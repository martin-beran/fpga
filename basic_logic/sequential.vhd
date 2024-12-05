-- Sequential circuits (flip-flops)

library ieee;
use ieee.std_logic_1164.all;

-- A dummy register used to add delay to some forward links.
-- Using dummy registers prevents the optimizer to join several logical gates into a single LUT
-- and/or perform other modifications, which would cause a circuit to behave incorrectly.
-- Where used, architecture "main" is a standard or "textbook" implementation of a circuit,
-- while "registered" is an implementation with added dummy registers in order to fix
-- the behavior on an FPGA. Note that registers are added to forward links between gates (where
-- they only add delay), not to feedback links (where they would alter feedback behavior).
entity dummy_reg is
	port (
		Clk: in std_logic;
		I: in std_logic;
		O: out std_logic
	);
end entity;

architecture main of dummy_reg is
	signal v: std_logic;
begin
	O <= v;
	process (Clk) is
	begin
		if rising_edge(Clk) then
			v <= I;
		end if;
	end process;
end architecture;

-- R-S latch
library ieee;
use ieee.std_logic_1164.all;

entity seq_r_s_latch is
	port (
		R: in std_logic; -- reset
		S: in std_logic; -- set
		Q, notQ: out std_logic
	);
end entity;

architecture main of seq_r_s_latch is
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

-- Positive-edge-triggered D flip-flop with asynchronous set and reset
library ieee;
use ieee.std_logic_1164.all;

entity seq_d_sr is
	port (
		C: in std_logic; -- clock
		D: in std_logic; -- data
		notS: in std_logic; -- async set (inverted)
		notR: in std_logic; -- async reset (inverted)
		Q, notQ: out std_logic
	);
end entity;

architecture main of seq_d_sr is
	signal nand11, nand12, nand13, nand14, nand21, nand22: std_logic;
begin
	nand11 <= not(notS and nand14 and nand12);
	nand12 <= not(nand11 and C and notR);
	nand13 <= not(nand12 and C and nand14);
	nand14 <= not(nand13 and D and notR);
	nand21 <= not(notS and nand12 and nand22);
	nand22 <= not(nand21 and nand13 and notR);
	Q <= nand21;
	notQ <= nand22;
end architecture;

-- T flip-flop
library ieee;
use ieee.std_logic_1164.all;

entity seq_t is
	port (
		C: in std_logic; -- clock
		T: in std_logic; -- toggle enable
		Q, notQ: out std_logic;
		DummyClk: in std_logic := '0'
	);
end entity;

architecture main of seq_t is
	signal and1, and2, nor1, nor2: std_logic;
begin
	and1 <= nor1 and T and C;
	and2 <= C and T and nor2;
	nor1 <= and1 nor nor2;
	nor2 <= and2 nor nor1;
	Q <= nor1;
	notQ <= nor2;
end architecture;

architecture registered of seq_t is
	signal and1a, and1b, and2a, and2b, nor1, nor2: std_logic;
begin
	and1a <= nor1 and T and C;
	and2a <= C and T and nor2;
	dummy1: entity work.dummy_reg port map (Clk=>DummyClk, I=>and1a, O=>and1b);
	dummy2: entity work.dummy_reg port map (Clk=>DummyClk, I=>and2a, O=>and2b);
	nor1 <= and1b nor nor2;
	nor2 <= and2b nor nor1;
	Q <= nor1;
	notQ <= nor2;
end architecture;

-- J-K flip flop
library ieee;
use ieee.std_logic_1164.all;

entity seq_jk is
	port (
		C: in std_logic; -- clock
		J: in std_logic;
		K: in std_logic;
		Q, notQ: out std_logic;
		DummyClk: in std_logic := '0'
	);
end entity;

architecture main of seq_jk is
	signal nand11, nand12, nand21, nand22: std_logic;
begin
	nand11 <= not(nand22 and J and C);
	nand12 <= not(C and K and nand21);
	nand21 <= nand11 nand nand22;
	nand22 <= nand12 nand nand21;
	Q <= nand21;
	notQ <= nand22;
end architecture;

architecture registered of seq_jk is
	signal nand11a, nand11b, nand12a, nand12b, nand21, nand22: std_logic;
begin
	nand11a <= not(nand22 and J and C);
	nand12a <= not(C and K and nand21);
	dummy1: entity work.dummy_reg port map (Clk=>DummyClk, I=>nand11a, O=>nand11b);
	dummy2: entity work.dummy_reg port map (Clk=>DummyClk, I=>nand12a, O=>nand12b);
	nand21 <= nand11b nand nand22;
	nand22 <= nand12b nand nand21;
	Q <= nand21;
	notQ <= nand22;
end architecture;