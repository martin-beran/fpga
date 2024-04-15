-- Demo of library package lib_io.pkg_ps2
-- It displays the last two received scan codes on the 7 segment display.
-- Buttons toggle keyboard LEDs:
--     button1 => NumLock
--     button2 => CapsLock
--     button3 => ScrollLock

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library lib_io;
use lib_io.pkg_button.all;
use lib_io.pkg_ps2.all;
use lib_io.pkg_reset.all;
use lib_io.pkg_seg7.all;

entity demo_ps2 is
	port (
	);
end entity;

architecture main of demo_ps2 is
begin
end architecture;