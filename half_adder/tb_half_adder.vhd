library ieee;
use ieee.std_logic_1164.all;

-- half_adder test

entity tb_half_adder is
end entity;

architecture all_in_vals of tb_half_adder is
	component half_adder
		port (
			A, B: in std_logic;
			Q, Cout: out std_logic
		);
	end component;
	signal tA, tB, tQ, tCout: std_logic;
begin
	tA <= '0',
	      '1' after 30 ns,
			'0' after 60 ns,
			'1' after 90 ns,
			'0' after 120 ns;
	tB <= '0',
			'1' after 60 ns,
			'0' after 120 ns;
	
	uut: half_adder port map (A=>tA, B=>tB, Q=>tQ, Cout=>tCout);
end architecture;