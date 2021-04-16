module serial_in (
	input			i_clock,				// 56.84 MHz
	input			i_serial_rx,
	input			i_load_turbo,				// 0-normal, 1-turbo

	output wire		o_tape_in,
	output wire [7:0]	o_data,					// FIFO data in
	output wire		o_fifo_write_req			// FIFO write request
);
	parameter		CLOCK			= 56842105;
	parameter		BAUD_RATE		= 115200;
	parameter		SERIAL_STROBE_FULL	= CLOCK / BAUD_RATE;		// d493
	parameter		SERIAL_STROBE_HALF	= CLOCK / (BAUD_RATE * 2);

	reg [7:0]		r_data			= 8'd0;
	reg			r_data_ready		= 1'b0;
	reg [2:0]		r_state			= 3'd0;
	reg [2:0]		r_bit_ptr		= 3'd0;
	reg [7:0]		r_data_raw		= 8'd0;
	reg [15:0]		r_counter		= 16'd0;
	reg			r_serial_rx_d1;
	reg			r_serial_rx_d2;
	wire			r_load_turbo;

	assign			r_load_turbo		= i_load_turbo;
	assign			o_data			= r_data;
	assign			o_fifo_write_req	= (r_load_turbo && r_data_ready) ? 1'b1 : 1'b0;
	assign			o_tape_in		= r_data[7];			// comp. w/ 8'd128 in 'normal', make noise in 'turbo'

	always @ (posedge i_clock) begin
		r_serial_rx_d2 <= r_serial_rx_d1;					// buffered i_serial_rx for i_CLOCK's period
	end

	always @ (negedge i_clock) begin
		r_serial_rx_d1 <= i_serial_rx;

		if (r_data_ready)							// FIFO saved data-byte at prev. posedge
			r_data_ready <= 1'b0;

		case (r_state)
			3'd0:	begin							// IDLE, waiting for START-bit (LOW)
					if (~r_serial_rx_d2) begin			// spotted START-bit
						r_counter <= 16'd0;			// reset counter
						r_state <= 3'd1;
					end
				end
			3'd1:	begin
					if (r_counter == SERIAL_STROBE_HALF) begin	// half of strobe - middle of START-bit
						r_counter <= 16'd0;			// reset counter

						if (~r_serial_rx_d2) begin		// good news - START-bit is really LOW
							r_bit_ptr <= 3'd0;
							r_state <= 3'd2;
						end else				// wrong START-bit (HIGH), switch back to IDLE..
							r_state <= 3'd0;

					end else
						r_counter <= r_counter + 1'b1;
				end
			3'd2:	begin
					if (r_counter == SERIAL_STROBE_FULL) begin	// middle of data-bits
						r_counter <= 16'd0;
						r_data_raw[r_bit_ptr] <= r_serial_rx_d2;

						if (r_bit_ptr == 3'd7)			// last data-bit has now been processed
							r_state <= 3'd3;		// go to processing STOP-bit
						else
							r_bit_ptr <= r_bit_ptr + 1'b1;

					end else
						r_counter <= r_counter + 1'b1;
				end
			3'd3:	begin
					if (r_counter == SERIAL_STROBE_FULL) begin	// middle of STOP-bit (8N1)
						r_counter <= 16'd0;

						if (r_serial_rx_d2) begin
							r_data <= r_data_raw;		// expose the new data-byte only if STOP-bit is really HIGH
							r_data_ready <= 1'b1;		// ask FIFO_in to write (is considered only in 'turbo' mode)
							r_state <= 3'd0;
						end else				// wrong STOP-bit (LOW)
							r_state <= 3'd4;

					end else
						r_counter <= r_counter + 1'b1;
				end
			3'd4:	begin							// wait for finishing abnormal LOW-level
					if (r_serial_rx_d2)
						r_state <= 3'd0;
				end
		endcase
	end

endmodule
