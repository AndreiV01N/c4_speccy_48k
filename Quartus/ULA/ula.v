module ula (
	// main ULA clock 56.84 MHz
	input			clock_sys,
	// Video pixel clock 108.0 MHz (VGA 1280x1024 @60 Hz)
	input			clock_pix,
	// VGA
	output			VGA_R,
	output			VGA_G,
	output			VGA_B,
	output			VGA_HSYNC,
	output			VGA_VSYNC,
	// SDRAM controller
	input			ram_ready,
	input [15:0]		ram_rd_data,
	output			ram_rd_req,
	output			ram_wr_req,
	output [21:0]		ram_addr,
	output [15:0]		ram_wr_data,
	// Reset
	input			RESET_n,
	// Video RAM interface
	input [7:0]		video_rd_data,
	output [7:0]		video_wr_data,
	output [12:0]		video_wr_addr,
	output reg [12:0]	video_rd_addr,
	output			video_rd_en,
	output			video_wr_en,
	// I/O port OUT
	output			BEEPER,
	output			TAPE_OUT,
	output reg [7:0]	port_3F_out,
	output reg [7:0]	port_5F_out,
	// PS/2
	input			PS2_KBCLK,
	input			PS2_KBDAT,
	// I/O port IN
	input			TAPE_IN,
	input [7:0]		port_3F_in,
	input [7:0]		port_5F_in,

	output			sys_reset,
	output			load_mode_toggle,	// default '.WAV' or fast '.TAP' loading mode
	output			save_mode_toggle	// default '.WAV' or fast '.TAP' saving mode
);
	reg  [3:0]	clock_sys_cnt	= 4'd0;
	wire		clock_kb;
	wire		clock_rom;
	reg  [10:0]	h_cnt		= 11'd0;
	reg  [10:0]	h_cnt_d1	= 11'd0;	// to recognize negedge of clock_pix at next frame
	reg  [10:0]	v_cnt		= 11'd0;
	reg  [10:0]	v_cnt_int	= 11'd0;	// 50 Hz is every 630'th line
	wire		screen, h_screen, v_screen, screen_pre, h_screen_pre;
	reg		screen_pre_d1;
	wire		blank, h_blank, v_blank;
        wire [4:0]	h_bias;
	reg  [7:0]	vid_0_reg, vid_1_reg, vid_b_reg, vid_c_reg;
	reg		vid_dot;
	wire		r_color, g_color, b_color;
	wire [7:0]	rom_do;
	wire [15:0]	cpu_a_bus;
	wire [7:0]	cpu_do_bus;
	wire [7:0]	cpu_di_bus;
	wire		cpu_clk;
	wire		cpu_mreq_n;
	wire		cpu_iorq_n;
	wire		cpu_wr_n;
	wire		cpu_rd_n;
	wire		cpu_int_n;
	wire		cpu_m1_n;
	wire		vid_sel;
	wire		rom_sel;
	wire		port_3F_sel, port_5F_sel, port_FE_sel;
	wire		port_XX_out;
	reg  [7:0]	port_FE_out;
	wire		res_kbd_n;
	wire [7:0]	kb_a_bus;
	wire [4:0]	kb_do_bus;
	reg  [4:0]	flash_cnt;
	wire [2:0]	ink;
	wire [2:0]	paper;
//	wire		bright;
	wire		inverted;
	reg		r_tape_in;
	wire [12:1]	r_f_keys;

// VGA timinigs (1280x1024 @60 Hz) 108.0 Mhz
/*	hcnt:   0_____________1023	1024___1151	1152_______1199	1200_____1311	1312_____1559	1560_____1687
		Screen (1024)		Border (128)	F.porch (48)	H_sync (112)	B.porch (248)	Border (128)

	vcnt:	0_____________767	768_____895	896_______896	897____899	900_____937	938_____1065
		Screen (768)		Border (128)	F.porch (1)	V_sync (3)	B.porch (38)	Border (128)
*/

	always @ (negedge clock_pix) begin
		case (h_cnt)
			11'd1024:	begin					// Screen->[border 1-st pix]
						if (v_cnt_int == 11'd1279)
							v_cnt_int <= 11'd0;	// cpu_int_n is triggered
						else
							v_cnt_int <= v_cnt_int + 1'b1;
						h_cnt <= h_cnt + 1'b1;
					end
			11'd1200:	begin					// start of H-sync, updating v_cnt
						if (v_cnt == 11'd1065)
							v_cnt <= 11'd0;		// Screen's 1-st line
						else
							v_cnt <= v_cnt + 1'b1;
						h_cnt <= h_cnt + 1'b1;
					end
			11'd1655:	h_cnt <= h_cnt + 11'd9;			// 1664 (align the frame before Screen to 8 bit)
			11'd1695:	h_cnt <= 11'd0;				// Screen's 1-st pix
			default:	h_cnt <= h_cnt + 1'b1;
		endcase
	end

	always @ (posedge clock_pix) begin		// helps to apply new screen-byte and attr just in time
		h_cnt_d1 <= h_cnt;			// sync with h_cnt (half-phase)
		screen_pre_d1 <= screen_pre;
	end

	assign VGA_HSYNC	= (h_cnt >= 11'd1200 && h_cnt <= 11'd1311)	? 1'b1 : 1'b0;		// pos
	assign VGA_VSYNC	= (v_cnt >= 11'd897  && v_cnt <= 11'd899)	? 1'b1 : 1'b0;		// pos

	assign h_screen		= (h_cnt <= 11'd1023)				? 1'b1 : 1'b0;
	assign v_screen		= (v_cnt <= 11'd767)				? 1'b1 : 1'b0;
	assign h_blank		= (h_cnt >= 11'd1152 && h_cnt <= 11'd1559)	? 1'b1 : 1'b0;
	assign v_blank		= (v_cnt >= 11'd896  && v_cnt <= 11'd937)	? 1'b1 : 1'b0;
	assign h_screen_pre	= (h_cnt <= 11'd991 || h_cnt >= 11'd1664)	? 1'b1 : 1'b0;

	assign screen		= (h_screen && v_screen)			? 1'b1 : 1'b0;
	assign screen_pre	= (h_screen_pre && v_screen)			? 1'b1 : 1'b0;
	assign blank		= (h_blank || v_blank)				? 1'b1 : 1'b0;

	assign h_bias		= (h_cnt >= 11'd1656)				? 5'd0 : h_cnt[9:5] + 1'b1 ;

	assign vid_sel		= (screen_pre && (h_cnt[4:0] == 5'b10001 ||
						  h_cnt[4:0] == 5'b11001))	? 1'b1 : 1'b0;

	always @ (negedge clock_pix) begin
		if (screen_pre_d1) begin
			case (h_cnt_d1[4:0])
				5'b10000: video_rd_addr <= {v_cnt[9:8], v_cnt[4:2], v_cnt[7:5], h_bias};	// 4th screen-dot
				5'b11000: video_rd_addr <= {3'b110, v_cnt[9:5], h_bias};			// 6th screen-dot
				5'b10010: vid_0_reg <= video_rd_data;		// bits
				5'b11010: vid_1_reg <= video_rd_data;		// attr
				5'b11111: begin
						vid_b_reg <= vid_0_reg;         // bits
						vid_c_reg <= vid_1_reg;         // attr
					  end
			endcase
		end
	end

	always @ (h_cnt or vid_b_reg) begin
		case (h_cnt[4:2])
			3'b000: vid_dot <= vid_b_reg[7];
			3'b001: vid_dot <= vid_b_reg[6];
			3'b010: vid_dot <= vid_b_reg[5];
			3'b011: vid_dot <= vid_b_reg[4];
			3'b100: vid_dot <= vid_b_reg[3];
			3'b101: vid_dot <= vid_b_reg[2];
			3'b110: vid_dot <= vid_b_reg[1];
			3'b111: vid_dot <= vid_b_reg[0];
		endcase
	end

	always @ (posedge v_cnt[10]) begin
		flash_cnt <= flash_cnt + 1'b1;
	end

//	assign bright	= vid_c_reg[6];
	assign inverted	= vid_c_reg[7] && flash_cnt[4] ? 1'b1 : 1'b0;
	assign ink	= inverted ? vid_c_reg[5:3] : vid_c_reg[2:0];
	assign paper	= inverted ? vid_c_reg[2:0] : vid_c_reg[5:3];

	assign b_color = blank ? 1'b0 : (screen ? (vid_dot ? ink[0] : paper[0]) : port_FE_out[0]);
	assign r_color = blank ? 1'b0 : (screen ? (vid_dot ? ink[1] : paper[1]) : port_FE_out[1]);
	assign g_color = blank ? 1'b0 : (screen ? (vid_dot ? ink[2] : paper[2]) : port_FE_out[2]);

	assign VGA_B = b_color;		// "RZ-EasyFPGA" board has 1-bit discrete VGA pins :(
	assign VGA_R = r_color;
	assign VGA_G = g_color;


// System (CPU and memory)
	always @ (negedge clock_sys) begin
		r_tape_in <= TAPE_IN;
		clock_sys_cnt <= clock_sys_cnt + 1'b1;
	end

	assign cpu_clk		= clock_sys_cnt[3];		// CPU clock  = 56.84 MHz >> 4 = 3.55 MHz
	assign clock_kb		= clock_sys_cnt[1];		// PS/2 clock = 56.84 MHz >> 2 = 14.2 MHz
	assign clock_rom	= clock_sys_cnt[1];		// ROM clock  = 56.84 MHz >> 2 = 14.2 MHz

	assign cpu_int_n	= (	v_cnt_int == 11'd0	&&
					h_cnt >= 11'd1024	&&
					h_cnt <= 11'd1567	&&
					cpu_iorq_n		&&
					cpu_m1_n)				? 1'b0 : 1'b1;

	assign rom_sel		= (                cpu_a_bus[15:14] == 2'b00)	? 1'b1 : 1'b0;		// positive if selected
	assign port_3F_sel	= (~cpu_iorq_n &&  cpu_a_bus[7:0]   == 8'h3F)	? 1'b1 : 1'b0;		// positive if selected (port B of 8255A)
	assign port_5F_sel	= (~cpu_iorq_n &&  cpu_a_bus[7:0]   == 8'h5F)	? 1'b1 : 1'b0;		// positive if selected (port C of 8255A)
	assign port_FE_sel	= (~cpu_iorq_n &&  cpu_a_bus[7:0]   == 8'hFE)	? 1'b1 : 1'b0;		// positive if selected (cpu_a_bus[7:0] == 8'hFE)
	assign port_XX_out	= (~cpu_iorq_n && ~cpu_wr_n)			? 1'b1 : 1'b0;

	always @ (posedge port_XX_out) begin
		case (cpu_a_bus[7:0])
			8'h3F:	port_3F_out <= cpu_do_bus;		// OUT (x3F) <- A
			8'h5F:	port_5F_out <= cpu_do_bus;		// OUT (x5F) <- A
			8'hFE:	port_FE_out <= cpu_do_bus;		// OUT (xFE) <- A [N/A, N/A, N/A, TAPE_OUT, BEEP, GB, RB, BB]
		endcase
	end

	assign video_rd_en	= vid_sel;
	assign video_wr_en	= (~cpu_mreq_n &&  cpu_rd_n && ~cpu_wr_n && cpu_a_bus >= 16'h4000 && cpu_a_bus < 16'h5B00) ? 1'b1 : 1'b0;
	assign video_wr_data	= (~cpu_mreq_n &&  cpu_rd_n && ~cpu_wr_n && cpu_a_bus >= 16'h4000 && cpu_a_bus < 16'h5B00) ? cpu_do_bus : 8'h00;
	assign video_wr_addr	=                                          (cpu_a_bus >= 16'h4000 && cpu_a_bus < 16'h5B00) ? cpu_a_bus[12:0] : 13'h0000;

	assign ram_rd_req	= (~cpu_mreq_n && ~cpu_rd_n &&  cpu_wr_n)	? 1'b1 : 1'b0;
	assign ram_wr_req	= (~cpu_mreq_n &&  cpu_rd_n && ~cpu_wr_n)	? 1'b1 : 1'b0;
	assign ram_wr_data	= (~cpu_mreq_n &&  cpu_rd_n && ~cpu_wr_n)	? {8'h00, cpu_do_bus} : 16'h0000;
	assign ram_addr		= {6'b000000, cpu_a_bus};

	assign cpu_di_bus	= (~cpu_mreq_n &&  rom_sel && ~cpu_rd_n)	? rom_do				:
				  (~cpu_mreq_n && ~rom_sel && ~cpu_rd_n)	? ram_rd_data[7:0]			:
				  (            port_3F_sel && ~cpu_rd_n)	? port_3F_in				:	// IN A <- (x3F)
				  (            port_5F_sel && ~cpu_rd_n)	? port_5F_in				:	// IN A <- (x5F)
				  (            port_FE_sel && ~cpu_rd_n)	? {1'b0, r_tape_in, 1'b0, kb_do_bus}	:	// IN A <- (xFE)
				  8'hFF;

	assign kb_a_bus		=  cpu_a_bus[15:8];

	assign TAPE_OUT		=  port_FE_out[3];
	assign BEEPER		= ~port_FE_out[4];
	assign sys_reset	= ~res_kbd_n;
	assign load_mode_toggle	= ~r_f_keys[11];
	assign save_mode_toggle	= ~r_f_keys[12];

	wire stub_RFSH_n;
	wire stub_HALT_n;
	wire stub_BUSAK_n;
	T80se Z80 (
		.RESET_n	(RESET_n && res_kbd_n),
		.CLK_n		(cpu_clk),
		.CLKEN		(1'b1),
		.WAIT_n		(ram_ready),
		.INT_n		(cpu_int_n),
		.NMI_n		(1'b1),
		.BUSRQ_n	(1'b1),
		.M1_n		(cpu_m1_n),
		.MREQ_n		(cpu_mreq_n),
		.IORQ_n		(cpu_iorq_n),
		.RD_n		(cpu_rd_n),
		.WR_n		(cpu_wr_n),
		.RFSH_n		(stub_RFSH_n),
		.HALT_n		(stub_HALT_n),
		.BUSAK_n	(stub_BUSAK_n),
		.A		(cpu_a_bus),
		.DI		(cpu_di_bus),
		.DO		(cpu_do_bus)
	);

	rom_16k ROM (
		.address	(cpu_a_bus[13:0]),
		.clock		(clock_rom),
		.q		(rom_do)
	);

	wire stub_k_joy;
//	wire stub_f_key;
	wire stub_num_joy;
	zxkbd zxkey (
		.clk		(clock_kb),
		.reset		(1'b0),
		.res_k		(res_kbd_n),
		.ps2_clk	(PS2_KBCLK),
		.ps2_data	(PS2_KBDAT),
		.zx_kb_scan	(kb_a_bus),
		.zx_kb_out	(kb_do_bus),
		.k_joy		(stub_k_joy),
		.f_key		(r_f_keys),
		.num_joy	(stub_num_joy)
	);

endmodule
