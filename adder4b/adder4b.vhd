library ieee;
use ieee.std_logic_1164.all;

-- 4bit full adder

entity adder4b is
	port (
		A, B: in std_logic_vector (3 downto 0);
		Cin: in std_logic;
		Q: out std_logic_vector (3 downto 0);
		Cout: out std_logic
	);
end entity;

architecture main of adder4b is
	component full_adder is
		port (
			A, B, Cin: in std_logic;
			Q, Cout: out std_logic
		);
	end component;
	signal C0, C1, C2, C3: std_logic;
begin
	a0: full_adder port map (A(0), B(0), Cin, Q(0), C0);
	a1: full_adder port map (A(1), B(1), C0, Q(1), C1);
	a2: full_adder port map (A(2), B(2), C1, Q(2), C2);
	a3: full_adder port map (A(3), B(3), C2, Q(3), C3);
	Cout <= C3;
end architecture;