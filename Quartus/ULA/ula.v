module ula (
	// main ULA clock ~56.00 MHz
	input			clock_sys,
	// Video pixel clock
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
//	output			video_rd_en,
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

// VGA and video memory
/*
//Sys clock:  56.8421 MHz - c0 - Ratio: 108/95
//Pix clock: 108.0000 MHz - c1 - Ratio:  54/25 (2.16)

	parameter	vga_pix_clock	= 108000000;

	parameter	vga_x		= 1280;
	parameter	vga_y		= 1024;

	parameter	vga_x_total	= 1688;
	parameter	vga_y_total	= 1066;

	parameter	vga_h_f_porch	= 48;
	parameter	vga_h_sync	= 112;
	parameter	vga_h_b_porch	= 248;

	parameter	vga_v_f_porch	= 1;
	parameter	vga_v_sync	= 3;
	parameter	vga_v_b_porch	= 38;
*/

//PLL New2 (1366x768): screen
//Sys clock:  55.000 MHz - c0 - Ratio: 11/10
//Pix clock:  88.000 MHz - c1 - Ratio: 44/25
	parameter	vga_pix_clock	= 88000000;

	parameter	vga_x_total	= 1816;		// 0 .. 1815
	parameter	vga_y_total	= 808;

	parameter	vga_x		= 1384;		// 0 .. 1383
	parameter	vga_y		= 768;

	parameter	vga_h_f_porch	= 40;
	parameter	vga_h_sync	= 280;
	parameter	vga_h_b_porch	= 112;

	parameter	vga_v_f_porch	= 2;
	parameter	vga_v_sync	= 12;
	parameter	vga_v_b_porch	= 26;
//
	reg		is_tiled	= 1'd0;		// toggled by F9 key [0,1]
	reg [2:0]	pix_per_dot	= 3'd1;		// toggled by F10 key [1,2,3,4,5]

	reg [10:0]	h_cnt		= 11'd0;
	reg [5:0]	h_cmap_pix	= 5'd0;		// 0..cmap_size_pix-1 - current pix column in char-map
	reg [2:0]	h_cmap_dot	= 3'd0;		// 0..7  current dot column in char-map
	reg [4:0]	h_cmap		= 5'd0;		// 0..31 current char-map column

	reg [10:0]	v_cnt		= 11'd0;
	reg [5:0]	v_cmap_pix	= 5'd0;		// 0..cmap_size_pix-1 - current vert. pix in char-map
	reg [2:0]	v_cmap_dot	= 3'd0;		// 0..7 current dot row in char-map
	reg [4:0]	v_cmap		= 5'd0;		// 0..24 current char-map row
	reg [1:0]	v_zone		= 2'd0;		// vert. zx videomem zone [0,1,2]
	reg [2:0]	v_zone_cmap	= 3'd0;		// 0..7 current char-map row in current v_zone

	reg [7:0]	video_b, video_b_buff;		// screen-bits
	reg [7:0]	video_c, video_c_buff;		// colors (attrs)
	reg [5:0]	flash_cnt		= 6'd0;

	wire [5:0]	cmap_size_pix		= 6'(pix_per_dot << 3);			// *8
	wire [10:0]	screen_x_pix		= 11'(pix_per_dot << 8);		// *256
	wire [10:0]	screen_y_pix		= 11'((pix_per_dot << 6) * 3);		// *192

	wire [10:0]	border_x		= 11'((vga_x - screen_x_pix) >> 1);
	wire [10:0]	border_y		= 11'((vga_y - screen_y_pix) >> 1);

	wire [10:0]	vga_h_sync_begin	= 11'(vga_x_total - vga_h_sync);
	wire [10:0]	vga_h_sync_end		= 11'(vga_x_total - 1);			// reset <h_cnt>
	wire [10:0]	vga_v_sync_begin	= 11'(vga_y_total - vga_v_sync);
	wire [10:0]	vga_v_sync_end		= 11'(vga_y_total - 1);			// reset <v_cnt>
	
	wire [5:0]	cmap_dot2_pix	= 6'(1 * pix_per_dot);
	wire [5:0]	cmap_dot3_pix	= 6'(2 * pix_per_dot);
	wire [5:0]	cmap_dot4_pix	= 6'(3 * pix_per_dot);
	wire [5:0]	cmap_dot5_pix	= 6'(4 * pix_per_dot);
	wire [5:0]	cmap_dot6_pix	= 6'(5 * pix_per_dot);
	wire [5:0]	cmap_dot7_pix	= 6'(6 * pix_per_dot);
	wire [5:0]	cmap_dot8_pix	= 6'(7 * pix_per_dot);

	/// Maths for X
	wire [10:0]	start_x		= is_tiled ? 11'(vga_h_b_porch - cmap_size_pix + ((border_x % screen_x_pix) % cmap_size_pix))
						   : 11'(vga_h_b_porch + border_x);

	wire [10:0]	screen_x	= is_tiled ? 11'(vga_h_b_porch)
						   : 11'(vga_h_b_porch + border_x);

	wire [10:0]	screen_x_end	= is_tiled ? 11'(vga_h_b_porch + vga_x - 1)
						   : 11'(vga_h_b_porch + border_x + screen_x_pix - 1);

	wire [4:0]	h_cmap_init	= is_tiled ? 5'(31 - ((border_x % screen_x_pix) / cmap_size_pix))
						   : 5'd0;
	/// Maths for Y
	wire [10:0]	screen_y	= is_tiled ? 11'(vga_v_b_porch)
						   : 11'(vga_v_b_porch + border_y);

	wire [10:0]	screen_y_end	= is_tiled ? 11'(vga_v_b_porch + vga_y - 1)
						   : 11'(vga_v_b_porch + border_y + screen_y_pix - 1);

	wire [4:0]	v_cmap_init	= is_tiled ? 5'(((screen_y_pix - (border_y % screen_y_pix)) / cmap_size_pix) % 24)
						   : 5'd0;
 
	wire [5:0]	v_cmap_pix_init	= is_tiled ? 6'((cmap_size_pix - ((border_y % screen_y_pix) % cmap_size_pix)) % cmap_size_pix)
						   : 6'd0;

	wire [2:0]	v_cmap_dot_init	= is_tiled ? 3'(v_cmap_pix_init / pix_per_dot)
						   : 3'd0;
	///

	wire	h_sync		= (h_cnt >= vga_h_sync_begin &&
				   h_cnt <= vga_h_sync_end)			? 1'b1 : 1'b0;

	wire	v_sync		= (v_cnt >= vga_v_sync_begin &&
				   v_cnt <= vga_v_sync_end)			? 1'b1 : 1'b0;

	wire	h_screen	= (h_cnt >= screen_x &&
				   h_cnt <= screen_x_end)			? 1'b1 : 1'b0;

	wire	v_screen	= (v_cnt >= screen_y &&
				   v_cnt <= screen_y_end)			? 1'b1 : 1'b0;

	wire	screen		= (h_screen && v_screen)			? 1'b1 : 1'b0;

	wire	h_blank		= (h_cnt <= (vga_h_b_porch - 1) ||
				   h_cnt >= (vga_h_b_porch + vga_x))		? 1'b1 : 1'b0;

	wire	v_blank		= (v_cnt < vga_v_b_porch ||
				   v_cnt >= (vga_v_b_porch + vga_y))		? 1'b1 : 1'b0;

	wire	blank		= (h_blank || v_blank)				? 1'b1 : 1'b0;

	wire	video_dot	= video_b[7 - h_cmap_dot];
//	wire	bright		= video_c[6];
	wire	inverted	= (video_c[7] && flash_cnt[5])			? 1'b1 : 1'b0;

	wire [2:0]	ink	= inverted					? video_c[5:3] : video_c[2:0];
	wire [2:0]	paper	= inverted					? video_c[2:0] : video_c[5:3];

	assign VGA_HSYNC = h_sync;
	assign VGA_VSYNC = v_sync;

	assign VGA_B = blank ? 1'b0 : (screen ? (video_dot ? ink[0] : paper[0]) : port_FE_out[0]);
	assign VGA_R = blank ? 1'b0 : (screen ? (video_dot ? ink[1] : paper[1]) : port_FE_out[1]);
	assign VGA_G = blank ? 1'b0 : (screen ? (video_dot ? ink[2] : paper[2]) : port_FE_out[2]);

	always @ (posedge r_f_keys[9]) begin
		is_tiled <= ~is_tiled;
        end

	always @ (posedge r_f_keys[10]) begin
		if ((pix_per_dot + 1'b1) * 8 * 24 > vga_y)
			pix_per_dot <= 3'd1;
		else
			pix_per_dot <= pix_per_dot + 1'b1;
        end

	always @ (negedge clock_pix) begin
		case (h_cnt)			// VGA counters
			vga_h_sync_begin:
				begin
					h_cnt <= h_cnt + 1'b1;
					case (v_cnt)
						vga_y_total - 1:
							v_cnt <= 11'd0;
						default:
							v_cnt <= v_cnt + 1'b1;
					endcase
				end
			vga_x_total - 1:
				h_cnt <= 11'd0;
			default:
				h_cnt <= h_cnt + 1'b1;
		endcase

		if (v_screen) begin		// read data from video memory
			case (h_cmap_pix)
				6'd0:
						video_rd_addr <= {v_zone[1:0], v_cmap_dot[2:0], v_zone_cmap[2:0], h_cmap[4:0]};	// byte's addr
				cmap_dot4_pix:
					begin
						video_b_buff <= video_rd_data;
						video_rd_addr <= {3'b110, v_cmap[4:0], h_cmap[4:0]}; // attr's addr
					end
				default:
					begin
					end
			endcase
		end
	end

	always @ (posedge clock_pix) begin
		case (h_cnt)
			vga_h_sync_begin:	// H-sync
				begin
					case (v_cnt)
						screen_y - 1:
							begin
								v_cmap <= v_cmap_init;
								v_cmap_pix <= v_cmap_pix_init;
								v_cmap_dot <= v_cmap_dot_init;
								v_zone_cmap <= 3'(v_cmap_init % 8);
								v_zone <= 2'(v_cmap_init >> 3);
								flash_cnt <= flash_cnt + 1'b1;
							end
						default:
							begin
								case (v_cmap_pix)
									cmap_dot2_pix - 1,
									cmap_dot3_pix - 1,
									cmap_dot4_pix - 1,
									cmap_dot5_pix - 1,
									cmap_dot6_pix - 1,
									cmap_dot7_pix - 1,
									cmap_dot8_pix - 1:	// last line in 'dot'
										begin
											v_cmap_pix <= v_cmap_pix + 1'b1;
											v_cmap_dot <= v_cmap_dot + 1'b1;
										end
									cmap_size_pix - 1:	// last line in 'cmap'
										begin
											case (v_cmap)
												5'd7:
													begin
														v_cmap <= v_cmap + 1'b1;
														v_zone <= 2'd1;
														v_zone_cmap <= 3'd0;
													end
												5'd15:
													begin
														v_cmap <= v_cmap + 1'b1;
														v_zone <= 2'd2;
														v_zone_cmap <= 3'd0;
													end
												5'd23:
													begin
														v_cmap <= 5'd0;
														v_zone <= 2'd0;
														v_zone_cmap <= 3'd0;
													end
												default:
													begin
														v_cmap <= v_cmap + 1'b1;
														v_zone_cmap <= v_zone_cmap + 1'b1;
													end
											endcase
											v_cmap_pix <= 6'd0;
											v_cmap_dot <= 3'd0;
										end
									default:
										v_cmap_pix <= v_cmap_pix + 1'b1;
								endcase
							end
					endcase
				end
			start_x - cmap_size_pix:
				begin
					h_cmap <= h_cmap_init;
					h_cmap_pix <= 6'd0;		// 1-st pix in cmap
					h_cmap_dot <= 3'd0;		// 1-st dot in cmap
				end
			start_x:
				begin
					h_cmap <= h_cmap + 1'b1;
					h_cmap_pix <= 6'd0;
					h_cmap_dot <= 3'd0;
					video_b <= video_b_buff;	// apply byte
					video_c <= video_rd_data;	// apply colors (attrs)
				end
			default:
				begin
					case (h_cmap_pix)
						cmap_dot2_pix - 1,
						cmap_dot3_pix - 1,
						cmap_dot4_pix - 1,
						cmap_dot5_pix - 1,
						cmap_dot6_pix - 1,
						cmap_dot7_pix - 1,
						cmap_dot8_pix - 1:	// last pixel in 'dot'
							begin
								h_cmap_pix <= h_cmap_pix + 1'b1;
								h_cmap_dot <= h_cmap_dot + 1'b1;
							end
						cmap_size_pix - 1:	// last pixel in 'cmap'
							begin
								case (h_cmap)
									5'd31:
										h_cmap <= 5'd0;
									default:
										h_cmap <= h_cmap + 1'b1;
								endcase
								h_cmap_pix <= 6'd0;
								h_cmap_dot <= 3'd0;
								video_b <= video_b_buff;	// apply byte
								video_c <= video_rd_data;	// apply colors (attrs)
							end
						default:
								h_cmap_pix <= h_cmap_pix + 1'b1;
					endcase
				end
		endcase
	end

// System (CPU and memory)
	reg [3:0]	clock_sys_cnt	= 4'd0;
	reg [7:0]	port_FE_out;
	reg		r_tape_in;

	wire [10:0]	cpu_int_len	= 11'((vga_pix_clock / 1000000) << 3);		// 8us
	
	wire cpu_clk		= clock_sys_cnt[3];		// CPU clock  = 56 MHz >> 4 = 3.5 MHz
	wire clock_kb		= clock_sys_cnt[1];		// PS/2 clock = 56 MHz >> 2 = 14 MHz
	wire clock_rom		= clock_sys_cnt[1];		// ROM clock  = 56 MHz >> 2 = 14 MHz

	wire cpu_int_n		= (v_cnt == vga_v_sync_begin		&&
				   h_cnt <= cpu_int_len			&&
				   cpu_iorq_n				&&
				   cpu_m1_n)					? 1'b0 : 1'b1;

	wire [7:0] cpu_di_bus	= (~cpu_mreq_n &&  rom_sel && ~cpu_rd_n)	? rom_do				:
				  (~cpu_mreq_n && ~rom_sel && ~cpu_rd_n)	? ram_rd_data[7:0]			:
				  (            port_3F_sel && ~cpu_rd_n)	? port_3F_in				:	// IN A <- (x3F)
				  (            port_5F_sel && ~cpu_rd_n)	? port_5F_in				:	// IN A <- (x5F)
				  (            port_FE_sel && ~cpu_rd_n)	? {1'b0, r_tape_in, 1'b0, kb_do_bus}	:	// IN A <- (xFE)
				  8'hFF;

	wire rom_sel		= (                cpu_a_bus[15:14] == 2'b00)	? 1'b1 : 1'b0;		// positive if selected
	wire port_3F_sel	= (~cpu_iorq_n &&  cpu_a_bus[7:0]   == 8'h3F)	? 1'b1 : 1'b0;		// positive if selected (port B of 8255A)
	wire port_5F_sel	= (~cpu_iorq_n &&  cpu_a_bus[7:0]   == 8'h5F)	? 1'b1 : 1'b0;		// positive if selected (port C of 8255A)
	wire port_FE_sel	= (~cpu_iorq_n &&  cpu_a_bus[7:0]   == 8'hFE)	? 1'b1 : 1'b0;		// positive if selected (cpu_a_bus[7:0] == 8'hFE)
	wire port_XX_out	= (~cpu_iorq_n && ~cpu_wr_n)			? 1'b1 : 1'b0;

	assign video_wr_en	= (~cpu_mreq_n &&  cpu_rd_n && ~cpu_wr_n && cpu_a_bus >= 16'h4000 && cpu_a_bus < 16'h5B00) ? 1'b1 : 1'b0;
	assign video_wr_data	= (~cpu_mreq_n &&  cpu_rd_n && ~cpu_wr_n && cpu_a_bus >= 16'h4000 && cpu_a_bus < 16'h5B00) ? cpu_do_bus : 8'h00;
	assign video_wr_addr	=                                          (cpu_a_bus >= 16'h4000 && cpu_a_bus < 16'h5B00) ? cpu_a_bus[12:0] : 13'h0000;

	assign ram_rd_req	= (~cpu_mreq_n && ~cpu_rd_n &&  cpu_wr_n)	? 1'b1 : 1'b0;
	assign ram_wr_req	= (~cpu_mreq_n &&  cpu_rd_n && ~cpu_wr_n)	? 1'b1 : 1'b0;
	assign ram_wr_data	= (~cpu_mreq_n &&  cpu_rd_n && ~cpu_wr_n)	? {8'h00, cpu_do_bus} : 16'h0000;
	assign ram_addr		= {6'b000000, cpu_a_bus};

	assign TAPE_OUT		=  port_FE_out[3];
	assign BEEPER		= ~port_FE_out[4];
	assign sys_reset	= ~res_kbd_n;
	assign load_mode_toggle	= ~r_f_keys[11];
	assign save_mode_toggle	= ~r_f_keys[12];

	always @ (negedge clock_sys) begin
		r_tape_in <= TAPE_IN;
		clock_sys_cnt <= clock_sys_cnt + 1'b1;
	end

	always @ (posedge port_XX_out) begin
		case (cpu_a_bus[7:0])
			8'h3F:	port_3F_out <= cpu_do_bus;		// OUT (x3F) <- A
			8'h5F:	port_5F_out <= cpu_do_bus;		// OUT (x5F) <- A
			8'hFE:	port_FE_out <= cpu_do_bus;		// OUT (xFE) <- A [N/A, N/A, N/A, TAPE_OUT, BEEP, GB, RB, BB]
		endcase
	end

	wire		cpu_m1_n;
	wire		cpu_mreq_n;
	wire		cpu_iorq_n;
	wire		cpu_rd_n;
	wire		cpu_wr_n;
	wire		stub_RFSH_n;
	wire		stub_HALT_n;
	wire		stub_BUSAK_n;
	wire [15:0]	cpu_a_bus;
	wire [7:0]	cpu_do_bus;
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

	wire [7:0]	rom_do;
	rom_16k ROM (
		.address	(cpu_a_bus[13:0]),
		.clock		(clock_rom),
		.q		(rom_do)
	);


	wire		res_kbd_n;
	wire [7:0]	kb_a_bus = cpu_a_bus[15:8];
	wire [4:0]	kb_do_bus;
	wire [12:1]	r_f_keys;
	wire [4:0]	stub_k_joy;
	wire		stub_num_joy;
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
