-- 4 x 7 segment display showing up to 4 hex digits and decimal points

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package pkg_display_4hex is
	constant n_digits: integer := 4; -- number of display digits
	subtype digit_t is unsigned(3 downto 0);
	type digits_t is array (n_digits - 1 downto 0) of digit_t;
	subtype digit_sel_t is std_logic_vector(n_digits - 1 downto 0);
	-- display input signals
	type display_in_t is
		record
			wr: std_logic; -- store input to registers
			digit_ena: digit_sel_t; -- digits on/off
			digit_blink: digit_sel_t; -- enables blinking of digits
			dp_ena: digit_sel_t; -- decimal point on/off
			dp_blink: digit_sel_t; -- enables blinking of decimal points
			digits: digits_t; -- values of digits
		end record;
	-- control signals of 4x7 segment display (active '0')
	subtype segments7_t is std_logic_vector(6 downto 0);
	type display4x7_t is
		record
			digit_sel: digit_sel_t;
			segments: segments7_t;
			dp: std_logic;
		end record;
	function to_digit_t(constant d: integer) return digit_t;
end package;

package body pkg_display_4hex is
	function to_digit_t(constant d: integer) return digit_t is
	begin
		return to_unsigned(d, digit_t'length);
	end;
end package body;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pkg_display_4hex.all;

entity display_4hex is
	port (
		Clk: in std_logic; -- main clock
		BlinkClk: in std_logic; -- blink on/off clock
		Ctrl: in display_in_t; -- control input signals
		Display: out display4x7_t -- the output display
	);
end entity;

architecture main of display_4hex is
	type decoder_t is array(0 to 15) of segments7_t;
	constant decoder: decoder_t := (
			 "0111111", -- 0
			 "0000110", -- 1
			 "1011011", -- 2
			 "1001111", -- 3
			 "1100110", -- 4
			 "1101101", -- 5
			 "1111101", -- 6
			 "0000111", -- 7
			 "1111111", -- 8
			 "1101111", -- 9
			 "1110111", -- A
			 "1111100", -- B
			 "0111001", -- C
			 "1011110", -- D
			 "1111001", -- E
			 "1110001"  -- F
	);
	constant multiplex: integer := 50_000; -- Clk ticks between switching digits
	signal mDigitEna, mDigitBlink, mDPEna, mDPBlink: digit_sel_t := (others=>'0');
	signal mDigits: digits_t := (others=>to_digit_t(0));
begin
	store: process (Clk, Ctrl) is
	begin
		if rising_edge(Clk) and Ctrl.wr = '1' then
			mDigitEna <= Ctrl.digit_ena;
			mDigitBlink <= Ctrl.digit_blink;
			mDPEna <= Ctrl.dp_ena;
			mDPBlink <= Ctrl.dp_blink;
			mDigits <= Ctrl.digits;
		end if;
	end process;
	show: process (Clk) is
		subtype d_t is integer range 0 to n_digits - 1;
		variable tick: integer := 0;
		variable d: d_t := 0;
		variable ena:std_logic_vector(6 downto 0);
	begin
		if rising_edge(Clk) then
			tick := tick + 1;
			if tick = multiplex then
				if d = d_t'high then
					d := 0;
				else
					d := d + 1;
				end if;
				tick := 0;
			end if;
			Display.digit_sel <= (others=>'1');
			Display.digit_sel(d) <= '0';
			ena := (others=>(mDigitEna(d) and (not mDigitBlink(d) or BlinkClk)));
			Display.segments <= not(decoder(to_integer(mDigits(d))) and ena);
			Display.dp <= not(mDPEna(d) and (mDPEna(d) and (not mDPBlink(d) or BlinkClk)));
		end if;
	end process;
end architecture;