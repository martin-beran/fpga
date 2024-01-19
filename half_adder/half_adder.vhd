library ieee;
use ieee.std_logic_1164.all;

-- half adder (use entity kit as top-level entity for hw with inverted switches and LEDs)

entity half_adder is
	port (
		A, B: in std_logic;
		Q, Cout: out std_logic
	);
end entity;

architecture main of half_adder is
begin
	Q <= A xor B;
	Cout <= A and B;
end architecture;

library ieee;
use ieee.std_logic_1164.all;

entity inverter is
	port (
		A: in std_logic;
		Q: out std_logic
	);
end entity;

architecture main of inverter is
begin
	Q <= not A;
end architecture;

library ieee;
use ieee.std_logic_1164.all;

entity kit is
	port (
		S1, S2: in std_logic;
		LED1, LED2: out std_logic
	);
end entity;

architecture main of kit is
	signal iS1, iS2, iLED1, iLED2: std_logic;
begin
	invS1: entity work.inverter port map (A=>S1, Q=>iS1);
	invS2: entity work.inverter port map (A=>S2, Q=>iS2);
	invLED1: entity work.inverter port map (A=>iLED1, Q=>LED1);
	invLED2: entity work.inverter port map (A=>iLED2, Q=>LED2);
	core: entity work.half_adder port map (A=>iS1, B=>iS2, Q=>iLED1, Cout=>iLED2);
end architecture;