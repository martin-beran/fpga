-- Testbench for entity mb5016_cpu

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.types.all;

entity tb_mb5016_cpu is
end entity;

architecture main of tb_mb5016_cpu is
	constant step: delay_length := 1 ns; -- This should be set to simulation resolution
	constant period: delay_length := 20 ns; -- System clock period, 50 MHz
	signal M_A_R_K: integer := 0; -- User-defined mark in simulation waveform
	signal S_T_E_P: std_logic := '0'; -- Each edge is an indicator of a WAIT in simulation waveform
	signal Clk: std_logic := '0';
	signal Rst: std_logic := '1';
	signal Run: std_logic := '0';
	signal Busy, Halted: std_logic;
	signal Irq: std_logic_vector(15 downto 10) := (others=>'0');
	signal AddrBus: word_t;
	signal DataBus: byte_t := (others=>'Z');
	signal Rd, Wr: std_logic;
	signal RegIdx: reg_idx_t := (others=>'0');
	signal RegData: word_t := (others=>'Z');
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
		-- Wait for the next rising edge of the system clock
		procedure CLK_NEXT is
		begin
			wait on Clk until Clk = '1';
			S_T_E_P <= not S_T_E_P;
		end procedure;
		-- Wait for a short time. Useful for checking assertions after setting asynchronous signals.
		procedure TIME_STEP is
		begin
			wait for step;
			S_T_E_P <= not S_T_E_P;
		end procedure;
		-- Set a user-defined mark in simulation waveform
		procedure MARK(id: integer) is
		begin
			M_A_R_K <= id;
			report "MARK " & integer'image(id);
		end;
	begin
		-- Initial reset
		MARK(-1);
		TIME_STEP;
		CLK_NEXT;
		Rst <= '0';
		
		-- TEST: CPU is initially not running
		MARK(1);
		CLK_NEXT;
		assert Busy = '0' severity failure;
		assert Halted = '0' severity failure;
		assert AddrBus = to_word(0) severity failure;
		assert is_byte_z(DataBus) severity failure;
		
		-- TEST: Set a register value
		MARK(2);
		RegIdx <= to_reg_idx(1);
		RegData <= X"1234";
		RegWr <= '1';
		CLK_NEXT;
		RegIdx <= to_reg_idx(10);
		RegData <= X"abcd";
		RegWr <= '1';
		CLK_NEXT;
		RegData <= X"ZZZZ";
		RegWr <= '0';
		CLK_NEXT;
		assert is_word_z(RegData) severity failure;
		CLK_NEXT;
		
		-- TEST: Get a register value
		MARK(3);
		RegIdx <= to_reg_idx(0);
		RegRd <= '1';
		TIME_STEP;
		assert RegData = X"0000" severity failure;
		CLK_NEXT;
		RegIdx <= to_reg_idx(1);
		RegRd <= '1';
		TIME_STEP;
		assert RegData = X"1234" severity failure;
		CLK_NEXT;
		RegIdx <= to_reg_idx(10);
		RegRd <= '1';
		TIME_STEP;
		assert RegData = X"abcd" severity failure;
		CLK_NEXT;
		RegRd <= '0';
		TIME_STEP;
		assert is_word_z(RegData) severity failure;
		
		-- TEST: Execute instruction INC1 R0, R1
		-- R1=0x1234 => R0=0x1235
		MARK(4);
		Run <= '1';
		CLK_NEXT;
		-- Initiate read of 1st byte of instruction
		Run <= '0';
		TIME_STEP;
		assert Busy = '1' severity failure;
		assert AddrBus = X"0000" severity failure;
		assert is_byte_z(DataBus) severity failure;
		assert Rd = '1' severity failure;
		assert Wr = '0' severity failure;
		CLK_NEXT;
		-- Initiate read of 2nd byte of instruction; read 1st byte
		DataBus <= X"08";
		TIME_STEP;
		assert Busy = '1' severity failure;
		assert AddrBus = X"0001" severity failure;
		assert Rd = '1' severity failure;
		assert Wr = '0' severity failure;
		CLK_NEXT;
		-- Read 2nd byte of instruction
		DataBus <= X"01";
		TIME_STEP;
		assert Busy = '1' severity failure;
		assert Rd = '0' severity failure;
		assert Wr = '0' severity failure;
		CLK_NEXT;
		-- Execute instruction
		DataBus <= X"ZZ";
		TIME_STEP;
		assert Busy = '1' severity failure;
		CLK_NEXT;
		-- Instruction done, check result in R0
		RegIdx <= to_reg_idx(0);
		RegRd <= '1';
		TIME_STEP;
		assert Busy = '0' severity failure;
		assert RegData = X"1235" severity failure;
		CLK_NEXT;
		-- Check unchanged source R1
		RegIdx <= to_reg_idx(1);
		RegRd <= '1';
		TIME_STEP;
		assert Busy = '0' severity failure;
		assert RegData = X"1234" severity failure;
		CLK_NEXT;
		-- Check address of next instruction in PC
		RegIdx <= to_reg_idx(reg_idx_pc);
		RegRd <= '1';
		TIME_STEP;
		assert RegData = X"0002" severity failure;
		CLK_NEXT;
		
		-- TEST: Execute instruction LD R2, R1
		-- PC=0x0002, R1=0x1234
		MARK(5);
		Run <= '1';
		CLK_NEXT;
		-- Initiate read of 1st byte of instruction
		Run <= '0';
		TIME_STEP;
		assert Busy = '1' severity failure;
		assert AddrBus = X"0002" severity failure;
		assert Rd = '1' severity failure;
		CLK_NEXT;
		-- Initiate read of 2nd byte of instruction; read 1st byte
		DataBus <= X"0a";
		TIME_STEP;
		assert Busy = '1' severity failure;
		assert AddrBus = X"0003" severity failure;
		assert Rd = '1' severity failure;
		CLK_NEXT;
		-- Read 2nd byte of instruction
		DataBus <= X"21";
		TIME_STEP;
		assert Busy = '1' severity failure;
		assert Rd = '0' severity failure;
		CLK_NEXT;
		-- Initiate load of 1st (low) byte
		DataBus <= X"ZZ";
		TIME_STEP;
		assert Busy = '1' severity failure;
		assert AddrBus = X"1234" severity failure;
		assert Rd = '1' severity failure;
		CLK_NEXT;
		-- Initiate load of 2nd (high) byte; load 1st (low) byte
		DataBus <= X"1a";
		TIME_STEP;
		assert Busy = '1' severity failure;
		assert AddrBus = X"1235" severity failure;
		assert Rd = '1' severity failure;
		CLK_NEXT;
		-- Load 2nd (high) byte
		DataBus <= X"2b";
		TIME_STEP;
		assert Busy = '1' severity failure;
		assert Rd = '0' severity failure;
		CLK_NEXT;
		-- Instruction done, check loaded value in R2
		DataBus <= X"ZZ";
		RegIdx <= to_reg_idx(2);
		RegRd <= '1';
		TIME_STEP;
		assert Busy = '0' severity failure;
		assert RegData = X"2b1a" severity failure;
		CLK_NEXT;

		-- TEST: Execute instruction STO R2, R0
		-- END OF TEST
		MARK(-1);
		CLK_NEXT;
		Rst <= '1';
		CLK_NEXT;
		CLK_NEXT;
		-- If S_T_E_P is not used, it is optimized away by Questa
		report "Testbench finished MARK=" & integer'image(M_A_R_K) & " STEP=" & std_logic'image(S_T_E_P);
		wait;
	end process;

	dut: entity work.mb5016_cpu port map (
		Clk=>Clk, Rst=>Rst,
		Run=>Run, Busy=>Busy, Halted=>Halted,
		Irq=>Irq,
		AddrBus=>AddrBus, DataBus=>DataBus, Rd=>Rd, Wr=>Wr,
		RegIdx=>RegIdx, RegData=>RegData, RegRd=>RegRd, RegWr=>RegWr, RegCsr=>RegCsr
	);
end architecture;