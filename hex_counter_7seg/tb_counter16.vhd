library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common.all;

entity tb_counter16 is
end entity;

architecture main of tb_counter16 is
	signal clk: std_logic := '0';
	signal N: val_t;
begin
	process is
	begin
		wait for 10 ns;
		clk <= not clk;
	end process;
	dut: entity work.counter16 generic map (period=>10) port map (clk=>clk, N=>N);
end architecture;