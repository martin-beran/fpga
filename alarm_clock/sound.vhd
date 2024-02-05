-- Playing sound

library ieee;
use ieee.std_logic_1164.all;
use work.common.all;

entity sound is
	port (
		Clk: in std_logic; -- the main system clock (edge)
		Play: in std_logic; -- whether to play sound (level)
		Speaker: out std_logic -- speaker output
	);
end entity;

architecture main of sound is
begin
	Speaker <= '0';
	-- TODO
end;