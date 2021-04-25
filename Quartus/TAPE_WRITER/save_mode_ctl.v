module save_mode_ctl (
	input		i_clock,			// 56.84 MHz
	input		i_save_mode_tgl,		// F12 key from ULA

	output		o_save_turbo,			// goes to port_5F_in[7]: 0-normal (.wav or .tap), 1-turbo (.tap)
	output [1:0]	o_save_mode_id			// 0-'normal-wav', 1-'turbo_tap', 2-'normal_tap'
);
	reg [1:0]	r_save_mode_id	= 2'b00;
	reg		r_save_mode_tgl_aligned;
	reg		r_save_mode_tgl_d1;

	assign		o_save_mode_id	= r_save_mode_id;
	assign		o_save_turbo	= r_save_mode_id[0];

	always @ (negedge i_clock) begin
		r_save_mode_tgl_aligned <= i_save_mode_tgl;
	end

	always @ (posedge i_clock) begin
		r_save_mode_tgl_d1 <= r_save_mode_tgl_aligned;
	end

	always @ (posedge r_save_mode_tgl_d1) begin
		if (r_save_mode_id == 2'b10)
			r_save_mode_id <= 2'b00;
		else
			r_save_mode_id <= r_save_mode_id + 1'b1;
	end

endmodule
