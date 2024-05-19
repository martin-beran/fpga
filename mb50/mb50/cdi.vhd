-- MB50: CDI (Control and Debugging Interface)

library ieee;
use ieee.std_logic_1164.all;

entity cdi is
	port (
		-- CPU clock
		Clk: in std_logic;
		-- Reset
		Rst: in std_logic;
		-- Run the CPU
		RunCpu: out std_logic
	);
end entity;

architecture main of cdi is
begin
end architecture;