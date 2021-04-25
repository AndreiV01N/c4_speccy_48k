module tape_out_decoder (
	input wire		i_fifo_full,				// we're unable to rely on this. once fifo is full we loose data at once
	input wire		i_tape_out,				// port_FE[3]
	input wire [7:0]	i_port_3F_out,				// incoming data bytes in "turbo" mode
	input wire [7:4]	i_port_5F_out,				// using bit-4 to write data byte into FIFO_out in "turbo" mode
	input wire		i_clock,				// 56.84 MHz
	input wire [1:0]	i_save_mode_id,

	output wire [7:0]	o_data,
	output wire		o_fifo_write_req
);
	wire			w_tape_out;
	assign			w_tape_out		= i_tape_out;		// idling when "turbo"
	
	reg [31:0]		r_counter		= 32'd0;		// to count HIGH and LOW levels lengths
	reg			r_level			= 1'b0;
	reg [2:0]		r_bit_ptr		= 3'd0;
	reg [2:0]		r_state			= 3'd0;

	wire			w_save_turbo;					// SAVE mode "1"
	wire			w_save_wav;					// SAVE mode "0"
	assign			w_save_turbo		=  i_save_mode_id[0];
	assign			w_save_wav		= ~i_save_mode_id[0] && ~i_save_mode_id[1];

	// SAVE mode "0"
	reg [7:0]		r_byte_wav;
	reg			r_byte_wav_ready	= 1'b0;

	// SAVE mode "1"
	reg			r_write_req_aligned;
	reg			r_write_req_d1;
	reg			r_write_req_d2;
	wire			r_write_req;
	assign			r_write_req		= r_write_req_aligned && ~r_write_req_d2;

	// SAVE mode "2"
	reg [7:0]		r_byte_tap;
	reg [7:0]		r_byte_tap_buff;
	reg			r_byte_tap_ready	= 1'b0;
	reg [15:0]		r_byte_tap_count	= 16'd0;		// to count "tap" bytes sent to FIFO_out

	assign			o_data			= (w_save_turbo)	? i_port_3F_out		:
							  (w_save_wav)		? r_byte_wav		: r_byte_tap;

	assign			o_fifo_write_req	= (w_save_turbo)	? r_write_req		:
							  (w_save_wav)		? r_byte_wav_ready	: r_byte_tap_ready;

// clock 56.547 MHz r_counter[15:10]/r_counter[15:8]	| wav_levels H/L
//	PILOT:	6'h21/8'h87	(2168 * 16 = h8780)	| 7/7
//	H_SYNC:	6'h0A/8'h29	( 667 * 16 = h29B0)	| 2/
//	L_SYNC:	6'h0B/8'h2D	( 735 * 16 = h2DF0)	|  /2
//	0:	6'h0D/8'h35	( 855 * 16 = h3570)	| 3/3
//	1:	6'h1A/8'h6A	(1710 * 16 = h6AE0)	| 5/6

	always @ (posedge i_clock) begin
		r_write_req_d1 <= r_write_req_aligned;
	end

	always @ (negedge i_clock) begin
		r_write_req_aligned <= i_port_5F_out[4];
		r_write_req_d2 <= r_write_req_d1;

		if (r_byte_wav_ready)								// FIFO_out already saved the data at preceeding posedge
			r_byte_wav_ready <= 1'b0;

		if (r_byte_tap_ready)								// FIFO_out already saved the data at preceeding posedge
			r_byte_tap_ready <= 1'b0;

		if (w_tape_out != r_level) begin						// tape level has now just changed to opposite
			if (r_state == 3'd6)
				r_state <= 3'd0;						// unlock r_counter upon SAVE activity

			if (r_level) begin							// HIGH levels
				r_byte_wav <= 8'hFF;						// 1-st wav-byte on HIGH level
				r_byte_wav_ready <= 1'b1;
				case (r_counter[15:10])
					6'h21:	r_state <= 3'd1;				// HIGH_pilot, expecting LOW_pilot
					6'h0A:	if (r_state == 3'd2) begin			// HIGH_sync
							r_byte_tap = r_byte_tap_count[7:0];	// insert 1-st (LSB) dumb byte for TAP block size header
							r_byte_tap_ready <= 1'b1;
							r_state <= 3'd3;			// expecting LOW_sync
						end
					6'h0D:	if (r_state == 3'd4) begin			// HIGH_0
							r_byte_tap_buff[r_bit_ptr] = 1'b0;	// saving bit in advance, LOW_0 is expected anyway
							r_bit_ptr <= r_bit_ptr - 1'b1;
							r_state <= 3'd5;			// expecting LOW_0
						end
					6'h1A:	if (r_state == 3'd4) begin			// HIGH_1
							r_byte_tap_buff[r_bit_ptr] = 1'b1;	// saving bit in advance, LOW_1 is expected anyway
							r_bit_ptr <= r_bit_ptr - 1'b1;
							r_state <= 3'd5;			// expecting LOW_1
						end
				endcase
			end else begin								// LOW levels
				r_byte_wav <= 8'h00;						// 1-st wav-byte on LOW level
				r_byte_wav_ready <= 1'b1;
				case (r_counter[15:10])
					6'h21:	if (r_state == 3'd1)				// LOW_pilot
							r_state <= 3'd2;			// permits HIGH_sync next to be
					6'h0B:	if (r_state == 3'd3) begin			// LOW_sync
							r_byte_tap = r_byte_tap_count[15:8];	// insert 2-nd (MSB) dumb byte for TAP block size header
							r_byte_tap_ready <= 1'b1;
							r_byte_tap_count <= 16'd0;		// reset bytes counter before new TAP block
							r_bit_ptr <= 3'd7;
							r_state <= 3'd4;			// expecting either HIGH_0 or HIGH_1
						end
					6'h0D,							// LOW_0
					6'h1A:	if (r_state == 3'd5) begin			// LOW_1
							if (r_bit_ptr == 3'd7) begin		// all 8 bits have now been parsed
								r_byte_tap = r_byte_tap_buff;	// the prepared byte is ready to be sent
								r_byte_tap_ready <= 1'b1;	// asking FIFO_out to write the byte
								r_byte_tap_count <= r_byte_tap_count + 1'b1;
							end
							r_state <= 3'd4;			// expecting either HIGH_0 or HIGH_1
						end
				endcase
			end
			r_counter <= 32'd0;				// reset counter to count a new level length
			r_level <= w_tape_out;
		end else begin						// same tape level as last time
			if (r_state != 3'd6)				// lock counter while silence on serial_rx
				r_counter = r_counter + 1'b1;		// counts current level length

			if (r_level) begin
				case (r_counter[15:0])
					16'h2800,			// HIGH_sync		+1 = 2
					16'h3400,			// HIGH_0		+1 = 3
					16'h3800,			// -fake complement-	+1 = 4
					16'h6400,			// HIGH_1		+1 = 5
					16'h7400,			// -fake complement-	+1 = 6
					16'h8400:			// HIGH_pilot (LEADER)	+1 = 7
							begin
								r_byte_wav <= 8'hFF;
								r_byte_wav_ready <= 1'b1;
							end
				endcase
			end else begin
				case (r_counter[15:0])
					16'h2C00,			// LOW_sync		+1 = 2
					16'h3400,			// LOW_0		+1 = 3
					16'h3800,			// -fake complement-	+1 = 4
					16'h4800,			// -fake complement-	+1 = 5
					16'h6400,			// LOW_1		+1 = 6
					16'h8400:			// LOW_pilot (LEADER)	+1 = 7
							begin
								r_byte_wav <= 8'h00;
								r_byte_wav_ready <= 1'b1;
							end
				endcase
			end

			if (r_counter == 32'h07000000) begin		// ~2.0s of silence (means end of SAVE stream)
				r_byte_tap = r_byte_tap_count[7:0];	// append 1-st (LSB) TAP header byte
				r_byte_tap_ready <= 1'b1;
			end

			if (r_counter == 32'h07400000) begin		// ~2.1s of silence
				r_byte_tap = r_byte_tap_count[15:8];	// append 2-nd (MSB) TAP header byte
				r_byte_tap_ready <= 1'b1;
				r_byte_tap_count <= 16'd0;
				r_counter <= 32'd0;
				r_state <= 3'd6;			// lock r_counter until any further SAVE activity
			end
		end
	end

endmodule
