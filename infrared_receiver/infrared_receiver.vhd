-- Infrared receiver demo: the top-level entity

library ieee;
use ieee.std_logic_1164.all;

entity infrared_receiver is
	port (
		IR: in std_logic;
		DIG1, DIG2, DIG3, DIG4: out std_logic;
		SEG0, SEG1, SEG2, SEG3, SEG4, SEG5, SEG6, SEG7: out std_logic
	);
end entity;

architecture main of infrared_receiver is
begin
end architecture;