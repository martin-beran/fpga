library ieee;
use ieee.std_logic_1164.all;

-- one bit full adder

entity full_adder is
	port (
		A, B, Cin: in std_logic;
		Q, Cout: out std_logic
	);
end entity;

architecture main of full_adder is
begin
	Q <= A xor B when Cin = '0' else
		not (A xor B);
	Cout <= A and B when Cin = '0' else
		A or B;
end architecture;