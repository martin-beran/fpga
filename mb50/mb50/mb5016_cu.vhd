-- CPU MB5016: CU (Control Unit)
-- The CU connects and controls other components of the CPU. It fetches and executes instructions,
-- routes data, and communicates with the CDI (Control and Debugging Interface)

use work.types.all;

package pkg_mb5016_cu is
	-- Routing data to/from data bus
	type data_bus_route_t is (
		FromRegAH, -- High byte from register at interface A to memory
		FromRegAL, -- Low byte from register at interface A to memory
		FromRegBH, -- High byte from register at interface B to memory
		FromRegBL, -- Low byte from register at interface B to memory
		ToRegAH, -- From memory to high byte of register at interface A
		ToRegAL, -- From memory to low byte of register at interface A
		ToRegBH, -- From memory to high byte of register at interface B
		ToRegBL -- From memory to low byte of register at interface B
	);
	-- Opcodes of instructions
	constant OpcodeAdd: byte_t := X"01";
	constant OpcodeAnd: byte_t := X"02";
	constant OpcodeCmps: byte_t := X"1b";
	constant OpcodeCmpu: byte_t := X"19";
	constant OpcodeCsrr: byte_t := X"03";
	constant OpcodeCsrw: byte_t := X"04";
	constant OpcodeDdsto: byte_t := X"17";
	constant OpcodeDec1: byte_t := X"05";
	constant OpcodeDec2: byte_t := X"06";
	constant OpcodeExch: byte_t := X"07";
	constant OpcodeExchnf: byte_t := X"80";
	constant OpcodeInc1: byte_t := X"08";
	constant OpcodeInc2: byte_t := X"09";
	constant OpcodeIll: byte_t := X"00";
	constant OpcodeLd: byte_t := X"0a";
	constant OpcodeLdb: byte_t := X"0b";
	constant OpcodeLdis: byte_t := X"0c";
	constant OpcodeLdisx: byte_t := X"0d";
	constant OpcodeLdnf: byte_t := X"90";
	constant OpcodeLdnfis: byte_t := X"a0";
	constant OpcodeLdxnfis: byte_t := X"b0";
	constant OpcodeMv: byte_t := X"0e";
	constant OpcodeMvnf: byte_t := X"c0";
	constant OpcodeNeg: byte_t := X"0f";
	constant OpcodeNot: byte_t := X"10";
	constant OpcodeOr: byte_t := X"11";
	constant OpcodeReti: byte_t := X"1c";
	constant OpcodeRev: byte_t := X"1d";
	constant OpcodeShl: byte_t := X"12";
	constant OpcodeShr: byte_t := X"13";
	constant OpcodeShra: byte_t := X"14";
	constant OpcodeSto: byte_t := X"15";
	constant OpcodeStob: byte_t := X"16";
	constant OpcodeSub: byte_t := X"18";
	constant OpcodeXor: byte_t := X"1a";
end package;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.types.all;
use work.pkg_mb5016_cu.all;
use work.pkg_mb5016_alu;

entity mb5016_cu is
	port (
		-- CPU clock
		Clk: in std_logic;
		-- Reset (stops the CPU)
		Rst: in std_logic;
		-- Execute the next instruction
		Run: in std_logic;
		-- Executing an instruction
		Busy: out std_logic;
		-- Generate an exception
		Exception: out std_logic;
		-- Select the first (destination) register argument of an instruction
		RegIdxA: out reg_idx_t;
		-- Select the second (source) register argument of an instruction
		RegIdxB: out reg_idx_t;
		-- Write to the first register argument of an instruction
		RegWrA: out std_logic;
		-- Write to the second register argument of an instruction
		RegWrB: out std_logic;
		-- Read the second (destination) argument of an instruction from a CSR
		CsrRd: out std_logic;
		-- Use a CSR for writing the first (result) argument of an instruction
		CsrWr: out std_logic;
		-- Enable writing of csr0 bit H
		EnaCsr0H: out std_logic;
		-- Value of csr1
		Csr1Data: out word_t;
		-- Which flags an instruction can modify
		RegWrFlags: out flags_t;
		-- Current value of register F (r14)
		RegRdF: in word_t;
		-- Current value of register PC (r15)
		RegRdPc: in word_t;
		-- Select ALU operation
		AluOp: out pkg_mb5016_alu.op_t;
		-- Select routing (source register) for address bus value: 0=RegIdxA, 1=RegIdxB
		AddrBusRoute: out std_logic;
		-- Select routing of data to/from data bus
		DataBusRoute: out data_bus_route_t;
		-- Data bus, used only to read instructions
		DataBus: in byte_t;
		-- Memory read
		MemRd: out std_logic;
		-- Memory write
		MemWr: out std_logic
	);
end entity;

architecture main of mb5016_cu is
begin
	-- The main FSM that controls the CPU
	cu_fsm: block is
		type state_t is (
			Init, -- Initial state, CPU stopped
			IGetOpcode, -- Reading opcode (1st byte of an instruction)
			IGetRegisters, -- Reading source and destination registers (2nd byte of an instruction)
			IExec -- Start executing an instruction
		);
		signal state: state_t := Init;
		procedure init_signals is
		begin
			Exception <= '0';
			RegIdxA <= to_reg_idx(0);
			RegIdxB <= to_reg_idx(0);
			RegWrA <= '0';
			RegWrB <= '0';
			CsrRd <= '0';
			CsrWr <= '0';
			EnaCsr0H <= '0';
			Csr1Data <= (others=>'0');
			RegWrFlags <= (others=>'0');
			AluOp <= pkg_mb5016_alu.OpMv;
			AddrBusRoute <= '0';
			DataBusRoute <= FromRegAH;
			MemRd <= '0';
			MemWr <= '0';
		end procedure;
		procedure read_instr_byte is
		begin
			RegIdxA <= to_reg_idx(reg_idx_pc);
			RegIdxB <= to_reg_idx(reg_idx_pc);
			AddrBusRoute <= '1';
			MemRd <= '1';
			RegWrA <= '1';
			AluOp <= pkg_mb5016_alu.OpInc1;
		end procedure;
	begin
		Busy <= '0' when state = Init else '1';

		process (Clk, Rst) is
			variable opcode: byte_t;
			variable dst_reg, src_reg: reg_idx_t;
		begin
			if Rst = '1' then
				init_signals;
				state <= Init;
			elsif rising_edge(Clk) then
				init_signals;
				case state is
					when Init =>
						if Run = '1' then
							read_instr_byte; -- Initiate read of the opcode, increment register pc
							state <= IGetOpcode;
						end if;
					when IGetOpcode =>
						read_instr_byte; -- Initiate read of src, dst registers, increment register pc
						state <= IGetRegisters;
					when IGetRegisters =>
						opcode := DataBus;
						state <= IExec;
					when IExec =>
						dst_reg := DataBus(7 downto 4);
						src_reg := DataBus(3 downto 0);
						-- TODO
				end case;
			end if;
		end process;
	end block;
end architecture;