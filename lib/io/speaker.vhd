-- Speaker control

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
library lib_io;
use lib_io.pkg_crystal.crystal_hz;

package pkg_speaker is
	-- half of the period of a 1 Hz signal
	constant half_period_1hz: positive := crystal_hz / 2;
	-- the number of bits needed to count a half of the period (for 20 Hz)
	constant half_period_bits: positive := positive(ceil(log2(real(half_period_1hz / 20))));
	-- half periods of notes
	type note_t is (
		note_Pause,
		note_C4, note_C4sharp, note_D4, note_D4sharp, note_E4,
		note_F4, note_F4sharp, note_G4, note_G4sharp, note_A4, note_A4sharp, note_B4
	);
	type note_half_period_t is array(note_t) of natural;
	constant note_half_period: note_half_period_t := (
		0,
		half_period_1hz / 262, -- C4
		half_period_1hz / 277, -- C4#
		half_period_1hz / 294, -- D4
		half_period_1hz / 311, -- D4#
		half_period_1hz / 330, -- E4
		half_period_1hz / 349, -- F4
		half_period_1hz / 370, -- F4#
		half_period_1hz / 392, -- G4
		half_period_1hz / 415, -- G4#
		half_period_1hz / 440, -- A4
		half_period_1hz / 466, -- A4#
		half_period_1hz / 494  -- B4
	);
	-- play a sound defined by half of the period (implemented by a simple counter)
	component play_sound is
		generic (
			-- the number of bits needed to count a half of the period of 20 Hz signal
			bits: positive := half_period_bits;
			-- speaker input with inverted logic (active level '0')
			inverted: boolean := true
		);
		port (
			-- the master system clock
			Clk: in std_logic;
			-- reset and turn any sound off
			Rst: in std_logic;
			-- half of the sound period (Clk ticks), zero to mute
			I: in unsigned(bits - 1 downto 0);
			-- start/stop playing sound according to I
			W: in std_logic;
			-- signal to be connected to the speaker output pin
			Speaker: out std_logic
		);
	end component;
end package;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity play_sound is
	generic (
		bits: positive;
		inverted: boolean
	);
	port (
		Clk, Rst: in std_logic;
		I: in unsigned(bits - 1 downto 0);
		W: in std_logic;
		Speaker: out std_logic
	);
end entity;

architecture main of play_sound is
	signal state: std_logic := '0';
begin
	Speaker <= not state when inverted else state;
	process (Clk) is
		variable half_period: unsigned(bits - 1 downto 0) := to_unsigned(0, bits);
		variable cnt: unsigned(bits - 1 downto 0) := to_unsigned(0, bits);
	begin
		if rising_edge(Clk) then
			if W = '1' then
				half_period := I;
			end if;
			if Rst = '1' then
				half_period := to_unsigned(0, bits);
			end if;
			if W = '1' or Rst = '1' then
				cnt := to_unsigned(0, bits);
				state <= '0';
			end if;
			if half_period = 0 then
				state <= '0';
			elsif cnt < half_period then
				cnt := cnt + 1;
			else
				cnt := to_unsigned(0, bits);
				state <= not state;
			end if;
		end if;
	end process;
end architecture;