module load_mode_ctl (
	input		i_clock,			// ~abt 56 MHz
	input		i_load_mode_tgl,		// F11 key from ULA

	output		o_clear_fifo,
	output		o_load_turbo,			// port_5F_in[3]
	output [1:0]	o_load_mode_id
);
	reg		r_load_turbo;
	reg [1:0]	r_load_mode_id		= 2'b00;

	reg		r_load_mode_tgl_aligned;
	reg		r_load_mode_tgl_d1;
	reg		r_load_mode_tgl_d2;

	assign		o_clear_fifo	= (r_load_mode_tgl_aligned && ~r_load_mode_tgl_d2) ? 1'b1 : 1'b0;
	assign		o_load_mode_id	= r_load_mode_id;
	assign		o_load_turbo	= r_load_mode_id[0];

	always @ (negedge i_clock) begin
		r_load_mode_tgl_aligned <= i_load_mode_tgl;
		r_load_mode_tgl_d2 <= r_load_mode_tgl_d1;
	end

	always @ (posedge i_clock) begin
		r_load_mode_tgl_d1 <= r_load_mode_tgl_aligned;
	end

	always @ (posedge r_load_mode_tgl_d1) begin
		r_load_mode_id <= {1'b0, ~r_load_mode_id[0]};
	end

endmodule
