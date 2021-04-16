library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sdram_controller is
	generic (
		--memory frequency in MHz
		sdram_frequency	: integer := 57
	);
	port (
		--ready to operation
		ready		: out std_logic := '0';
		--clock
		clock		: in  std_logic;
		--read
		rd_req		: in  std_logic;
		rd_adr		: in  std_logic_vector(21 downto 0);
		rd_data		: out std_logic_vector(15 downto 0);
		rd_valid	: out std_logic;
		--write
		wr_req		: in  std_logic;
		wr_adr		: in  std_logic_vector(21 downto 0);
		wr_data		: in  std_logic_vector(15 downto 0);
		--SDRAM interface
		sdram_wren_n	: out std_logic := '1';
		sdram_cas_n	: out std_logic := '1';
		sdram_ras_n	: out std_logic := '1';
		sdram_a		: out std_logic_vector(11 downto 0);
		sdram_ba	: out std_logic_vector(1 downto 0);
		sdram_dqm	: out std_logic_vector(1 downto 0);
		sdram_dq	: inout std_logic_vector(15 downto 0);
		sdram_clk_n	: out std_logic;
		--SDRAM interface (only for RZ_EasyFPGA board)
		sdram_cs_n	: out std_logic;
		sdram_cke	: out std_logic
	);
end entity;

architecture rtl of sdram_controller is
	signal adr			: std_logic_vector(21 downto 0) := (others => '0');	--selected address
	signal adr_reg			: std_logic_vector(21 downto 0) := (others => '0');	--selected address register
	signal state			: std_logic_vector(2 downto 0) := "100";		--state machine register
	signal sdram_cmd		: std_logic_vector(2 downto 0) := (others => '1');	--command register
	signal wr_data1			: std_logic_vector(15 downto 0) := (others => '0');	--write data pipe stage1
	signal wr_data2			: std_logic_vector(15 downto 0) := (others => '0');	--write data pipe stage2
	signal rd_pipe_valid		: std_logic_vector(3 downto 0) := (others => '0');
	signal rd_now			: std_logic := '0';
	signal rd_selected		: std_logic := '0';
	signal wr_selected		: std_logic := '0';
	signal rd_cycle			: std_logic := '0';
	signal same_row_and_bank	: std_logic := '0';
	signal sdram_dq_oe		: std_logic := '0';					--output enable
	signal init_cnt			: integer := 0;						--initialization counter value
	signal refresh_cnt		: integer := 0;						--refresh counter

	--sdram commands
	constant cmd_loadmode		: std_logic_vector(2 downto 0) := "000";
	constant cmd_refresh		: std_logic_vector(2 downto 0) := "001";
	constant cmd_precharge		: std_logic_vector(2 downto 0) := "010";
	constant cmd_active 		: std_logic_vector(2 downto 0) := "011";
	constant cmd_write		: std_logic_vector(2 downto 0) := "100";
	constant cmd_read		: std_logic_vector(2 downto 0) := "101";
	constant cmd_nop		: std_logic_vector(2 downto 0) := "111";

	--Timing parameters
	constant tRAS			: integer :=	((sdram_frequency * 44)/1000)+1;	--ACTIVE-to-PRECHARGE command
	constant tRC			: integer :=	((sdram_frequency * 66)/1000)+1;	--ACTIVE-to-ACTIVE command period
	constant tRCD			: integer :=	((sdram_frequency * 20)/1000)+1;	--ACTIVE-to-READ or WRITE delay
	constant tRFC			: integer :=	((sdram_frequency * 66)/1000)+1;	--AUTO REFRESH command period
	constant tRP			: integer :=	((sdram_frequency * 20)/1000)+1;	--PRECHARGE command period
	constant tRRD			: integer :=	((sdram_frequency * 15)/1000)+1;	--ACTIVE bank a to ACTIVE bank b command
	constant tWR			: integer :=	((sdram_frequency * 15)/1000)+1;	--WRITE recovery time
	constant tINIT			: integer :=	(sdram_frequency * 10)+1;		--minimal initialization time
	constant tREF			: integer :=	((sdram_frequency * 1560)/1000)+1;	--REFRESH period (for row)

begin
	state_machine:process(clock) begin
		if rising_edge(clock) then
			case state is
				when "000" =>
					if ((rd_req = '1') or (wr_req = '1')) then	--if read or write request
						sdram_cmd <= cmd_active;		--then activate sdram
						sdram_ba <= adr(21 downto 20);		--and open this bank
						sdram_a <= adr(19 downto 8);		--and this row
						sdram_dqm <= "11";
						state <= "001";				--go to "read or write" state after all
					else
						sdram_cmd <= cmd_nop;			--if no requests then no operation needed
						sdram_ba <= (others => '0');
						sdram_a <= (others => '0');
						sdram_dqm <= "11";
						state <= "000";
					end if;

				when "001" =>
					if (rd_selected = '1') then
						sdram_cmd <= cmd_read;			--run read if read needed
					else
						sdram_cmd <= cmd_write;			--...or write
					end if;
					sdram_ba <= adr_reg(21 downto 20);
					sdram_a(9 downto 0) <= "00" & adr_reg(7 downto 0);
					sdram_a(10) <= '0';
					sdram_dqm <= "00";
					--if row address do not change, repeat prev operation
					if ((rd_selected = '1' and rd_req = '1' and same_row_and_bank = '1') or (rd_selected = '0' and wr_req = '1' and same_row_and_bank = '1')) then
						state <= "001";
					else --else open new bank and row
						state <= "010";
					end if;

				when "010" =>
					sdram_cmd <= cmd_precharge; --closing row
					sdram_ba <= (others => '0');
					sdram_a <= (10 => '1', others => '0');
					sdram_dqm <= "11";
					state <= "011";

				when "011" =>
					sdram_cmd <= cmd_nop;
					sdram_ba <= (others => '0');
					sdram_a <= (others => '0');
					sdram_dqm <= "11";
					if (refresh_cnt = tREF + 1) then
						state <= "101";
					else
						state <= "000";
					end if;

				when "100" =>
					if (init_cnt = tINIT+1) then --initialization
						sdram_cmd <= cmd_precharge;
						sdram_a(10) <= '1';
					elsif (init_cnt = tINIT + tRP + 1 or init_cnt = tINIT + tRP + tRFC + 1) then
						sdram_cmd <= cmd_refresh;
					elsif (init_cnt = tINIT + tRP + 2*tRFC + 1) then
						sdram_cmd <= cmd_loadmode;
						sdram_a(9 downto 0) <= "0000100111";
					elsif (init_cnt = tINIT + tRP + 2*tRFC + 3 + 1) then
						state <= "000";
					else
						sdram_cmd <= cmd_nop;
					end if;

				when "101" =>
					sdram_cmd <= cmd_refresh;
					if ((refresh_cnt > 0) and refresh_cnt < tRFC) then
						sdram_cmd <= cmd_nop;
					elsif (refresh_cnt = tRFC) then
						state <= "000";
					end if;

				when others => null;
			end case;
		end if;
	end process state_machine;


	read_priority:process(rd_req, wr_req) begin --read requests have priority
		rd_now <= rd_req;
	end process read_priority;


	process(clock) begin
		if rising_edge(clock) then
			if (state = "000") then
				rd_selected <= rd_now;
			end if;
		end if;
	end process;


	address_select:process(clock, rd_cycle) begin
		if rising_edge(clock) then
			adr_reg <= adr;
		end if;
	end process address_select;


	output_enable:process(clock) begin
		if rising_edge(clock) then
			if (state = "001") then
				sdram_dq_oe <= wr_selected;
			else
				sdram_dq_oe <= '0';
			end if;
		end if;
	end process output_enable;


	process(clock) begin
		if rising_edge(clock) then
			wr_data1 <= wr_data;
			wr_data2 <= wr_data1;
		end if;
	end process;


	read_valid:process(clock) begin
		if rising_edge(clock) then
			if (state = "001" and rd_selected = '1') then
				rd_pipe_valid <= rd_pipe_valid(2 downto 0) & '1';
			else
				rd_pipe_valid <= rd_pipe_valid(2 downto 0) & '0';
			end if;
		end if;
	end process read_valid;


	read_data:process(clock) begin
		if rising_edge(clock) then
			rd_data <= sdram_dq;
		end if;
	end process read_data;


	init_counter:process(clock) begin
		if rising_edge(clock) then
			if (init_cnt < (tINIT + 2*tRFC + tRP + 3 + 1)) then
				init_cnt <= init_cnt + 1;
			else
				null;
			end if;
		end if;
	end process init_counter;


	refresh_counter:process(clock) begin
		if rising_edge(clock) then
			if (refresh_cnt < tREF + 1) then
				refresh_cnt <= refresh_cnt + 1;
			else
				if (state = "101") then
					refresh_cnt <= 0;
				end if;
			end if;
		end if;
	end process refresh_counter;


	ready			<= '1'			when ((state = "000") or (state = "001"))	else '0';
	adr			<= rd_adr		when (rd_cycle = '1')				else wr_adr;	--address select
	same_row_and_bank	<= '1'			when (adr(21 downto 8) = adr_reg(21 downto 8))	else '0';
	rd_cycle		<= rd_now		when (state = "000")				else rd_selected;
	wr_selected		<= not rd_selected;
	rd_valid		<= rd_pipe_valid(3);

	--command set
	sdram_ras_n		<= sdram_cmd(2);
	sdram_cas_n		<= sdram_cmd(1);
	sdram_wren_n		<= sdram_cmd(0);

	--write
	sdram_dq		<= wr_data2		when sdram_dq_oe = '1'				else (others => 'Z');

	--sdram_clock
	sdram_clk_n		<= not clock;

	sdram_cs_n		<= '0';
	sdram_cke		<= '1';
end rtl;
