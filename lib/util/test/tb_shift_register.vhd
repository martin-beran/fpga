-- Testbench for package shift_register

library ieee;
use ieee.std_logic_1164.all;
library lib_util;
use lib_util.pkg_shift_register.all;

entity tb_shift_register_io is
end entity;

architecture main of tb_shift_register_io is
	constant bits: positive := 4;
	subtype data_t is std_logic_vector(bits - 1 downto 0);
	signal Clk: std_logic := '0';
	signal Rst1, R1, W1, ShiftR1, ShiftW1, Serial1: std_logic := '0';
	signal Rst2, R2, W2, ShiftR2, ShiftW2, Serial2L, Serial2R: std_logic := '0';
	signal Data1L, Data1R, Data2: data_t;
begin
	clock: process is
		variable state: std_logic := '0';
	begin
		state := not state;
		Clk <= state;
		wait for 5 ns;
	end process;
	
	ShiftW1 <=
		'1' after 10 ns,
		'0' after 50 ns;
	Serial1 <=
		'1' after 10 ns, '1' after 20 ns, '0' after 30 ns, '1' after 40 ns, '0' after 50 ns;
	R1 <= '1' after 0 ns, '0' after 70 ns, '1' after 100 ns, '0' after 110 ns;
	Rst1 <= '1' after 80 ns, '0' after 90 ns;
	
	W2 <= '1' after 10 ns, '0' after 20 ns, '1' after 100 ns, '0' after 110 ns;
	Data2 <= "1101" after 10 ns, "0000" after 20 ns, "1101" after 100 ns, "0000" after 110 ns;
	ShiftR2 <= '1' after 10 ns, '0' after 60 ns, '1' after 110 ns, '0' after 160 ns;
	
 	dut_serial_w_left: shift_register_io
		generic map (bits=>bits, shift_dir=>left)
		port map (Clk=>Clk, Rst=>Rst1, R=>R1, W=>W1, ShiftR=>ShiftR1, ShiftW=>ShiftW1, Data=>Data1L, Serial=>Serial1);
	dut_serial_w_right: shift_register_io
		generic map (bits=>bits, shift_dir=>right)
		port map (Clk=>Clk, Rst=>Rst1, R=>R1, W=>W1, ShiftR=>ShiftR1, ShiftW=>ShiftW1, Data=>Data1R, Serial=>Serial1);
	dut_serial_r_left: shift_register_io
		generic map (bits=>bits, shift_dir=>left)
		port map (Clk=>Clk, Rst=>Rst2, R=>R2, W=>W2, ShiftR=>ShiftR2, ShiftW=>ShiftW2, Data=>Data2, Serial=>Serial2L);
	dut_serial_r_right: shift_register_io
		generic map (bits=>bits, shift_dir=>right)
		port map (Clk=>Clk, Rst=>Rst2, R=>R2, W=>W2, ShiftR=>ShiftR2, ShiftW=>ShiftW2, Data=>Data2, Serial=>Serial2R);
end architecture;

library ieee;
use ieee.std_logic_1164.all;
library lib_util;
use lib_util.pkg_shift_register.all;

entity tb_shift_register_1dir is
end entity;

architecture main of tb_shift_register_1dir is
	constant bits: positive := 4;
	subtype data_t is std_logic_vector(bits - 1 downto 0);
	signal Clk: std_logic := '0';
	signal Rst, W, ShiftR, ShiftW: std_logic := '0';
	signal SIn, SOutL, SOutR: std_logic;
	signal PIn, POutL, POutR: data_t;
begin
	clock: process is
		variable state: std_logic := '0';
	begin
		state := not state;
		Clk <= state;
		wait for 5 ns;
	end process;

	ShiftW <= '1' after 10 ns, '0' after 50 ns;
	SIn <= '1' after 10 ns, '1' after 20 ns, '0' after 30 ns, '1' after 40 ns, '0' after 50 ns;
	Rst <= '1' after 70 ns, '0' after 80 ns;

	W <= '1' after 100 ns, '0' after 110 ns, '1' after 200 ns, '0' after 210 ns;
	PIn <= "1101" after 100 ns, "0000" after 110 ns, "1101" after 200 ns, "0000" after 210 ns;
	ShiftR <= '1' after 100 ns, '0' after 150 ns, '1' after 210 ns, '0' after 260 ns;

	dut_serial_left: shift_register_1dir
		generic map (bits=>bits, shift_dir=>left)
		port map (Clk=>Clk, Rst=>Rst, W=>W, ShiftR=>ShiftR, ShiftW=>ShiftW, SIn=>SIn, SOut=>SOutL, PIn=>PIn, POut=>POutL);
	dut_serial_right: shift_register_1dir
		generic map (bits=>bits, shift_dir=>right)
		port map (Clk=>Clk, Rst=>Rst, W=>W, ShiftR=>ShiftR, ShiftW=>ShiftW, SIn=>SIn, SOut=>SOutR, PIn=>PIn, POut=>POutR);
end architecture;