-- CPU MB5016: CU (Control Unit)
-- The CU connects and controls other components of the CPU. It fetches and executes instructions,
-- routes data, and communicates with the CDI (Control and Debugging Interface)

use work.types.all;

package pkg_mb5016_cu is
	-- Routing data to address bus
	type addr_bus_route_t is (
		AddrRegA, -- From register at interface A
		AddrRegB -- From register at interface B
	);
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
use work.pkg_mb5016_alu.all;

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
		-- CPU is halted (by an exception when interrupts are disabled)
		Halted: out std_logic;
		-- Generate an exception
		Exception: out std_logic;
		-- Disable interrupts
		DisableIntr: out std_logic;
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
		-- Which flags an instruction can modify
		RegWrFlags: out flags_t;
		-- Current value of register F (r14)
		RegRdF: in word_t;
		-- Current value of register PC (r15)
		RegRdPc: in word_t;
		-- Select ALU operation
		AluOp: out op_t;
		-- Select routing (source register) for address bus value
		AddrBusRoute: out addr_bus_route_t;
		-- Value added to address bus value (0=first, 1=second byte of a word)
		AddrBusAdd: out std_logic;
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
			Halt, -- CPU halted (due to an exception when interrupts are disabled)
			IntrHnd, -- Called interrupt handler
			IGetOpcode, -- Reading opcode (1st byte of an instruction)
			IGetRegisters, -- Reading source and destination registers (2nd byte of an instruction)
			IDecode, -- Decode an instruction
			Load2, -- Load of 2nd byte initiated, or waiting for a single byte load
			Loaded1, -- 1st byte loaded
			Loaded, -- Load finished
			IncSrcReg, -- Increment source register by 2 after a load
			Store2, -- Store the second byte of a register to memory
			RetiPc, -- Set register PC in instruction RETI
			RetiIa -- Set register IA in instruction RETI
		);
		signal state: state_t := Init;

		procedure init_signals is
		begin
			Exception <= '0';
			DisableIntr <= '0';
			RegIdxA <= to_reg_idx(0);
			RegIdxB <= to_reg_idx(0);
			RegWrA <= '0';
			RegWrB <= '0';
			CsrRd <= '0';
			CsrWr <= '0';
			EnaCsr0H <= '0';
			RegWrFlags <= (others=>'0');
			AluOp <= OpMv;
			AddrBusRoute <= AddrRegA;
			AddrBusAdd <= '0';
			DataBusRoute <= FromRegAH;
			MemRd <= '0';
			MemWr <= '0';
		end procedure;

		type decoded_t is record
			is_implemented: boolean; -- if true then all other elements are ignored
			alu_op: op_t; -- ignored for instructions that do not use ALU
			is_condition, is_load1, is_load2, is_alu, is_flags, is_store1, is_store2: boolean;
		end record;

		pure function decode_opcode(opcode: byte_t) return decoded_t is
		begin
			case opcode is
				when OpcodeAdd     => return ( true,    OpAdd, false, false, false,  true,  true, false, false);
				when OpcodeAnd     => return ( true,    OpAnd, false, false, false,  true,  true, false, false);
				when OpcodeCmps    => return ( true,   OpCmps, false, false, false,  true,  true, false, false);
				when OpcodeCmpu    => return ( true,   OpCmpu, false, false, false,  true,  true, false, false);
				when OpcodeCsrr    => return ( true,   OpExch, false, false, false,  true, false, false, false);
				when OpcodeCsrw    => return ( true,   OpExch, false, false, false,  true, false, false, false);
				when OpcodeDdsto   => return (false,     OpMv, false, false, false,  true, false,  true,  true);
				when OpcodeDec1    => return ( true,   OpDec1, false, false, false,  true,  true, false, false);
				when OpcodeDec2    => return ( true,   OpDec2, false, false, false,  true,  true, false, false);
				when OpcodeExch    => return ( true,   OpExch, false, false, false,  true, false, false, false);
				when OpcodeExchnf  => return (false,   OpExch,  true, false, false,  true, false, false, false);
				when OpcodeInc1    => return ( true,   OpInc1, false, false, false,  true,  true, false, false);
				when OpcodeInc2    => return ( true,   OpInc2, false, false, false,  true,  true, false, false);
				when OpcodeIll     => return ( true,     OpMv, false, false, false, false, false, false, false);
				when OpcodeLd      => return ( true,     OpMv, false,  true,  true, false, false, false, false);
				when OpcodeLdb     => return ( true,     OpMv, false,  true, false, false, false, false, false);
				when OpcodeLdis    => return ( true,   OpInc2, false,  true,  true,  true, false, false, false);
				when OpcodeLdisx   => return (false,   OpInc2, false,  true,  true,  true, false, false, false);
				when OpcodeLdnf    => return ( true,     OpMv,  true,  true,  true, false, false, false, false);
				when OpcodeLdnfis  => return ( true,   OpInc2,  true,  true,  true,  true, false, false, false);
				when OpcodeLdxnfis => return (false,   OpInc2,  true,  true,  true,  true, false, false, false);
				when OpcodeMv      => return ( true,   OpExch, false, false, false,  true, false, false, false);
				when OpcodeMvnf    => return ( true,   OpExch,  true, false, false,  true, false, false, false);
				when OpcodeNeg     => return (false,    OpNot, false, false, false,  true,  true, false, false);
				when OpcodeNot     => return ( true,    OpNot, false, false, false,  true,  true, false, false);
				when OpcodeOr      => return ( true,     OpOr, false, false, false,  true,  true, false, false);
				when OpcodeReti    => return ( true, OpRetiIe, false, false, false,  true, false, false, false);
				when OpcodeRev     => return ( true,    OpRev, false, false, false,  true,  true, false, false);
				when OpcodeShl     => return ( true,    OpShl, false, false, false,  true,  true, false, false);
				when OpcodeShr     => return ( true,    OpShr, false, false, false,  true,  true, false, false);
				when OpcodeShra    => return ( true,   OpShra, false, false, false,  true,  true, false, false);
				when OpcodeSto     => return ( true,     OpMv, false, false, false, false, false,  true,  true);
				when OpcodeStob    => return ( true,     OpMv, false, false, false, false, false,  true, false);
				when OpcodeSub     => return ( true,    OpSub, false, false, false,  true,  true, false, false);
				when OpcodeXor     => return ( true,    OpXor, false, false, false,  true,  true, false, false);
				when others        => return (false,     OpMv, false, false, false, false, false, false, false);
			end case;
		end function;

	begin
		Busy <= '0' when state = Init or state = Halt else '1';
		Halted <= '1' when state = Halt else '0';

		process (Clk, Rst) is
			variable opcode: byte_t;
			variable dst_reg, src_reg: reg_idx_t;
			variable decoded: decoded_t;
			variable cond: boolean;

			procedure read_instr_byte is
			begin
				RegIdxA <= to_reg_idx(reg_idx_pc);
				RegIdxB <= to_reg_idx(reg_idx_pc);
				AddrBusRoute <= AddrRegB;
				MemRd <= '1';
				RegWrA <= '1';
				AluOp <= OpInc1;
			end procedure;
	
			procedure decode_regs is
			begin
				dst_reg := DataBus(7 downto 4);
				src_reg := DataBus(3 downto 0);
			end procedure;

			procedure illegal_instruction(reason: op_t) is
			begin
				Exception <= '1';
				RegIdxA <= to_reg_idx(0);
				RegWrA <= '1';
				CsrWr <= '1';
				EnaCsr0H <= '1';
				AluOp <= reason;
				state <= Init;
			end;
			
			procedure store(addr_add: std_logic; data: data_bus_route_t) is
			begin
				RegIdxA <= dst_reg;
				RegIdxB <= src_reg;
				AddrBusRoute <= AddrRegA;
				AddrBusAdd <= addr_add;
				DataBusRoute <= data;
				MemWr <= '1';
			end procedure;
			
		begin
			if Rst = '1' then
				init_signals;
				state <= Init;
			elsif rising_edge(Clk) then
				init_signals;
				case state is
					when Init =>
						if Run = '1' then
							if RegRdF(flags_idx_ie) = '1' and RegRdF(15 downto 9) /= "0000000" then
								-- Call interrupt handler
								DisableIntr <= '1';
								RegIdxA <= to_reg_idx(reg_idx_ia);
								RegIdxB <= to_reg_idx(reg_idx_pc);
								RegWrA <= '1';
								RegWrB <= '1';
								AluOp <= OpExch;
								state <= IntrHnd;
							elsif RegRdF(flags_idx_ie) = '0' and RegRdF(flags_idx_exc) = '1' then
								-- Exception with disabled interrupts
								state <= Halt;
							else
								-- Run the next instruction
								read_instr_byte;
								state <= IGetOpcode;
							end if;
						end if;
					when Halt =>
						if not (RegRdF(flags_idx_ie) = '0' and RegRdF(flags_idx_exc) = '1') then
							state <= Init;
						end if;
					when IntrHnd =>
						-- A separate state in order to signal Busy here, instead of reusing Init (would be not Busy)
						read_instr_byte;
						state <= IGetOpcode;
					when IGetOpcode =>
						read_instr_byte; -- Initiate read of src, dst registers, increment register pc
						state <= IGetRegisters;
					when IGetRegisters =>
						opcode := DataBus;
						state <= IDecode;
					when IDecode =>
						decoded := decode_opcode(opcode);
						decode_regs;
						if decoded.is_condition then
							cond := RegRdF(to_integer(opcode(2 downto 0))) = opcode(3);
						else
							cond := true;
						end if;
						if not decoded.is_implemented then
							illegal_instruction(OpConstExcIInstr);
						elsif opcode = OpcodeIll then
							illegal_instruction(OpConstExcIZero);
						elsif cond and decoded.is_load1 then
							RegIdxB <= src_reg;
							AddrBusRoute <= AddrRegA;
							AddrBusAdd <= '0';
							MemRd <= '1';
							state <= Load2;
						elsif cond and decoded.is_alu then
							RegIdxA <= dst_reg;
							RegIdxB <= src_reg;
							RegWrA <= '1';
							RegWrB <= '1';
							RegWrFlags <= (others=>'1');
							AluOp <= decoded.alu_op;
							state <= Init;
							case opcode is
								when OpcodeCsrr =>
									RegWrB <= '0';
									CsrRd <= '1';
									RegWrFlags <= (others=>'0');
								when OpcodeCsrw =>
									RegWrA <= '0';
									RegWrB <= '0';
									CsrWr <= '1';
									RegWrFlags <= (others=>'0');
								when OpcodeExch =>
									RegWrFlags <= (others=>'0');
								when OpcodeMv | OpcodeMvnf =>
									RegWrB <= '0';
									RegWrFlags <= (others=>'0');
								when OpcodeReti =>
									RegIdxA <= to_reg_idx(reg_idx_f);
									RegIdxB <= to_reg_idx(reg_idx_f);
									RegWrFlags <= (others=>'0');
									state <= RetiPc;
								when others =>
									null;
							end case;
						elsif decoded.is_store1 then
							store('0', FromRegBL);
							if decoded.is_store2 then
								state <= Store2;
							else
								state <= Init;
							end if;
						else
							state <= Init; -- Conditional instruction that does nothing in the false branch
						end if;
					when Load2 =>
						if decoded.is_load2 then
							RegIdxB <= src_reg;
							AddrBusRoute <= AddrRegA;
							AddrBusAdd <= '1';
							MemRd <= '1';
							state <= Loaded1;
						else
							state <= Loaded;
						end if;
					when Loaded1 =>
						RegIdxA <= dst_reg;
						RegWrA <= '1';
						DataBusRoute <= ToRegAL;
						state <= Loaded;
					when Loaded =>
						RegIdxA <= dst_reg;
						RegWrA <= '1';
						if decoded.is_load2 then
							DataBusRoute <= ToRegAH;
						else
							DataBusRoute <= ToRegAL;
						end if;
						case opcode is
							when OpcodeLdis | OpcodeLdnf =>
								state <= IncSrcReg;
							when others =>
								state <= Init;
						end case;
					when IncSrcReg =>
						RegIdxA <= src_reg;
						RegIdxB <= src_reg;
						RegWrA <= '1';
						AluOp <= OpInc2;
						state <= Init;
					when Store2 =>
						store('1', FromRegBH);
						state <= Init;
					when RetiPc =>
						RegIdxA <= to_reg_idx(reg_idx_pc);
						RegIdxB <= to_reg_idx(reg_idx_ia);
						RegWrA <= '1';
						AluOp <= OpExch;
						state <= RetiIa;
					when RetiIa =>
						RegIdxA <= to_reg_idx(reg_idx_ia);
						RegIdxB <= to_reg_idx(1);
						RegWrA <= '1';
						CsrRd <= '1';
						AluOp <= OpExch;
						state <= Init;
				end case;
			end if;
		end process;
	end block;
end architecture;