library ieee;
use ieee.std_logic_1164.all;

entity tb_adder4b is
end entity;

architecture main of tb_adder4b is
	component adder4b is
		port (
			A, B: in std_logic_vector (3 downto 0);
			Cin: in std_logic;
			Q: out std_logic_vector (3 downto 0);
			Cout: out std_logic
		);
	end component;
	signal tA, tB, tQ: std_logic_vector (3 downto 0);
	signal tCin, tCout: std_logic;
	function to_string(v: std_logic_vector) return string is
		variable b: string (1 to v'length) := (others => NUL);
		variable s: integer := 1;
	begin
		for i in v'range loop
			b(s) := std_logic'image(v(i))(2);
			s := s + 1;
		end loop;
		return b;
	end;
	procedure report_assert(
		constant eQ: std_logic_vector(3 downto 0);
		constant eCout: std_logic) is
	begin
		assert eQ = tQ and eCout = tCout report
			to_string(tA) & " + " & to_string(tB) & " + " & std_logic'image(tCin) & " = " &
			to_string(tQ) & " + " & std_logic'image(tCout)
			severity failure;
	end;
begin
	process
	begin
		tA <= "0000"; tB <= "0000"; tCin <= '0'; wait for 10 ns;
		report_assert(eQ=>"0000", eCout=>'0');
		tA <= "0000"; tB <= "0000"; tCin <= '1'; wait for 10 ns;
		report_assert(eQ=>"0001", eCout=>'0');
		tA <= "0010"; tB <= "1001"; tCin <= '0'; wait for 10 ns;
		report_assert(eQ=>"1011", eCout=>'0');
		tA <= "0110"; tB <= "0011"; tCin <= '0'; wait for 10 ns;
		report_assert(eQ=>"1001", eCout=>'0');
		tA <= "1000"; tB <= "1000"; tCin <= '0'; wait for 10 ns;
		report_assert(eQ=>"0000", eCout=>'1');
		report "Test PASS";
		wait;
	end process;
	dut: adder4b port map (A=>tA, B=>tB, Cin=>tCin, Q=>tQ, Cout=>tCout);
end architecture;