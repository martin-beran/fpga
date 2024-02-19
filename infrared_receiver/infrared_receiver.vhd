-- Infrared receiver demo: the top-level entity

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library lib_io;
use lib_io.pkg_infrared.all;
use lib_io.pkg_led.all;
use lib_io.pkg_reset.all;
use lib_io.pkg_seg7.all;
library lib_util;
use lib_util.pkg_multiplexer.all;

entity infrared_receiver is
	port (
		Clk: std_logic;
		RstBtn: std_logic;
		IR: in std_logic;
		DIG: out std_logic_vector(3 downto 0);
		SEG: out std_logic_vector(7 downto 0);
		LED: out std_logic_vector(1 to 4)
	);
end entity;

architecture main of infrared_receiver is
	signal rst, ack, cp, cp3, ir_ma, ir_ca, ir_err: std_logic;
	signal seg7: seg7_t(3 downto 0);
	signal seg7_sel: natural := 0;
	signal seg7_mux_i: mux_input_t(3 downto 0)(3 downto 0);
	signal seg7_mux_o, wseg7, dp: std_logic_vector(3 downto 0);
	signal ir_addr, ir_cmd, ir_cnt: unsigned(7 downto 0);
	signal debug_led: std_logic_vector(1 to 4);
begin
	-- handle reset button
	reset: reset_button port map (Clk=>Clk, RstBtn=>RstBtn, Rst=>rst);
	-- debugging LEDs
	debug: led_group port map (Clk=>Clk, Rst=>rst, I=>debug_led, LED=>LED);
	-- read from IR receiver
	ir_recv: infrared
		port map (
			Clk=>Clk, Rst=>rst, IR=>IR, Ack=>ack,
			MA=>ir_ma, CA=>ir_ca, Err=>ir_err,
			Addr=>ir_addr, Cmd=>ir_cmd, Cnt=>ir_cnt, DBG=>debug_led
		);
	ir_fsm: block is
		type state_t is (Init, Ready, Msg, Err);
		signal state: state_t := Init;
	begin
		process (Clk, rst) is
		begin
			if rst = '1' then
				state <= Init;
			elsif rising_edge(Clk) then
				case state is
					when Init =>
						seg7_mux_i <= (
							"0000", --  0 = 0
							"1001", --  9 = -
							"1001", --  9 = -
							"1001"  --  9 = -
						);
						cp <= '1';
						dp <= "0000";
						state <= Ready;
					when Ready =>
						Ack <= '0';
						if ir_ma = '1' or ir_ca = '1' then
							state <= Msg;
						elsif ir_err = '1' then
							state <= Err;
						end if;
					when Msg =>
						Ack <= '1';
						seg7_mux_i <= (
							std_logic_vector(ir_addr(7 downto 4)),
							std_logic_vector(ir_addr(3 downto 0)),
							std_logic_vector(ir_cmd(7 downto 4)),
							std_logic_vector(ir_cmd(3 downto 0))
						);
						cp <= '0';
						if to_integer(ir_cnt) < 16 then
							dp <= std_logic_vector(ir_cnt(3 downto 0));
						else
							dp <= (others=>'1');
						end if;
						state <= Ready;
					when Err =>
						Ack <= '1';
						seg7_mux_i <= (
							"1110", -- 14 = E
							"0101", --  5 = r
							"0101", --  5 = r
							"1000"  --  8 = space
						);
						cp <= '1';
						dp <= "0000";
						state <= Ready;
				end case;
			end if;
		end process;
	end block;
	-- display values from IR
	seg7_display: seg7_raw
		port map (
			Clk=>Clk, Rst=>rst,
			Seg7=>seg7, DP=>dp, EnaSeg7=>"1111", EnaDP=>"1111", WSeg7=>wseg7, WDP=>"1111",
			DIG=>DIG, SEG=>SEG
		);
	seg7_dec: seg7_decoder port map (I=>unsigned(seg7_mux_o), CP=>cp3, O=>seg7(0));
	seg7(1) <= seg7(0);
	seg7(2) <= seg7(0);
	seg7(3) <= seg7(0);
	seg7_mux: multiplexer
		generic map (inputs=>4, bits=>4)
		port map (Sel=>seg7_sel, I=>(seg7_mux_i(0), seg7_mux_i(1), seg7_mux_i(2), seg7_mux_i(3)), O=>seg7_mux_o);
	refresh: process (Clk) is
		variable ws: std_logic_vector(3 downto 0) := "0001";
	begin
		if rising_edge(Clk) then
			ws := ws(2 downto 0) & ws(3);
			wseg7 <= ws;
			if seg7_sel = 2 then -- will be incremented to 3
				cp3 <= '0'; -- E from Err
			else
				cp3 <= cp; -- digits or r or space from Err
			end if;
			if seg7_sel = 3 then
				seg7_sel <= 0;
			else
				seg7_sel <= seg7_sel + 1;
			end if;
		end if;
	end process;
end architecture;