-- PS/2 keyboard port controller

library ieee;
use ieee.std_logic_1164.all;

package pkg_ps2 is
	component ps2 is
		port (
			-- the master system clock
			Clk: in std_logic;
			-- reset
			Rst: in std_logic;
			-- PS/2 clock
			Ps2Clk: inout std_logic;
			-- PS/2 data
			Ps2Data: inout std_logic;
			-- data byte to tramsmit (read when TXStart = 1); must be valid at least 1 clock cycle after TxStart = 1
			TxD: in std_logic_vector(7 downto 0) := (others=>'0');
			-- start transmitting TxD (ignored until TxReady = 1)
			-- must be set to '0' before TxReady = '1', otherwise the same byte would be transmitted again
			TxStart: in std_logic := '0';
			-- ready to start transmitting ('1' at the beginning or after a byte is fully transmitted)
			TxReady: out std_logic;
			-- received data byte
			RxD: out std_logic_vector(7 downto 0);
			-- a valid byte has been received
			RxValid: out std_logic;
			-- the received byte has been read, a next byte can be put to RxD
			RxAck: in std_logic := '0'
		);
	end component;
end package;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library lib_util;
use lib_util.pkg_clock.all;
use lib_util.pkg_shift_register;
use lib_util.pkg_synchronizer.all;
library lib_io;
use lib_io.pkg_crystal.crystal_hz;
use lib_io.pkg_ps2.all;

entity ps2 is
	port (
		Clk, Rst: in std_logic;
		Ps2Clk, Ps2Data: inout std_logic := 'Z';
		TxD: in std_logic_vector(7 downto 0) := (others=>'0');
		TxStart: in std_logic := '0';
		TxReady: out std_logic := '1';
		RxD: out std_logic_vector(7 downto 0);
		RxValid: out std_logic := '0';
		RxAck: in std_logic := '0'
	);
end entity;

architecture main of ps2 is
	constant timeout: positive := crystal_hz / 1_000_000 * 55; -- clock inactive timeout
	constant tx_timeout: positive := crystal_hz / 1_000 * 15; -- clock start for transmitting timeout
	constant tx_init_time: positive := crystal_hz / 1_000_000 * 110; -- wait 110 us (minimum is 100 us)
	signal ps2clk_sync, ps2data_sync, ps2data_out: std_logic;
	signal rx_shift, tx_shift, tx_write: std_logic := '0'; -- shift one received bit
begin
	-- synchronizing with keyboard clock
	clk_sync: synchronizer port map (Clk=>Clk, I(0)=>Ps2Clk, O(0)=>ps2clk_sync);
	data_sync: synchronizer port map (Clk=>Clk, I(0)=>Ps2Data, O(0)=>ps2data_sync);

	-- transmitter and receiver (one process, because PS/2 is half-duplex)
	reg: pkg_shift_register.shift_register_1dir
		generic map (bits=>8, shift_dir=>pkg_shift_register.right)
		port map(
			Clk=>Clk, Rst=>Rst,
			W=>tx_write, ShiftR=>tx_shift, ShiftW=>rx_shift,
			PIn=>TxD, SIn=>ps2data_sync, POut=>RxD, SOut=>ps2data_out
		);

	comm_fsm: block
		type state_t is (
			Idle,
			RcvStart, RcvBits, RcvParity, RcvStop,
			SndStart, SndBits, SndParity, SndFinish, SndAck
		);
		signal state: state_t := Idle;
		signal clk_prev: std_logic := '1';
	begin
		step: process (Clk, Rst) is
			variable parity: std_logic;
			variable bits: natural;
			variable t: natural;
		begin
			if Rst = '1' then
				state <= Idle;
				clk_prev <= '1';
				TxReady <= '1';
				RxValid <= '0';
				Ps2Clk <= 'Z';
				Ps2Data <= 'Z';
			elsif rising_edge(Clk) then
				rx_shift <= '0';
				tx_shift <= '0';
				tx_write <= '0';
				clk_prev <= ps2clk_sync;
				case state is
					when Idle =>
						Ps2Clk <= 'Z';
						Ps2Data <= 'Z';
						TxReady <= '1';
						if RxAck = '1' then
							RxValid <= '0';
						end if;
						if TxStart = '1' then
							state <= SndStart;
							TxReady <= '0';
							Ps2Clk <= '0';
							t := 0;
							tx_write <= '1';
							bits := 0;
							parity := '1';
						elsif clk_prev = '1' and ps2clk_sync = '0'  and ps2data_sync = '0' then
							-- start bit received
							state <= RcvBits;
							parity := '0';
							bits := 0;
						end if;
					when RcvBits =>
						if clk_prev = '0' and ps2clk_sync = '1' then
							t := 0;
						elsif clk_prev = '1' and ps2clk_sync = '0' then
							-- bit received
							rx_shift <= '1';
							parity := parity xor ps2data_sync;
							bits := bits + 1;
							if bits = 8 then
								state <= RcvParity;
							end if;
						elsif ps2clk_sync = '1' then
							if t < timeout then
								t := t + 1;
							else
								state <= Idle;
							end if;
						end if;
					when RcvParity =>
						if clk_prev = '0' and ps2clk_sync = '1' then
							t := 0;
						elsif clk_prev = '1' and ps2clk_sync = '0' then
							-- parity bit received
							parity := parity xor ps2data_sync; -- 1=good, 0=bad parity
							state <= RcvStop;
						elsif ps2clk_sync = '1' then
							if t < timeout then
								t := t + 1;
							else
								state <= Idle;
							end if;
						end if;
					when RcvStop =>
						if clk_prev = '0' and ps2clk_sync = '1' then
							t := 0;
						elsif clk_prev = '1' and ps2clk_sync = '0' then
							-- stop bit received
							if ps2data_sync = '1' and parity = '1' then
								-- good parity and good stop bit
								RxValid <= '1';
							end if;
							state <= Idle;
						elsif ps2clk_sync = '1' then
							if t < timeout then
								t := t + 1;
							else
								state <= Idle;
							end if;
						end if;
					when SndStart =>
						if t < tx_init_time then
							t := t + 1;
						else
							Ps2Clk <= 'Z';
							Ps2Data <= '0';
							state <= SndBits;
							t := 0;
						end if;
					when SndBits =>
						if clk_prev = '0' and ps2clk_sync = '1' then
							t := 0;
						elsif clk_prev = '1' and ps2clk_sync = '0' then
							-- send next bit
							Ps2Data <= ps2data_out;
							tx_shift <= '1';
							parity := parity xor ps2data_out;
							bits := bits + 1;
							if bits = 8 then
								state <= SndParity;
							end if;
						elsif ps2clk_sync = '1' then
							if (bits = 0 and t < tx_timeout) or (bits /= 0 and t < timeout) then
								t := t + 1;
							else
								state <= Idle;
							end if;
						end if;
					when SndParity =>
						if clk_prev = '0' and ps2clk_sync = '1' then
							t := 0;
						elsif clk_prev = '1' and ps2clk_sync = '0' then
							-- send parity bit
							Ps2Data <= parity;
							state <= SndFinish;
						elsif ps2clk_sync = '1' then
							if t < timeout then
								t := t + 1;
							else
								state <= Idle;
							end if;
						end if;
					when SndFinish =>
						if clk_prev = '0' and ps2clk_sync = '1' then
							t := 0;
						elsif clk_prev = '1' and ps2clk_sync = '0' then
							state <= SndAck;
							Ps2Data <= 'Z';
						elsif ps2clk_sync = '1' then
							if t < timeout then
								t := t + 1;
							else
								state <= Idle;
							end if;
						end if;
					when SndAck =>
						if clk_prev = '0' and ps2clk_sync = '1' then
							t := 0;
						elsif clk_prev = '1' and ps2clk_sync = '0' then
							-- ignore the value of ACK bit (0=good, 1=bad)
							state <= Idle;
						elsif ps2clk_sync = '1' then
							if t < timeout then
								t := t + 1;
							else
								state <= Idle;
							end if;
						end if;
					when others =>
						null;
				end case;
			end if;
		end process;
	end block;
end architecture;
