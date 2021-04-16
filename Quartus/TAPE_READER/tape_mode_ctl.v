module load_mode_ctl (
	input	i_clock,		// 60 MHz
	input	i_load_mode_tgl,	// F12 key from ULA
	output	o_fifo_clear,
	output	o_load_mode	= 1'b0	// port_5F_in[3]
);
	reg	r_load_mode;
	reg	r_load_mode_tgl_aligned;
	reg	r_load_mode_tgl_d1;
	reg	r_load_mode_tgl_d2;

	assign	o_fifo_clear	= (r_load_mode_tgl_aligned && ~r_load_mode_tgl_d2) ? 1'b1 : 1'b0;
	assign	o_load_mode	= r_load_mode;

	always @ (negedge i_clock) begin
		r_load_mode_tgl_aligned <= i_load_mode_tgl;
		r_load_mode_tgl_d2 <= r_load_mode_tgl_d1;
	end

	always @ (posedge i_clock) begin
		r_load_mode_tgl_d1 <= r_load_mode_tgl_aligned;
	end

	always @ (posedge r_load_mode_tgl_d1) begin
		r_load_mode <= ~r_load_mode;
	end

endmodule
