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
	signal tx_data, rx_data: std_logic_vector(7 downto 0);
	signal tx_start, tx_ready, rx_valid, rx_ack, rx_err: std_logic;
	signal send_lock_state: boolean := false;
begin
	-- handle reset button
	reset: reset_button generic map (initial_rst=>true) port map (Clk=>Clk, RstBtn=>RstBtn, Rst=>rst);
	
	-- handle buttons
	buttons: button_group port map (Clk=>Clk, Rst=>rst, Button=>Btn, O(2 downto 0)=>btn_state);
	
	-- serial port, will be replaced by PS/2 later
	serial_port: uart port map (
		Clk=>Clk, Rst=>rst, TX=>TX, RX=>RX,
		TxD=>tx_data, TxStart=>tx_start, TxReady=>tx_ready,
		RxD=>rx_data, RxValid=>rx_valid, RxAck=>rx_ack, RxErr=>rx_err
	);
	
	kbd_send_fsm: block
		type state_t is (Init, Start, Send1, Send2);
		signal state: state_t := Init;
	begin
		process (Clk, rst) is
			constant byte0: std_logic_vector(7 downto 0) := X"ed";
			variable byte1: std_logic_vector(7 downto 0) := X"00";
			variable restart: boolean := false;
		begin
			if rst = '1' then
				tx_data <= (others=>'0');
				tx_start <= '0';
			elsif rising_edge(Clk) then
				if send_lock_state then
					byte1 := "00000" & lock_state(1) & lock_state(0) & lock_state(2);
				end if;
				case state is
					when Init =>
						if send_lock_state then
							state <= Start;
						end if;
					when Start =>
						if tx_ready = '1' then
							state <= Send1;
							tx_data <= byte0;
							tx_start <= '1';
						end if;
					when Send1 =>
						tx_start <= '0';
						if tx_ready = '1' then
							state <= Send2;
							tx_data <= byte1;
							tx_start <= '1';
						end if;
					when Send2 =>
						if tx_ready = '1' then
							if restart or send_lock_state then
								state <= Start;
								restart := false;
							else
								state <= Init;
							end if;
						elsif send_lock_state then
							restart := true;
						end if;
					when others =>
						null;
				end case;
			end if;
		end process;
	end block;
	
	kbd_recv: process (Clk, rst) is
	begin
		if rst = '1' then
			rx_ack <= '0';
		elsif rising_edge(Clk) then
		end if;
	end process;
	
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
			send_lock_state <= false;
			for i in btn_state'range loop
				if btn_state(i) = '1' and btn_old(i) = '0' then
					lock_state(i) <= not lock_state(i);
					send_lock_state <= true;
				end if;
			end loop;
		end if;
	end process;
	
end architecture;