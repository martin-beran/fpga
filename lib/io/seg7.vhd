-- Control of 7-segment display

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library lib_io;
use lib_io.pkg_crystal.crystal_hz;

package pkg_seg7 is
	-- state of display segments
	type seg7_t is array(natural range <>) of std_logic_vector(6 downto 0);

	-- control of idividual segments of the display
	component seg7_raw is
		generic (
			-- digit multiplexer frequency (1000 Hz)
			multiplex: positive := crystal_hz / 1000;
			-- the number of digits of the display
			digits: positive := 4;
			-- use inverted logical levels ('0' for on)
			inverted: boolean := true
		);
		port (
			-- the master system clock
			Clk: in std_logic;
			-- reset and turn the display off
			Rst: in std_logic;
			-- state of display segments (registered)
			Seg7: in seg7_t(digits - 1 downto 0);
			-- state of decimal points (registered)
			DP: in std_logic_vector(digits - 1 downto 0);
			-- enable (turn on) digits (unregistered)
			-- blinking can be easily implemented using EnaSeg7 and  EnaDP 
			EnaSeg7: in std_logic_vector(digits - 1 downto 0);
			-- enable (turn on) decimal points (unregistered)
			EnaDP: in std_logic_vector(digits - 1 downto 0);
			-- select digits to be updated by Seg7
			WSeg7: in std_logic_vector(digits - 1 downto 0);
			-- select decimal points to be updated by DP
			WDP: in std_logic_vector(digits - 1 downto 0);
			-- multiplexing digits
			DIG: out std_logic_vector(digits - 1 downto 0);
			-- control segments of the current digit (7 = decimal point)
			SEG: out std_logic_vector(7 downto 0)
		);
	end component;
	
	-- decoder of input numbers or character codes to display segments
	-- It supports two code pages of digits and symbols:
	-- CP=0 contains hexadecimal digits
	-- CP=1 contains some additional symbols
	component seg7_decoder is
		port (
			-- the input digit (CP=0) or character (CP=1)
			I: in unsigned(3 downto 0);
			-- the code page
			CP: in std_logic;
			-- output segments
			O: out std_logic_vector(6 downto 0)
		);
	end component;
end package;

--- seg7_raw ------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library lib_util;
use lib_util.pkg_multiplexer.all;
library lib_io;
use lib_io.pkg_seg7.all;

entity seg7_raw is
	generic (
		multiplex: positive;
		digits: positive;
		inverted: boolean
	);
	port (
		Clk, Rst: in std_logic;
		Seg7: in seg7_t(digits - 1 downto 0);
		DP, EnaSeg7, EnaDP, WSeg7, WDP: in std_logic_vector(digits - 1 downto 0);
		DIG: out std_logic_vector(digits - 1 downto 0);
		SEG: out std_logic_vector(7 downto 0)
	);
end entity;

architecture main of seg7_raw is
	subtype memory_t is mux_input_t(digits - 1 downto 0)(7 downto 0);
	signal memory: memory_t := (others=>(others=>'0'));
	signal dig_sel: natural range digits - 1 downto 0 := 0;
	signal dig_state: std_logic_vector(digits - 1 downto 0) := (0=>'1', others=>'0');
	signal seg_state0, seg_state1: std_logic_vector(7 downto 0);
	subtype ena_t is mux_input_t(digits - 1 downto 0)(0 downto 0);
	signal ena_seg7_i, ena_dp_i: ena_t;
	signal ena_seg7, ena_dp: std_logic_vector(0 downto 0);
begin
	DIG <= not dig_state when inverted else dig_state;
	SEG <= not seg_state1 when inverted else seg_state1;
	seg_gen: for i in 0 to 6 generate
	begin
		seg_state1(i) <= seg_state0(i) and ena_seg7(0);
	end generate;
	seg_state1(7) <= seg_state0(7) and ena_dp(0);
	ena_gen: for i in digits - 1 downto 0 generate
	begin
		ena_seg7_i(i)(0) <= EnaSeg7(i);
		ena_dp_i(i)(0) <= EnaDP(i);
	end generate;
	
	mux: multiplexer generic map (inputs=>digits, bits=>8) port map (Sel=>dig_sel, I=>memory, O=>seg_state0);
	mux_ena_seg7: multiplexer generic map (inputs=>digits, bits=>1) port map (Sel=>dig_sel, I=>ena_seg7_i, O=>ena_seg7);
	mux_ena_dp: multiplexer generic map (inputs=>digits, bits=>1) port map (Sel=>dig_sel, I=>ena_dp_i, O=>ena_dp);
	
	mux_clk: process (Clk) is
		variable m: natural := 0;
	begin
		if rising_edge(Clk) and digits > 1 then
			-- Rst not needed by multiplexing
			if m = multiplex - 1 then
				m := 0;
				dig_state <= dig_state(digits - 2 downto 0) & dig_state(digits - 1);
				if dig_sel = digits - 1 then
					dig_sel <= 0;
				else
					dig_sel <= dig_sel + 1;
				end if;
			else
				m := m + 1;
			end if;
		end if;
	end process;
	
	wr: for i in 0 to digits - 1 generate
	begin
		seg: process (Clk, Rst) is
		begin
			if (Rst) then
				memory(i) <= (others=>'0');
			elsif rising_edge(Clk) then
				if WSeg7(i) then
					memory(i)(6 downto 0) <= Seg7(i);
				end if;
				if WDP(i) then
					memory(i)(7) <= DP(i);
				end if;
			end if;
		end process;
	end generate;
end architecture;

--- seg7_decoder --------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity seg7_decoder is
	port (
		I: in unsigned(3 downto 0);
		CP: in std_logic;
		O: out std_logic_vector(6 downto 0)
	);
end entity;

architecture main of seg7_decoder is
	type decoder_t is array (0 to 1, 0 to 15) of std_logic_vector(6 downto 0);
	constant decoder: decoder_t := (
		0=>(
			"0111111", --  0 = 0     000
			"0000110", --  1 = 1    5   1
			"1011011", --  2 = 2    5   1
			"1001111", --  3 = 3     666
			"1100110", --  4 = 4    4   2
			"1101101", --  5 = 5    4   2
			"1111101", --  6 = 6     333
			"0000111", --  7 = 7
			"1111111", --  8 = 8
			"1101111", --  9 = 9
			"1110111", -- 10 = A
			"1111100", -- 11 = b
			"0111001", -- 12 = C
			"1011110", -- 13 = d
			"1111001", -- 14 = E
			"1110001"  -- 15 = F
		),
		1=>(
			"1110110", --  0 = H
			"0011110", --  1 = J
			"0111000", --  2 = L
			"1011100", --  3 = o
			"1110011", --  4 = P
			"1010000", --  5 = r
			"0111110", --  6 = U
			"0000000", --  7 =   (space, reserved)
			"0000000", --  8 =   (space)
			"1000000", --  9 = - (minus)
			"0001000", -- 10 = _ (underscore, low level mark)
			"1001000", -- 11 = = (segments 3, 6, medium level mark)
			"1001001", -- 12 =   (segments 0, 3, 6, high level mark)
			"0000000", -- 13 =   (space, reserved)
			"0000000", -- 14 =   (space, reserved)
			"0000000"  -- 15 =   (space, reserved)
		)
	);
begin
	O <= decoder(to_integer(unsigned'("" & CP)), to_integer(I));
end architecture;