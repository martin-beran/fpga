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
	-- TODO
	uart_cfg_set <= '0';
	uart_cfg_frame <= '0';
	uart_cfg <= (others=>'0');
	uart_txd <= (others=>'0');
	uart_tx_start <= '0';
	uart_tx_break <= '0';
	uart_rx_ack <= '0';
	
	CpuRun <= uart_rxd(0);
	CpuRegIdx <= unsigned(uart_rxd(3 downto 0));
	CpuRegDataWr <= word_t(uart_rxd & uart_rxd);
	CpuRegRd <= uart_rxd(1) xor uart_tx_ready;
	CpuRegWr <= uart_rxd(2) xor uart_rx_valid;
	CpuRegCsr <= uart_rxd(3) xor uart_rx_err;
	AddrBus <= addr_t(uart_rxd & uart_rxd);
	DataBusWr <= byte_t(uart_rxd);
	Rd <= uart_rxd(4) xor uart_rx_break;
	Wr <= uart_rxd(5);
end architecture;