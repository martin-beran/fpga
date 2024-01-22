library ieee;
use ieee.std_logic_1164.all;

entity tb_full_adder is
end entity tb_full_adder;

architecture main of tb_full_adder is
	component full_adder is
		port (
			A, B, Cin: in std_logic;
			Q, Cout: out std_logic
		);
	end component full_adder;
	signal tA, tB, tCin: std_logic;
	signal tQ, tCout: std_logic;
	procedure report_assert(constant eQ: std_logic; constant eCout: std_logic) is
	begin
		report
			"tA(" & std_logic'image(tA) &
			")+tB(" & std_logic'image(tB) &
			")+tCin(" & std_logic'image(tCin) &
			"=tQ(" & std_logic'image(tQ) & " exp " & std_logic'image(eQ) &
			"),tCout(" & std_logic'image(tCout) & " exp " & std_logic'image(eCout) & ")";
		assert tQ = eQ and tCout = eCout severity failure;	
	end procedure report_assert;
begin
	test: process
	begin
		tA <= '0'; tB <= '0'; tCin <= '0'; wait for 10 ns;
		report_assert(eQ=>'0', eCout=>'0');

		tA <= '0'; tB <= '0'; tCin <= '1'; wait for 10 ns;
		report_assert(eQ=>'1', eCout=>'0');

		tA <= '0'; tB <= '1'; tCin <= '0'; wait for 10 ns;
		report_assert(eQ=>'1', eCout=>'0');

		tA <= '0'; tB <= '1'; tCin <= '1'; wait for 10 ns;
		report_assert(eQ=>'0', eCout=>'1');

		tA <= '1'; tB <= '0'; tCin <= '0'; wait for 10 ns;
		report_assert(eQ=>'1', eCout=>'0');

		tA <= '1'; tB <= '0'; tCin <= '1'; wait for 10 ns;
		report_assert(eQ=>'0', eCout=>'1');

		tA <= '1'; tB <= '1'; tCin <= '0'; wait for 10 ns;
		report_assert(eQ=>'0', eCout=>'1');

		tA <= '1'; tB <= '1'; tCin <= '1'; wait for 10 ns;
		report_assert(eQ=>'1', eCout=>'1');

		report "Test PASS";
		wait;
	end process;
	dut: full_adder port map (A=>tA, B=>tB, Cin=>tCin, Q=>tQ, Cout=>tCout);
end architecture main;