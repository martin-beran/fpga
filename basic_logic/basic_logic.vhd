-- Demonstration of basic logic circuits: combinatorial (gates) and sequential (flip-flops)

library ieee, lib_util, lib_io;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use lib_io.pkg_button.all;
use lib_io.pkg_crystal.all;
use lib_io.pkg_led.all;
use lib_io.pkg_seg7.all;

entity basic_logic is
	port (
		-- the main system clock
		Clk: in std_logic;
		-- setting configuration mode, starting/stopping clock signal
		RstBtn: in std_logic;
		-- configuration and input buttons
		Button: in std_logic_vector(3 downto 0);
		-- LEDs indicating input bits
		LED: out std_logic_vector(3 downto 0);
		-- 7-segment display digit selection
		DIG: out std_logic_vector(3 downto 0);
		-- 7-segment display segment selection
		SEG: out std_logic_vector(7 downto 0)
	);
end entity;

architecture main of basic_logic is
	signal button_state: std_logic_vector(4 downto 0);
	signal inputs: std_logic_vector(3 downto 0);
	signal outputs: std_logic_vector(3 downto 0);	
begin
	-- handle physical buttons
	button_in: button_group	generic map (count=>5) port map (Clk=>Clk, Button=>Button&RstBtn, O=>button_state);
end architecture;