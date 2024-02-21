-- Serial port controller (UART, RS-232)

library ieee;
use ieee.std_logic_1164.all;

package pkg_uart is
	-- Supported baud speeds, a subset of commonly supported speeds 
	subtype uart_baud_t is std_logic_vector(7 downto 0);
	constant uart_baud_1200:    baud_t := "00000000";
	constant uart_baud_2400:    baud_t := "00000001";
	constant uart_baud_4800:    baud_t := "00000010";
	constant uart_baud_9600:    baud_t := "00000011";
	constant uart_baud_19200:   baud_t := "00000100";
	constant uart_baud_38400:   baud_t := "00000101";
	constant uart_baud_57600:   baud_t := "00000110";
	constant uart_baud_115200:  baud_t := "00000111";
	constant uart_baud_default: baud_t := uart_baud_9600;
	-- Data framing: bits-parity-stop, only 8-N-1 is currently implemented
	-- A reserved bit in a data framing configuration byte
	subtype uart_padding_t is std_logic_vector(0 downto 0);
	constant uart_padding: uart_padding_t := "0";
	-- Data bits: 5, 6, 7, 8, 9
	subtype uart_bits_t is std_logic_vector(2 downto 0);
	constant uart_bits_5: uart_bits_t := "000";
	constant uart_bits_6: uart_bits_t := "001";
	constant uart_bits_7: uart_bits_t := "010";
	constant uart_bits_8: uart_bits_t := "011";
	constant uart_bits_9: uart_bits_t := "100";
	-- Parity: N (None, no parity bit), O (Odd, odd number of 1 bits), E (Even, even number of 1 bits),
	--	M (Mark, parity bit is always 1), S (Space, parity bit is always 0)
	subtype uart_parity_t is std_logic_vector(2 downto 0);
	constant uart_parity_n: uart_parity_t := "000";
	constant uart_parity_o: uart_parity_t := "001";
	constant uart_parity_e: uart_parity_t := "010";
	constant uart_parity_m: uart_parity_t := "011";
	constant uart_parity_s: uart_parity_t := "100";
	-- stop bits: 1, 2
	subtype uart_stop_t is std_logic_vector(1);
	constant uart_stop_1: uart_stop_t := "0";
	constant uart_stop_2: uart_stop_t := "1";
	-- framing configuration byte
	subtype uart_frame_t is std_logic_vector(
		uart_padding_t'length + uart_bits_t'length + uart_parity_t'length uart_stop_t'length downto 0
	);
	constant uart_frame_default: uart_frame_t := uart_padding & uart_bits_8 & uart_parity_n & uart_stop_1;
	-- receive error codes
	constant uart_err_overrun: std_logic_vector(7 downto 0) := "00000000"; -- at least one byte lost due to late RxAck
	constant uart_err_frame: std_logic_vector(7 downto 0) := "00000001"; -- stop bit(s) not received
	constant uart_err_parity: std_logic_vector(7 downto 0) := "00000010"; -- failed parity check
	-- UART controller
	-- "in" ports have defaults, so that unidirectional or not configurable UART can be easily created
	component uart is
		port (
			-- the master system clock
			Clk: in std_logic;
			-- reset (sets default speed and framing, stops ongoing communication, clears registers, sets line to idle)
			Rst: in std_logic;
			-- RS-232 transmitting line
			TX: out std_logic;
			-- RS-232 receiving line
			RX: in std_logic := '1';
			-- enable setting configuration (stops ongoing communication)
			CfgSet: in std_logic := '0';
			-- meaning of Cfg: 0 = speed, 1 = framing
			CfgFrame: in std_logic := '0';
			-- configuration byte (read when CfgSet = 1, interpretation defined by CfgFrame)
			Cfg: in std_logic_vector(7 downto 0) := (others=>0);
			-- data byte to tramsmit (read when TXStart = 1)
			TxD: in std_logic_vector(7 downto 0) := (others=>0);
			-- start transmitting TxD (ignored until TxReady = 1)
			-- must be set to '0' before TxReady = '1', otherwise the same byte would be transmitted again
			TxStart: in std_logic := '0';
			-- ready to start transmitting ('1' at the beginning or after a byte is fully transmitted)
			TxReady: out std_logic;
			-- set TX to the break condition (level '0') for the duration of TxBreak = '1'
			-- TX is kept at '0' at least one character time, so that the receiver can recognize a break even for
			-- a short pulse on TxBreak
			TxBreak: in std_logic := '0';
			-- received data byte
			RxD: out std_logic_vector(7 downto 0);
			-- a valid byte has been received
			RxValid: out std_logic;
			-- the received byte has been read, a next byte can be put to RxD
			RxAck: in std_logic := '0';
			-- an error occurred, RxD contains the error code (RxAck required before the next byte)
			RxErr: out std_logic;
			-- the break condition detected on RX
			-- kept at '1' for the duration of break
			RxBreak: out std_logic;
		);
	end component;
begin
	-- Check that UART configuration (speed+framing) is 2 bytes
	assert uart_baud_t'length = 8 severity failure;
	assert uart_frame_t'length = 8 severity failure;
end package;

library ieee;
use ieee.std_logic1164.all;
library lib_io;
use lib_io.pkg_crystal.crystal_hz;

entity uart is
	port (
			Clk, Rst: in std_logic;
			TX: out std_logic;
			RX, CfgSet, CfgFrame: in std_logic;
			Cfg, TxD: in std_logic_vector(7 downto 0);
			TxStart: in std_logic;
			TxReady: out std_logic;
			TxBreak: in std_logic;
			RxD: out std_logic_vector(7 downto 0);
			RxValid: out std_logic;
			RxAck: in std_logic;
			RxErr, RxBreak: out std_logic;
	);
end entity;

architecture main of uart is
begin
	-- transmitter FSM
	tx_fsm: block is
		type state_t is (Ready, Start, Bits, Parity, Stop);
		signal state: state_t := Ready;
	begin
		step: process (Clk, Rst) is
		begin
			if Rst = '1' then
				state <= Ready;
			elsif rising_edge(Clk) then
			end if;
		end process;
	end block;
	
	-- receiver FSM
	rx_fsm: block is
		type state_t is (Ready, Start, Bits, Parity, Stop, Break);
		signal state: state_t := Ready;
	begin
		step: process (Clk, Rst) is
		begin
			if Rst = '1' then
				state <= Ready;
			elsif rising_edge(Clk) then
			end if;
		end process;
	end block;
end architecture;