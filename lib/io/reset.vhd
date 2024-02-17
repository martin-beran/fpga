-- Reset button

library ieee;
use ieee.std_logic_1164.all;
library lib_io;
use lib_io.pkg_crystal.all;

package pkg_reset is
	component reset_button is
		generic (
			-- the active level of the reset button
			rst_active: std_logic := '0';
			-- activate reset on power on, regardless of RstBtn state
			initial_rst: boolean := false;
			-- duration of the reset signal in the number of Clk cycles (1 ms)
			-- initial reset duration and duration after the reset button is released
			duration: positive := crystal_hz / 1000
		);
		port (
			-- the master system clock
			Clk: in std_logic;
			-- the reset button
			RstBtn: in std_logic;
			-- the output reset signal
			Rst: out std_logic
		);
	end component;
end package;

library ieee;
use ieee.std_logic_1164.all;
library lib_io;
use lib_io.pkg_reset;

entity reset_button is
	generic (
		rst_active: std_logic;
		initial_rst: boolean;
		duration: positive
	);
	port (
		Clk, RstBtn: in std_logic;
		Rst: out std_logic
	);
end entity;

architecture main of reset_button is
	function init_cnt(constant ir: boolean) return natural is
	begin
		if ir then
			return 1;
		else
			return 0;
		end if;
	end function;
begin
	process (Clk, RstBtn) is
		variable cnt: natural range 0 to duration := init_cnt(initial_rst);
	begin
		if RstBtn = rst_active then
			cnt := 1;
			Rst <= '1';
		elsif rising_edge(Clk) then
			if cnt = 0 then
				Rst <= '0';
			elsif cnt < duration then
				cnt := cnt + 1;
				Rst <= '1';
			else
				cnt := 0;
				Rst <= '0';
			end if;
		end if;
	end process;
end architecture;