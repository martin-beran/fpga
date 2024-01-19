library ieee;
use ieee.std_logic_1164.all;

-- half_adder test using a process

entity tb_half_adder_process is
end entity;

architecture all_in_vals of tb_half_adder_process is
	component half_adder
		port (
			A, B: in std_logic;
			Q, Cout: out std_logic
		);
	end component;
	
	signal tA, tB, tQ, tCout: std_logic;
	
	procedure print is
	begin
		report
			std_logic'image(tA) & " + " &
			std_logic'image(tB) & " = " &
			std_logic'image(tQ) &
			std_logic'image(tCout);
	end procedure;
begin
	testing: process
	begin
		tA <= '0'; tB <= '0'; wait for 10 ns;
		print;
		assert tQ = '0' and tCout = '0' severity failure;
		tA <= '0'; tB <= '1'; wait for 10 ns;
		print;
		assert tQ = '1' and tCout = '0' severity failure;
		tA <= '1'; tB <= '0'; wait for 10 ns;
		print;
		assert tQ = '1' and tCout = '0' severity failure;
		tA <= '1'; tB <= '1'; wait for 10 ns;
		print;
		assert tQ = '0' and tCout = '1' severity failure;
		report "Test PASS";
		wait;		
	end process;
	uut: half_adder port map (A=>tA, B=>tB, Q=>tQ, Cout=>tCout);
end architecture;