-- MB50: CDI (Control and Debugging Interface)

library ieee, lib_io;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.types.all;
use lib_io.pkg_uart;

entity cdi is
	port (
		-- CPU clock
		Clk: in std_logic;
		-- Reset
		Rst: in std_logic;
		-- RS-232 interface transmit pin
		UartTxD: out std_logic;
		-- RS-232 interface receive pin
		UartRxD: in std_logic;
		-- Connected to CPU signal Run
		CpuRun: out std_logic;
		-- Connected to CPU signal Busy
		CpuBusy: in std_logic;
		-- Connected to CPU signal Halted
		CpuHalted: in std_logic;
		-- Connected to CPU signal RegIdx
		CpuRegIdx: out reg_idx_t;
		-- Connected to CPU signal RegDataRd
		CpuRegDataRd: in word_t;
		-- Connected to CPU signal RegDataWr
		CpuRegDataWr: out word_t;
		-- Connected to CPU signal RegRd
		CpuRegRd: out std_logic;
		-- Connected to CPU signal RegWr
		CpuRegWr: out std_logic;
		-- Connected to CPU signal RegCsr
		CpuRegCsr: out std_logic;
		-- Address bus for direct access to memory
		AddrBus: out addr_t;
		-- Data bus for direct reading from memory
		DataBusRd: in byte_t;
		-- Data bus for direct write to memory
		DataBusWr: out byte_t;
		-- Direct read from memory (valid address on AddrBus, expects data in a later Clk cycle on DataBusRd)
		Rd: out std_logic;
		-- Direct write to memory (valid address on AddrBus, valid data on DataBusWr)
		Wr: out std_logic
	);
	subtype UartData is std_logic_vector(7 downto 0); -- Data type of the serial port
	-- CDI reguests (received from the debugger) ------------------------------
	-- Request for a status, expects RespStatus
	constant ReqStatus: UartData := X"00";
	-- Request for executing a single instruction, expects RespStatus
	constant ReqStep: UartData := X"01";
	-- CDI responses (sent to the debugger) -----------------------------------
	-- Returned for an unknown request code
	constant RespUnknownReq: UartData := X"00";
	-- System status, followed by bytes:
	-- 1. '0000000H'; H = CPU signal Halted
	-- 2. lower byte of register PC
	-- 3. upper byte of register PC
	constant RespStatus: UartData := X"01";
end entity;

architecture main of cdi is
	signal uart_cfg_set, uart_cfg_frame, uart_tx_start, uart_tx_ready, uart_tx_break: std_logic;
	signal uart_rx_valid, uart_rx_ack, uart_rx_err, uart_rx_break: std_logic;
	signal uart_cfg, uart_txd, uart_rxd: std_logic_vector(7 downto 0);
begin
	serial: pkg_uart.uart port map (
		Clk=>Clk, Rst=>Rst,
		TX=>UartTxD, RX=>UartRxD,
		CfgSet=>uart_cfg_set, CfgFrame=>uart_cfg_frame,
		Cfg=>uart_cfg,
		TxD=>uart_txd, TxStart=>uart_tx_start, TxReady=>uart_tx_ready, TxBreak=>uart_tx_break,
		RxD=>uart_rxd, RxValid=>uart_rx_valid, RxAck=>uart_rx_ack, RxErr=>uart_rx_err, RxBreak=>uart_rx_break
	);
	
	cdi_fsm: block is
		type state_t is (
			Init, -- Initial state
			WaitNotRun, -- Wait for CPU not running
			Ready, -- Serial interface configured and listening for a command from the debugger
			SendUnknownReq, -- Send RespUnknownReq
			SendStatus, -- Send RespStatus
			SendStatus1,
			SendStatus2,
			SendStatus3,
			DoStep -- Execute a single instruction
		);
		signal state: state_t := Init;
	begin
		run: process (Rst, Clk) is
			procedure init_signals is
			begin
				CpuRun <= '0';
				CpuRegIdx <= (others=>'0');
				CpuRegDataWr <= (others=>'0');
				CpuRegRd <= '0';
				CpuRegWr <= '0';
				CpuRegCsr <= '0';
				AddrBus <= (others=>'0');
				DataBusWr <= (others=>'0');
				Rd <= '0';
				Wr <= '0';
				uart_cfg_set <= '0';
				uart_cfg_frame <= '0';
				uart_cfg <= (others=>'0');
				uart_txd <= (others=>'0');
				uart_tx_start <= '0';
				uart_tx_break <= '0';
				uart_rx_ack <= '0';
			end procedure;
			procedure send_byte(byte: UartData; new_state: state_t := WaitNotRun) is
			begin
				if uart_tx_ready = '1' then
					uart_txd <= byte;
					uart_tx_start <= '1';
					state <= new_state;
				end if;
			end procedure;
		begin
			if Rst = '1' then
				init_signals;
				state <= Init;
			elsif rising_edge(Clk) then
				init_signals;
				case state is
					when Init =>
						-- Set serial port speed
						uart_cfg_set <= '1';
						uart_cfg <= pkg_uart.uart_baud_115200;
						state <= WaitNotRun;
					when WaitNotRun =>
						if CpuBusy /= '1' then
							state <= Ready;
						end if;
					when Ready =>
						if uart_rx_valid = '1' then
							uart_rx_ack <= '1';
							case uart_rxd is
								when ReqStatus =>
									state <= SendStatus;
								when ReqStep =>
									-- Allow 1 cycle for CPU to signal Busy='1'
									CpuRun <= '1';
									state <= DoStep;
								when others =>
									state <= SendUnknownReq;
							end case;
						end if;
					when SendUnknownReq =>
						send_byte(RespUnknownReq, WaitNotRun);
					when SendStatus =>
						send_byte(RespStatus, SendStatus1);
					when SendStatus1 =>
						CpuRegIdx <= to_reg_idx(reg_idx_pc);
						CpuRegRd <= '1';
						send_byte("0000000" & CpuHalted, SendStatus2);
					when SendStatus2 =>
						CpuRegIdx <= to_reg_idx(reg_idx_pc);
						CpuRegRd <= '1';
						send_byte(std_logic_vector(CpuRegDataRd(7 downto 0)), SendStatus3);
					when SendStatus3 =>
						send_byte(std_logic_vector(CpuRegDataRd(15 downto 8)));
					when DoStep =>
						state <= WaitNotRun;
				end case;
			end if;
		end process;
	end block;
end architecture;