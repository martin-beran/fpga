library ieee;
use ieee.std_logic_1164.all;

-- half adder, used as a component of full_adder
entity half_adder is
	port (
		A, B: in std_logic;
		Q, Cout: out std_logic
	);
end entity half_adder;

architecture main of half_adder is
begin
	Q <= A when B = '0' else
		not A;
	with A select
		Cout <= 
			'0' when '0',
			B when others;
end architecture main;