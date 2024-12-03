-- Sequential circuits (flip-flops)

-- R-S
library ieee;
use ieee.std_logic_1164.all;

entity seq_r_s is
	port (
		R: in std_logic; -- reset
		S: in std_logic; -- set
		Q, notQ: out std_logic
	);
end entity;

architecture main of seq_r_s is
	signal o1, o2: std_logic;
begin
	o1 <= R nor o2;
	o2 <= o1 nor S;
	Q <= o1;
	notQ <= o2;
end architecture;

-- Gated D latch
library ieee;
use ieee.std_logic_1164.all;

entity seq_gated_d_latch is
	port (
		E: in std_logic; -- enable (clock)
		D: in std_logic; -- data
		Q, notQ: out std_logic
	);
end entity;

architecture main of seq_gated_d_latch is
	signal not_d, and1, and2, nor1, nor2: std_logic;
begin
	not_d <= not D;
	and1 <= not_d and E;
	and2 <= D and E;
	nor1 <= and1 nor nor2;
	nor2 <= nor1 nor and2;
	Q <= nor1;
	notQ <= nor2;
end architecture;