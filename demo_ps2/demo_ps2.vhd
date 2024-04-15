-- Demo of library package lib_io.pkg_ps2
-- It displays the last two received scan codes on the 7 segment display.
-- Buttons toggle keyboard LEDs and board LEDs:
--     button1 => NumLock, LED1
--     button2 => CapsLock, LED2
--     button3 => ScrollLock, LED3

-- TODO: This is the first version of the demo project, intended for debugging
-- the demo itself. It uses UART instead of PS/2. After the PS/2 controller
-- implementation is finished, it will replace UART.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library lib_io;
use lib_io.pkg_button.all;
use lib_io.pkg_led.all;
-- use lib_io.pkg_ps2.all;
use lib_io.pkg_reset.all;
use lib_io.pkg_seg7.all;
use lib_io.pkg_uart.all;

entity demo_ps2 is
	port (
		Clk, RstBtn: in std_logic;
		PsData, PsClock: inout std_logic;
		TX: out std_logic;
		RX: in std_logic;
		Btn: in std_logic_vector(3 downto 0);
		LED: out std_logic_vector(3 downto 0);
		DIG: out std_logic_vector(3 downto 0);
		SEG: out std_logic_vector(7 downto 0)
	);
end entity;

architecture main of demo_ps2 is
	signal rst: std_logic;
	signal lock_state, lock_old: std_logic_vector(2 downto 0); -- 0=Num, 1=Caps, 2=Scroll Lock
	signal btn_state, btn_old: std_logic_vector(2 downto 0);
begin
	-- handle reset button
	reset: reset_button generic map (initial_rst=>true) port map (Clk=>Clk, RstBtn=>RstBtn, Rst=>rst);
	-- handle buttons
	buttons: button_group port map (Clk=>Clk, Rst=>rst, Button=>Btn, O(2 downto 0)=>btn_state);
	-- handle lock indication LEDs
	led_ctl: led_group port map (Clk=>Clk, Rst=>rst, I=>'0'&lock_state, LED=>LED);
	lock_leds: process (Clk, rst) is
	begin
		if rst = '1' then
			btn_old <= (others=>'0');
			lock_state <= (others=>'0');
			lock_old <= (others=>'1');
		elsif rising_edge(Clk) then
			lock_old <= lock_state;
			if lock_state /= lock_old then
				-- TODO: send new state to the keyboard
			end if;
			btn_old <= btn_state;
			for i in btn_state'range loop
				if btn_state(i) = '1' and btn_old(i) = '0' then
					lock_state(i) <= not lock_state(i);
				end if;
			end loop;
		end if;
	end process;
end architecture;