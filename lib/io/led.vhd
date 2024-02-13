-- Control of a group of LEDs

library ieee;
use ieee.std_logic_1164.all;

package pkg_led is
	component led_group is
		generic (
			-- The number of LEDs in the group
			count: positive := 4;
			-- Whether it uses inverted logical levels ('0' for on)
			inverted: boolean := true
		);
		port (
			-- the master system clock
			Clk: in std_logic;
			-- Reset and turn all LEDs off
			Rst: in std_logic := '0';
			-- Values of LEDs ('1'=on, '0'=off)
			I: in std_logic_vector(count - 1 downto 0);
			-- Select which values from I will be applied
			Sel: in std_logic_vector(count - 1 downto 0) := (others=>'1');
			-- Signals to be connected to LED control pins
			LED: out std_logic_vector(count - 1 downto 0)
		);
	end component;
end package;

library ieee;
use ieee.std_logic_1164.all;
library lib_io;
use lib_io.pkg_led.all;

entity led_group is
	generic (
		count: positive;
		inverted: boolean
	);
	port (
		Clk, Rst: in std_logic;
		I, Sel: in std_logic_vector(count - 1 downto 0);
		LED: out std_logic_vector(count - 1 downto 0)
	);
end entity;

architecture main of led_group is
	signal state: std_logic_vector(count - 1 downto 0) := (others=>'0');
begin
	LED <= not state when inverted else state;
	process (Clk) is
	begin
		if rising_edge(Clk) then
			if Rst = '1' then
				state <= (others=>'0');
			else
				state <= (state and not Sel) or (Sel and I);
			end if;
		end if;
	end process;
end architecture;