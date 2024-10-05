-- Testbench for entity mb5016_cpu

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.types.all;

entity tb_mb5016_cpu is
end entity;

architecture main of tb_mb5016_cpu is
	constant period: delay_length := 20 ns; -- 50 MHz
	signal Clk, Rst, Run: std_logic := '0';
	signal Busy, Halted: std_logic;
	signal Irq: std_logic_vector(15 downto 10) := (others=>'0');
	signal AddrBus: word_t;
	signal DataBus: byte_t;
	signal Rd, Wr: std_logic;
	signal RegIdx: reg_idx_t := (others=>'0');
	signal RegData: word_t;
	signal RegRd, RegWr, RegCsr: std_logic := '0';
begin
	clock: process is
		variable state: std_logic := '0';
	begin
		state := not state;
		Clk <= state;
		wait for period / 2;
	end process;

	test: process is
	begin
		-- END OF TEST
		Rst <= '1';
		wait for 2 * period;
		report "Testbench finished";
		wait;
	end process;

	dut: entity work.mb5016_cpu port map (
		Clk=>Clk, Rst=>Rst,
		Run=>Run, Busy=>Busy, Halted=>Halted,
		Irq=>Irq,
		AddrBus=>AddrBus, DataBus=>DataBus, Rd=>Rd, Wr=>Wr,
		RegData=>RegData, RegRd=>RegRd, RegWr=>RegWr, RegCsr=>RegCsr
	);
end architecture;