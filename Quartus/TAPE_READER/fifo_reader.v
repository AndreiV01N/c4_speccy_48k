module fifo_reader (
	input		i_clock,			// 56.84 MHz
	input [3:0]	i_port_5F_out,			// Bit-0: FIFO read request

	output		o_fifo_read_req		= 1'b0
);
	assign		o_fifo_read_req		= (r_read_req_aligned && ~r_read_req_d2) ? 1'b1 : 1'b0;

	reg		r_read_req_aligned;
	reg		r_read_req_d1;
	reg		r_read_req_d2;
	
	always @ (negedge i_clock) begin
		r_read_req_aligned <= i_port_5F_out[0];
		r_read_req_d2 <= r_read_req_d1;
	end

	always @ (posedge i_clock) begin
		r_read_req_d1 <= r_read_req_aligned;
	end

endmodule
