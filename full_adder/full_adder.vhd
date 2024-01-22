library ieee;
use ieee.std_logic_1164.all;

-- one bit full adder

entity full_adder is
	port (
		A, B, Cin: in std_logic;
		Q, Cout: out std_logic
	);
end entity full_adder;

architecture main of full_adder is
	component half_adder is
		port (
			A, B: in std_logic;
			Q, Cout: out std_logic
		);
	end component half_adder;
	signal Subtotal, C1, C2: std_logic;
begin
	adder1: half_adder port map (A=>A, B=>B, Q=>Subtotal, Cout=>C1);
	adder2: half_adder port map (A=>Subtotal, B=>Cin, Q=>Q, Cout=>C2);
	Cout <= C1 or C2;
end architecture main;

library ieee;
use ieee.std_logic_1164.all;

-- full adder used in the development kit (with inverted pins)

entity kit_full_adder is
	port (
		nA, nB, nCin: in std_logic;
		nQ, nCout: out std_logic
	);
end entity kit_full_adder;

architecture main of kit_full_adder is
	signal A, B, Cin, Q, Cout: std_logic;
begin
	impl: entity work.full_adder(main) port map (A, B, Cin, Q, Cout);
	iA: entity work.inverter(main) port map(nA, A);
	iB: entity work.inverter(main) port map(nB, B);
	iCin: entity work.inverter(main) port map(nCin, Cin);
	iQ: entity work.inverter(main) port map(Q, nQ);
	iCout: entity work.inverter(main) port map(Cout, nCout);
end architecture main;