-- Testbench for entity mb5016_registers

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.types.all;

entity tb_mb5016_registers is
end entity;

architecture main of tb_mb5016_registers is
	constant period: delay_length := 20 ns; -- 50 MHz
	signal Clk, Rst: std_logic;
	signal RdIdxA, RdIdxB, WrIdxA, WrIdxB: reg_idx_t;
	signal RdDataA, RdDataB, WrDataA, WrDataB: word_t;
	signal WrA, WrB: std_logic;
begin
	clock: process is
		variable state: std_logic;
	begin
		state := not state;
		Clk <= state;
		wait for period / 2;
	end process;
	
	test: process is
	begin
		-- test initial zeros in registers
		Rst <= '0';
		WrA <= '0';
		WrB <= '0';
		
		RdIdxA <= to_reg_idx(0);
		RdIdxB <= to_reg_idx(3);
		wait for period;
		
		--assert RdDataA = to_word(16#0000#) severity failure;
		assert RdDataA = X"0000" severity failure;
		assert RdDataB = X"0000" severity failure;
		-- test write by interface A
		WrIdxA <= to_reg_idx(1);
		WrIdxB <= to_reg_idx(2);
		WrDataA <= X"a0b1";
		WrDataB <= X"b0c1";
		WrA <= '1';
		WrB <= '0';
		RdIdxA <= to_reg_idx(2);
		RdIdxB <= to_reg_idx(1);
		wait for period;
		
		assert RdDataA = X"0000" severity failure;
		assert RdDataB = X"a0b1" severity failure;
		-- test write by interface B
		WrDataA <= X"a1b1";
		WrDataB <= X"b1c1";
		WrA <= '0';
		WrB <= '1';
		wait for period;
		
		assert RdDataA = X"b1c1" severity failure;
		assert RdDataB = X"a0b1" severity failure;
		-- test write by both interfaces
		WrDataA <= X"a2b2";
		WrDataB <= X"b2c2";
		WrA <= '1';
		WrB <= '1';
		WrIdxA <= to_reg_idx(10);
		WrIdxB <= to_reg_idx(15);
		RdIdxA <= to_reg_idx(1);
		RdIdxB <= to_reg_idx(2);
		wait for period;
		
		assert RdDataA = X"a1b1" severity failure;
		assert RdDataB = X"b1c1" severity failure;
		-- test no write, keep previous values
		WrDataA <= X"a3b3";
		WrDataB <= X"b3c3";
		WrA <= '0';
		WrB <= '0';
		RdIdxA <= to_reg_idx(10);
		RdIdxB <= to_reg_idx(15);
		wait for period;
		
		assert RdDataA = X"a2b2" severity failure;
		assert RdDataB = X"b2c2" severity failure;
		wait for period;
		
		-- test reset
		Rst <= '1';
		wait for period;
		Rst <= '0';
		
		assert RdDataA = X"0000" severity failure;
		assert RdDataB = X"0000" severity failure;
		wait for period;

		-- test write collision
		WrDataA <= X"1234";
		WrDataB <= X"abcd";
		WrA <= '1';
		WrB <= '1';
		WrIdxA <= to_reg_idx(0);
		WrIdxB <= to_reg_idx(0);
		RdDataA <= to_reg_idx(0);
		RdDataB <= to_reg_idx(1);
		wait for period;
		
		assert RdDataA = X"1234" severity failure;
		assert RdDataB = X"abcd" severity failure;
	end process;
	
	dut: entity work.mb5016_registers port map (
		Clk=>Clk, Rst=>Rst,
		RdIdxA=>RdIdxA, RdDataA=>RdDataA, RdIdxB=>RdIdxB, RdDataB=>RdDataB,
		WrIdxA=>WrIdxA, WrDataA=>WrDataA, WrA=>WrA, WrIdxB=>WrIdxB, WrDataB=>WrDataB, WrB=>WrB
	);
end architecture;