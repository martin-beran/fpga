-- Demo of library package lib_io.pkg_uart
-- When button 1 is pressed, it transmits ASCII characters 32-126 and CR.
-- Button 2 switches between speeds 9600 and 115200 baud.
-- When button 4 is pressed, it transmits break.
-- LEDs:
-- 1 = TX line level
-- 2 = RX line level
-- 4 = speed (off=9600, on=115200)

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
	signal rst, cfg_set, tx_start, tx_break, tx_pin, speed_led: std_logic := '0';
	signal rx_pin, tx_ready, rx_valid, rx_err: std_logic;
	signal cfg, tx_d, rx_d, tx_d_enable, rx_d_enable: std_logic_vector(7 downto 0);
	signal pressed: std_logic_vector(3 downto 0);
	constant byte0: std_logic_vector(7 downto 0) := (others=>'0');
	constant byte1: std_logic_vector(7 downto 0) := (others=>'1');
begin
	reset: reset_button generic map (initial_rst=>true) port map (Clk=>Clk, RstBtn=>RstBtn, Rst=>rst);
	TX <= tx_pin;
	rx_pin <= RX;
	tx_d_enable <= byte1 when tx_start else byte0;
	rx_d_enable <= byte1 when rx_valid else byte0;
--	serial_port: uart port map (
--		Clk=>Clk, Rst=>rst, TX=>tx_pin, RX=>rx_pin, CfgSet=>cfg_set, Cfg=>cfg,
--		TxD=>(tx_d and tx_d_enable) or (rx_d and rx_d_enable),
--		TxStart=>tx_start or rx_valid, TxReady=>tx_ready, TxBreak=>tx_break,
--		RxD=>rx_d, RxValid=>rx_valid, RxAck=>rx_valid or rx_err, RxErr=>rx_err
--	);
	serial_port: uart port map (
		Clk=>Clk, Rst=>rst, TX=>tx_pin, RX=>rx_pin, CfgSet=>cfg_set, Cfg=>cfg,
		TxD=>(tx_d and tx_d_enable) or (rx_d and rx_d_enable),
		TxStart=>tx_start or rx_valid, TxReady=>tx_ready, TxBreak=>tx_break,
		RxD=>rx_d, RxValid=>rx_valid, RxAck=>rx_valid or rx_err, RxErr=>rx_err
	);
	buttons: button_group port map (Clk=>Clk, Rst=>rst, Button=>Btn, O=>pressed);
	leds: led_group port map (Clk=>Clk, Rst=>rst, I=>(tx_pin, rx_pin, '0', speed_led), W=>(others=>'1'), LED=>LED);

	speed_fsm: process (Clk, rst) is
		type state_t is (Idle, Change);
		variable state: state_t := Idle;
		subtype sel_speed_t is natural range 0 to 1;
		variable sel_speed: sel_speed_t := 0;
		type speeds_t is array(sel_speed_t'range) of std_logic_vector(7 downto 0);
		constant speeds: speeds_t := (uart_baud_9600, uart_baud_115200);
	begin
		if rst = '1' then
			sel_speed := 0;
			cfg_set <= '0';
			speed_led <= '0';
			state := Idle;
		elsif rising_edge(Clk) then
			cfg_set <= '0';
			cfg <= (others=>'0');
			case sel_speed is
				when 1 => speed_led <= '1';
				when others => speed_led <= '0';
			end case;
			case state is
				when Idle =>
					if pressed(2) = '1' then
						if sel_speed < sel_speed_t'high then
							sel_speed := sel_speed + 1;
						else
							sel_speed := 0;
						end if;
						cfg_set <= '1';
						cfg <= speeds(sel_speed);
						state := Change;
					end if;
				when Change =>
					if pressed(2) = '0' then
						state := Idle;
					end if;
			end case;
		end if;
	end process;

	ascii_fsm: process (Clk, rst) is
		type state_t is (Idle, TxChar, TxBusy, TxEol, TxBreak);
		variable state: state_t := Idle;
		variable ascii: natural range 0 to 127;
	begin
		if rst = '1' then
			tx_start <= '0';
			tx_break <= '0';
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