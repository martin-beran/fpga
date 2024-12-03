-- Combinatorial circuits (gates)

-- Definition of A fun B => Q by elements of logic vector "XXXX":
-- A B "XXXX"
-- 0 0     Q
-- 0 1    Q
-- 1 0   Q
-- 1 1  Q

-- 0000 constant 0
library ieee;
use ieee.std_logic_1164.all;

entity comb_0000_const0 is
	port (
		A, B: in std_logic;
		Q: out std_logic
	);
end entity;

architecture main of comb_0000_const0 is
begin
	Q <= '0';
end architecture;

-- 0001 A nor B
library ieee;
use ieee.std_logic_1164.all;

entity comb_0001_nor is
	port (
		A, B: in std_logic;
		Q: out std_logic
	);
end entity;

architecture main of comb_0001_nor is
begin
	Q <= A nor B;
end architecture;

-- 0010 not(A <= B)
library ieee;
use ieee.std_logic_1164.all;

entity comb_0010_not_rev_impl is
	port (
		A, B: in std_logic;
		Q: out std_logic
	);
end entity;

architecture main of comb_0010_not_rev_impl is
begin
	Q <= not A and B;
end architecture;

-- 0011 not A
library ieee;
use ieee.std_logic_1164.all;

entity comb_0011_not_a is
	port (
		A, B: in std_logic;
		Q: out std_logic
	);
end entity;

architecture main of comb_0011_not_a is
begin
	Q <= not A;
end architecture;

-- 0100 not(A => B)
library ieee;
use ieee.std_logic_1164.all;

entity comb_0100_not_impl is
	port (
		A, B: in std_logic;
		Q: out std_logic
	);
end entity;

architecture main of comb_0100_not_impl is
begin
	Q <= A and not B;
end architecture;

-- 0101 not B
library ieee;
use ieee.std_logic_1164.all;

entity comb_0101_not_b is
	port (
		A, B: in std_logic;
		Q: out std_logic
	);
end entity;

architecture main of comb_0101_not_b is
begin
	Q <= not B;
end architecture;

-- 0110 A xor B
library ieee;
use ieee.std_logic_1164.all;

entity comb_0110_xor is
	port (
		A, B: in std_logic;
		Q: out std_logic
	);
end entity;

architecture main of comb_0110_xor is
begin
	Q <= A xor B;
end architecture;

-- 0111 A nand B
library ieee;
use ieee.std_logic_1164.all;

entity comb_0111_nand is
	port (
		A, B: in std_logic;
		Q: out std_logic
	);
end entity;

architecture main of comb_0111_nand is
begin
	Q <= A nand B;
end architecture;

-- 1000 A and B
library ieee;
use ieee.std_logic_1164.all;

entity comb_1000_and is
	port (
		A, B: in std_logic;
		Q: out std_logic
	);
end entity;

architecture main of comb_1000_and is
begin
	Q <= A and B;
end architecture;

-- 1001 A xnor B
library ieee;
use ieee.std_logic_1164.all;

entity comb_1001_xnor is
	port (
		A, B: in std_logic;
		Q: out std_logic
	);
end entity;

architecture main of comb_1001_xnor is
begin
	Q <= A xnor B;
end architecture;

-- 1010 B
library ieee;
use ieee.std_logic_1164.all;

entity comb_1010_b is
	port (
		A, B: in std_logic;
		Q: out std_logic
	);
end entity;

architecture main of comb_1010_b is
begin
	Q <= B;
end architecture;

-- 1011 A => B
library ieee;
use ieee.std_logic_1164.all;

entity comb_1011_impl is
	port (
		A, B: in std_logic;
		Q: out std_logic
	);
end entity;

architecture main of comb_1011_impl is
begin
	Q <= not A or B;
end architecture;

-- 1100 A
library ieee;
use ieee.std_logic_1164.all;

entity comb_1100_a is
	port (
		A, B: in std_logic;
		Q: out std_logic
	);
end entity;

architecture main of comb_1100_a is
begin
	Q <= A;
end architecture;

-- 1101 A <= B
library ieee;
use ieee.std_logic_1164.all;

entity comb_1101_rev_impl is
	port (
		A, B: in std_logic;
		Q: out std_logic
	);
end entity;

architecture main of comb_1101_rev_impl is
begin
	Q <= A or not B;
end architecture;

-- 1110 A or B
library ieee;
use ieee.std_logic_1164.all;

entity comb_1110_or is
	port (
		A, B: in std_logic;
		Q: out std_logic
	);
end entity;

architecture main of comb_1110_or is
begin
	Q <= A or B;
end architecture;

-- 1111 constant 1
library ieee;
use ieee.std_logic_1164.all;

entity comb_1111_const1 is
	port (
		A, B: in std_logic;
		Q: out std_logic
	);
end entity;

architecture main of comb_1111_const1 is
begin
	Q <= '1';
end architecture;