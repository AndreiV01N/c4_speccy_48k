module serial_out (
	input [7:0]		i_data,
	input			i_fifo_empty,
	input			i_clock,					// 56.84 MHz

	output wire		o_serial_tx,
	output wire		o_fifo_read_req
);
	parameter		CLOCK			= 56842105;
	parameter		BAUD_RATE		= 115200;
	parameter		POWER_32		= 33'h100000000;	// 2 ** 32
	parameter [48:0]	DDS_M_115200		= POWER_32 * BAUD_RATE / CLOCK;

	reg			r_serial_tx		= 1'b1;
	assign			o_serial_tx		= r_serial_tx;

	wire			w_new_data_ready;
	assign			w_new_data_ready	= ~i_fifo_empty;

	reg [31:0]		r_counter_dds		= 32'd0;
	reg			r_115200_freq_d1;
	reg			r_115200_freq_d2;

	always @ (negedge i_clock) begin
		r_counter_dds <= r_counter_dds + DDS_M_115200[31:0];		// 56.842 MHz -> 115200 Hz
		r_115200_freq_d2 <= r_115200_freq_d1;				// 'w_115200_freq' delayed for 1 period of i_clock
	end

	wire			w_115200_freq;
	assign			w_115200_freq		= r_counter_dds[31];	// 115200 Hz

	always @ (posedge i_clock) begin
		r_115200_freq_d1 <= w_115200_freq;				// 'w_115200_freq' delayed for 1/2 period of i_clock
	end

	reg			r_read_data_req		= 1'b0;
	assign			o_fifo_read_req		= (w_115200_freq && ~r_115200_freq_d2 && r_read_data_req) ? 1'b1 : 1'b0;

	reg [2:0]		r_state			= 3'd0;
	reg [2:0]		r_bit_ptr		= 3'd0;

	always @ (posedge w_115200_freq) begin					// 115200 Hz (triggered up and down by 'negedge i_clock')
		if (r_read_data_req)
			r_read_data_req <= 1'b0;

		case (r_state)
			3'd0:	begin
					if (w_new_data_ready) begin		// FIFO is not empty
						r_serial_tx <= 1'b0;		// START-bit
						r_read_data_req <= 1'b1;	// ask FIFO to expose next byte on i_data
						r_state <= 3'd1;
					end else
						r_serial_tx <= 1'b1;		// do nothing, keeping TX HIGH (IDLE)
				end
			3'd1:	begin						// i_data now holds the new data-byte
					r_serial_tx <= i_data[r_bit_ptr];
					if (r_bit_ptr == 3'd7)
						r_state <= 3'd2;		// all 8 bits have now been sent
				end
			3'd2:	begin
					r_serial_tx <= 1'b1;			// STOP-bit
					r_state <= 3'd0;
				end
		endcase
	end
	
	always @ (negedge w_115200_freq) begin
		case (r_state)
			3'd0:	r_bit_ptr <= 3'd7;
			3'd1:	r_bit_ptr <= r_bit_ptr + 1'b1;
		endcase
	end

endmodule
