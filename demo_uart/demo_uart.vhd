-- Demo of library package lib_io.pkg_uart
-- When button 1 is pressed, it transmits ASCII characters 32-126 and CR.
-- When button 4 is pressed, it transmits break

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library lib_io;
use lib_io.pkg_button.all;
use lib_io.pkg_led.all;
use lib_io.pkg_reset.all;
use lib_io.pkg_uart.all;

entity demo_uart is
	port (
		Clk, RstBtn: in std_logic;
		TX: out std_logic;
		RX: in std_logic;
		Btn: in std_logic_vector(3 downto 0);
		LED: out std_logic_vector(3 downto 0)
	);
end entity;

architecture main of demo_uart is
	signal rst, tx_start, tx_break, tx_pin, rx_pin, tx_eol: std_logic := '0';
	signal tx_ready: std_logic;
	signal tx_d: std_logic_vector(7 downto 0);
	signal pressed: std_logic_vector(3 downto 0);
begin
	reset: reset_button generic map (initial_rst=>true) port map (Clk=>Clk, RstBtn=>RstBtn, Rst=>rst);
	TX <= tx_pin;
	rx_pin <= RX;
	serial_port: uart port map (
		Clk=>Clk, Rst=>rst, TX=>tx_pin, RX=>rx_pin,
		TxD=>tx_d, TxStart=>tx_start, TxReady=>tx_ready, TxBreak=>tx_break
	);
	buttons: button_group port map (Clk=>Clk, Rst=>rst, Button=>Btn, O=>pressed);
	leds: led_group port map (Clk=>Clk, Rst=>rst, I=>(tx_pin, rx_pin, tx_eol, others=>'0'), W=>(others=>'1'), LED=>LED);
	ascii_fsm: process (Clk, rst) is
		type state_t is (Idle, TxChar, TxBusy, TxEol, TxBreak);
		variable state: state_t := Idle;
		variable ascii: natural range 0 to 127;
	begin
		if rst = '1' then
			tx_start <= '0';
			tx_break <= '0';
			tx_eol <= '0';
			state := Idle;
		elsif rising_edge(Clk) then
			if pressed(0) then
				state := TxBreak;
			end if;
			tx_start <= '0';
			tx_break <= '0';
			case state is
				when Idle =>
					if pressed(3) = '1' then
						ascii := 32;
						state := TxChar;
					end if;
				when TxChar =>
					if tx_ready = '1' then
						tx_start <= '1';
						if ascii <= 126 then
							tx_d <= std_logic_vector(to_unsigned(ascii, 8));
							ascii := ascii + 1;
							state := TxBusy; -- do not increment ascii in the next tick, when tx_ready is still '1'
						else
							tx_d <= std_logic_vector(to_unsigned(13, 8)); -- CR
							state := TxEol;
						end if;
					end if;
				when TxBusy =>
					state := TxChar; -- tx_ready will be '0' in the next tick, wait for transmission end
				when TxEol =>
					if tx_ready = '1' then
						tx_eol <= not tx_eol;
					end if;
					if tx_ready = '1' and pressed(3) = '0' then
						state := Idle;
					end if;
				when TxBreak =>
					tx_break <= '1';
					if pressed(3) = '0' then
						state := Idle;
					end if;
			end case;
		end if;
	end process;
end architecture;