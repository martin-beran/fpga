library ieee;
use ieee.std_logic_1164.all;

entity inverter is
	port (
		A: in std_logic;
		Q: out std_logic
	);
end entity inverter;

architecture main of inverter is
begin
	Q <= not A;
end architecture main;