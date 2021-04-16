module seven_led_x4 (
	input			i_clock,			// 56.84 MHz
	input [1:0]		i_save_mode_id,			// 0-'normal_wav', 1-'turbo_tap', 2-'normal_tap'
	input [1:0]		i_load_mode_id,			// 0-'normal_wav', 1-'turbo_tap'

	output reg [7:0]	o_seg,
	output reg [3:0]	o_dig
);

//	reg [7:0]		r_seg;
//	reg [3:0]		r_dig;

	wire [1:0]		r_load_mode_id;
	wire [1:0]		r_save_mode_id;
	reg  [3:0]		r_hex;
	reg  [31:0]		r_counter;

	assign			r_load_mode_id =	i_load_mode_id;
	assign			r_save_mode_id =	i_save_mode_id;

	always @ (posedge i_clock) begin
		r_counter <= r_counter + 1'b1;
	end

	always @ (r_counter[17] or r_load_mode_id or r_save_mode_id) begin	// ~200 Hz
		case (r_counter[19:18])
			2'b00:	begin
					o_dig <= 4'b0111;
					r_hex <= 4'h4;				// 'Load mode' logo
				end
			2'b01:	begin
					o_dig <= 4'b1011;
					r_hex <= {2'b00, r_load_mode_id};	// 0. , 1. , 2. , 3.
				end
			2'b10:	begin
					o_dig <= 4'b1101;
					r_hex <= 4'h5;				// 'Save mode' logo
				end
			2'b11:	begin
					o_dig <= 4'b1110;
					r_hex <= {2'b00, r_save_mode_id};	// 0. , 1. , 2. , 3.
				end
		endcase
	end

	always @ (r_hex) begin
		case (r_hex)
			4'h0:		o_seg = 8'h40;		// 0.
			4'h1:		o_seg = 8'h79;		// 1.
			4'h2:		o_seg = 8'h24;		// 2.
			4'h3:		o_seg = 8'h30;		// 3.

			4'h4:		o_seg = 8'hA1;		// 'd' as logo for 'Load mode'
			4'h5:		o_seg = 8'hE3;		// 'u' as logo for 'Save mode'

			default:	o_seg = 8'hF7;		// _
		endcase
	end

endmodule
