-- Testbench for entity mb5016_registers

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.types.all;

entity tb_mb5016_registers is
end entity;

architecture main of tb_mb5016_registers is
	constant period: delay_length := 20 ns; -- 50 MHz
	signal Clk, Rst: std_logic := '0';
	signal IdxA, IdxB: reg_idx_t := to_reg_idx(0);
	signal RdDataA, RdDataB, WrDataA, WrDataB: word_t := X"0000";
	signal WrA, WrB: std_logic := '0';
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
		-- TEST: initial zeros in registers
		IdxA <= to_reg_idx(0);
		IdxB <= to_reg_idx(3);
		wait for period;
		assert RdDataA = X"0000" severity failure;
		assert RdDataB = X"0000" severity failure;

		-- TEST: write by interface A
		IdxA <= to_reg_idx(1);
		IdxB <= to_reg_idx(2);
		WrDataA <= X"a0b1";
		WrDataB <= X"b0c1";
		WrA <= '1';
		WrB <= '0';
		wait for period;
		IdxA <= to_reg_idx(2);
		IdxB <= to_reg_idx(1);
		WrA <= '0';
		wait for period;
		assert RdDataA = X"0000" severity failure;
		assert RdDataB = X"a0b1" severity failure;

		-- TEST: write by interface B
		IdxA <= to_reg_idx(1);
		IdxB <= to_reg_idx(2);
		WrDataA <= X"a1b1";
		WrDataB <= X"b1c1";
		WrA <= '0';
		WrB <= '1';
		wait for period;
		IdxA <= to_reg_idx(2);
		IdxB <= to_reg_idx(1);
		WrB <= '0';
		wait for period;
		assert RdDataA = X"b1c1" severity failure;
		assert RdDataB = X"a0b1" severity failure;

		-- TEST: write by both interfaces
		IdxA <= to_reg_idx(10);
		IdxB <= to_reg_idx(15);
		WrDataA <= X"a2b2";
		WrDataB <= X"b2c2";
		WrA <= '1';
		WrB <= '1';
		wait for period;
		IdxA <= to_reg_idx(1);
		IdxB <= to_reg_idx(2);
		WrA <= '0';
		WrB <= '0';
		wait for period;
		-- no write, check keep previous values in r1, r2
		assert RdDataA = X"a0b1" severity failure;
		assert RdDataB = X"b1c1" severity failure;
		IdxA <= to_reg_idx(10);
		IdxB <= to_reg_idx(15);
		-- these value will not be written
		WrDataA <= X"a3b3";
		WrDataB <= X"b3c3";
		WrA <= '0';
		WrB <= '0';
		wait for period;
		-- check previously written values
		assert RdDataA = X"a2b2" severity failure;
		assert RdDataB = X"b2c2" severity failure;
		wait for period;

		-- TEST: reset
		Rst <= '1';
		wait for period;
		Rst <= '0';

		assert RdDataA = X"0000" severity failure;
		assert RdDataB = X"0000" severity failure;
		wait for period;

		-- TEST: write collision
		IdxA <= to_reg_idx(0);
		IdxB <= to_reg_idx(0);
		WrDataA <= X"1234";
		WrDataB <= X"abcd";
		WrA <= '1';
		WrB <= '1';
		wait for period;
		WrA <= '0';
		WrB <= '0';
		wait for period;
		assert RdDataA = X"1234" severity failure;
		assert RdDataB = X"1234" severity failure;
		wait for period;

		-- END OF TEST
		Rst <= '1';
		wait for 2 * period;
		report "Testbench finished";
		wait;
	end process;

	dut: entity work.mb5016_registers port map (
		Clk=>Clk, Rst=>Rst,
		IdxA=>IdxA, RdDataA=>RdDataA, IdxB=>IdxB, RdDataB=>RdDataB,
		WrDataA=>WrDataA, WrA=>WrA, WrDataB=>WrDataB, WrB=>WrB
	);
end architecture;