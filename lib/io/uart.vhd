-- Serial port controller (UART, RS-232)

library ieee;
use ieee.std_logic_1164.all;

package pkg_uart is
	-- Supported baud speeds, a subset of commonly supported speeds 
	subtype uart_baud_t is std_logic_vector(7 downto 0);
	constant uart_baud_1200:    uart_baud_t := "00000000";
	constant uart_baud_2400:    uart_baud_t := "00000001";
	constant uart_baud_4800:    uart_baud_t := "00000010";
	constant uart_baud_9600:    uart_baud_t := "00000011";
	constant uart_baud_19200:   uart_baud_t := "00000100";
	constant uart_baud_38400:   uart_baud_t := "00000101";
	constant uart_baud_57600:   uart_baud_t := "00000110";
	constant uart_baud_115200:  uart_baud_t := "00000111";
	constant uart_baud_default: uart_baud_t := uart_baud_9600;
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
	subtype uart_stop_t is std_logic_vector(0 downto 0);
	constant uart_stop_1: uart_stop_t := "0";
	constant uart_stop_2: uart_stop_t := "1";
	-- framing configuration byte
	subtype uart_frame_t is std_logic_vector(
		uart_padding_t'length + uart_bits_t'length + uart_parity_t'length + uart_stop_t'length - 1 downto 0
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
			Cfg: in std_logic_vector(7 downto 0) := (others=>'0');
			-- data byte to tramsmit (read when TXStart = 1)
			TxD: in std_logic_vector(7 downto 0) := (others=>'0');
			-- start transmitting TxD (ignored until TxReady = 1)
			-- must be set to '0' before TxReady = '1', otherwise the same byte would be transmitted again
			TxStart: in std_logic := '0';
			-- ready to start transmitting ('1' at the beginning or after a byte is fully transmitted)
			TxReady: out std_logic;
			-- set TX to the break condition (level '0') for the duration of TxBreak = '1'
			-- break condition is set immediately, even when a character is being transmitted
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
			RxBreak: out std_logic
		);
	end component;
end package;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library lib_util;
use lib_util.pkg_clock.all;
use lib_util.pkg_shift_register;
library lib_io;
use lib_io.pkg_crystal.crystal_hz;
use lib_io.pkg_uart.all;

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
			RxErr, RxBreak: out std_logic
	);
begin
	-- Check that UART configuration (speed+framing) is 2 bytes
	assert uart_baud_t'length = 8 severity failure;
	assert uart_frame_t'length = 8 severity failure;
end entity;

architecture main of uart is
	-- The maximum supported baud rate is 115200. Each bit takes 434=2*7*31 of 50MHz clock ticks.
	-- We use oversampling frequency 115200*31=3571200Hz, that is, sampling the line every 14 clock ticks.
	-- There is a low-pass filter which detects an edge only if the level is stable for several last cycles
	constant sampling_period: positive := 14;
	constant filter_sz: positive := 4;
	signal sampler: std_logic; -- RX filtering clock, and its output sync
	signal RXF: std_logic := '1'; -- sampled and filtered RX
	-- configuration
	type config_t is record
		baud: uart_baud_t;
		bits: natural range 5 to 9;
		parity: uart_parity_t;
		stop: uart_stop_t;
	end record;
	pure function config_reset return config_t is
	begin
		return (baud=>uart_baud_9600, bits=>8, parity=>uart_parity_n, stop=>uart_stop_1);
	end function;
	signal config: config_t := config_reset; -- current configuration
	signal reconfigured: boolean := false; -- notify transmitter and receiver
	-- periods for baud speeds, in sampler ticks
	type baud_period_t is array(natural range <>) of positive;
	constant baud_period_data: baud_period_t := (
		to_integer(unsigned(uart_baud_1200))   => crystal_hz/sampling_period/1200,
		to_integer(unsigned(uart_baud_2400))   => crystal_hz/sampling_period/2400,
		to_integer(unsigned(uart_baud_4800))   => crystal_hz/sampling_period/4800,
		to_integer(unsigned(uart_baud_9600))   => crystal_hz/sampling_period/9600,
		to_integer(unsigned(uart_baud_19200))  => crystal_hz/sampling_period/19200,
		to_integer(unsigned(uart_baud_38400))  => crystal_hz/sampling_period/38400,
		to_integer(unsigned(uart_baud_57600))  => crystal_hz/sampling_period/57600,
		to_integer(unsigned(uart_baud_115200)) => crystal_hz/sampling_period/115200
	);
	impure function baud_period return positive is
	begin
		return baud_period_data(to_integer(unsigned(config.baud(2 downto 0))));
	end function;
	-- data and control signals
	signal tx_w: std_logic; -- write data to transmitter
	signal tx_shift: std_logic; -- transmit one bit
	signal tx_bit: std_logic; -- a single bit to be transmitted
	signal tx_0: std_logic; -- transmit bit '0' (used for break, start, and parity bit)
	signal tx_1: std_logic; -- transmit bit '1' (used for idle, parity, and stop bit)
begin
	-- receiver sampling clock and low pass filter (generates RXF)
	-- note that serial line idle state is '1'
	sampler_clock: clock_divider
		generic map (factor=>sampling_period)
		port map (Clk=>Clk, Rst=>Rst, O=>sampler);
	rx_filter: process (Clk, Rst) is
		variable state: std_logic_vector(filter_sz - 1 downto 0) := (others=>'1');
		constant state0: std_logic_vector(state'range) := (others=>'0');
		constant state1: std_logic_vector(state'range) := (others=>'1');
	begin
		if Rst = '1' then
			state := (others=>'1');
			RXF <= '1';
		elsif rising_edge(Clk) and sampler = '1' then
			state := state(state'high - 1 downto 0) & RX;
			if state = state0 or state = state1 then
				RXF <= state(0);
			end if;
		end if;
	end process;

	-- configuration
	set_cfg: process (Clk, Rst) is
	begin
		if Rst = '1' then
			config <= config_reset;
		elsif rising_edge(Clk) then
			reconfigured <= false;
			if CfgSet then
				if CfgFrame = '0' then
					config.baud <= Cfg;
				else
					config.bits <= 5 + to_integer(unsigned(Cfg(6 downto 4)));
					config.parity <= Cfg(3 downto 1);
					config.stop <= Cfg(0 downto 0);
				end if;
				reconfigured <= true;
			end if;
		end if;
	end process;

	-- transmitter
	tx_register: pkg_shift_register.shift_register_1dir
		generic map (bits=>9, shift_dir=>pkg_shift_register.right)
		port map (Clk=>Clk, Rst=>Rst, W=>tx_w, ShiftR=>tx_shift, PIn=>'0'&TxD, SOut=>tx_bit);

	tx_w <= TxReady and TxStart;
	TX <=
		'0' when tx_0 = '1' else
		'1' when tx_1 = '1' else
		tx_bit;

	tx_fsm: block is
		type state_t is (Idle, Start, Bits, Parity, Stop, Break);
		signal state: state_t := Idle;
	begin
		step: process (Clk, Rst) is
			subtype bit_cnt_t is natural range 0 to 1+9+1+2; -- maximum number of start+data+parity+stop
			variable bit_cnt: bit_cnt_t;
			variable timer: natural range 0 to baud_period_data(to_integer(unsigned(uart_baud_1200))); -- maximum period
		begin
			if Rst = '1' then
				state <= Idle;
			elsif rising_edge(Clk) then
				tx_0 <= '0';
				tx_1 <= '0';
				tx_shift <= '0';
				TxReady <= '0';
				if reconfigured then
					state <= Idle;
				elsif TxBreak = '1' then
					state <= Break;
					bit_cnt := 0;
					timer := 0;
					tx_0 <= '1';
				else
					case state is
						when Idle =>
							tx_1 <= '1';
							if TxStart = '1' then
								TxReady <= '0';
								timer := 0;
								state <= Start;
							else
								TxReady <= '1';
							end if;
						when Start =>
							tx_0 <= '1';
							if sampler = '1' then
								if timer < baud_period then
									timer := timer + 1;
								else
									bit_cnt := 0;
									timer := 0;
									state <= Bits;
								end if;
							end if;
						when Bits =>
							if sampler = '1' then
								if timer < baud_period then
									timer := timer + 1;
								else
									bit_cnt := bit_cnt + 1;
									timer := 0;
									if bit_cnt = config.bits then
										state <= Stop; -- parity bit not implemented
									else
										tx_shift <= '1';
									end if;
								end if;
							end if;
						when Parity =>
							null; -- parity bit not implemented
						when Stop =>
							tx_1 <= '1';
							if sampler = '1' then
								if timer < baud_period then
									timer := timer + 1;
								else
									state <= Idle;
								end if;
							end if;
						when Break =>
							-- TxBreak = '0', keep break for at least 1 character
							tx_0 <= '0';
							if sampler = '1' then
								if timer < baud_period then
									timer := timer + 1;
								elsif bit_cnt < bit_cnt_t'high then
									bit_cnt := bit_cnt + 1;
									timer := 0;
								else
									state <= Idle;
								end if;
							end if;
					end case;
				end if;
			end if;
		end process;
	end block;
	
	-- receiver
	rx_fsm: block is
		type state_t is (Idle, Start, Bits, Parity, Stop, Break);
		signal state: state_t := Idle;
	begin
		step: process (Clk, Rst) is
		begin
			if Rst = '1' then
				state <= Idle;
			elsif rising_edge(Clk) then
				if reconfigured then
					state <= Idle;
				else
					case state is
						when Idle =>
							null;
						when Start =>
							null;
						when Bits =>
							null;
						when Parity =>
							null;
						when Stop =>
							null;
						when Break =>
							null;
					end case;
				end if;
			end if;
		end process;
	end block;
end architecture;