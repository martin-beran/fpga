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
			-- data byte to tramsmit (read when TXStart = 1)
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
library lib_io;
use lib_io.pkg_crystal.crystal_hz;
use lib_io.pkg_ps2.all;

entity ps2 is
	port (
		Clk, Rst: in std_logic;
		Ps2Clk, Ps2Data: inout std_logic;
		TxD: in std_logic_vector(7 downto 0) := (others=>'0');
		TxStart: in std_logic := '0';
		TxReady: out std_logic;
		RxD: out std_logic_vector(7 downto 0);
		RxValid: out std_logic;
		RxAck: in std_logic := '0'
	);
end entity;

architecture main of ps2 is
	constant inactive_timeout: positive := crystal_hz / 1_000_000 * 55; -- receive clock inactive timeout
	signal ps2clk_sync, ps2data_sync: std_logic;
	signal rx_shift: std_logic := '0'; -- shift one received bit
begin
	-- synchronizing with keyboard clock
	clk_sync: synchronizer port map (Clk=>Clk, I=>Ps2Clk, O=>ps2clk_sync);
	data_sync: synchronizer port map (Clk=>Clk, I=>Ps2Data, O=>ps2data_sync);

	-- transmitter and receiver (one process, because PS/2 is half-duplex)
	reg: pkg_shift_register.shift_register_1dir
		generic map (bits=>8, shift_dir=>pkg_shift_register.right)
		port map(Clk=>Clk, Rst=>Rst, ShiftW=>rx_shift, SIn=>ps2data_sync, POut=>RxD);

	tx_fsm: block
		type state_t is (Idle, RcvStart);
		signal state: state_t := Idle;
		signal clk_prev: std_logic := '1';
	begin
		step: process (Clk, Rst) is
			variable rx_parity: std_logic;
		begin
			if Rst = '1' then
				state <= Idle;
				clk_prev <= '1';
			elsif rising_edge(Clk) then
				case state is
					clk_prev <= ps2clk_sync;
					when Idle =>
						if clk_prev = '1' and ps2clk_sync = '0'  and ps2clk_data = '0' then
							state <= RcvBits;
							rx_parity := '1';
						end if;
					when RcvBits =>
					when others =>
						null;
				end case;
			end if;
		end process;
	end block;
end architecture;