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
use lib_util.pkg_shift_register.all;
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
begin
	-- transmitter and receiver (one process, because PS/2 is half-duplex)
	tx_fsm: block
		type state_t is (Idle);
		signal state: state_t := Idle;
	begin
		step: process (Clk, Rst) is
		begin
			if Rst = '1' then
			elsif rising_edge(Clk) then
				case state is
					when Idle =>
						
						null;
					when others =>
						null;
				end case;
			end if;
		end process;
	end block;
end architecture;