-- A synchronizer for passing signals between clock domains

library ieee;
use ieee.std_logic_1164.all;

package pkg_synchronizer is
	component synchronizer is
		generic (
			-- the number of synchronized signal bits
			bits: positive := 1;
			-- stages the number of synchronizer stages (there are stages + 1 registers in the chain)
			stages: positive := 1
		);
		port (
			-- the master system clock
			Clk: in std_logic;
			-- the asynchronous input
			I: in std_logic_vector(bits - 1 downto 0);
			-- the synchronous output
			O: out std_logic_vector(bits - 1 downto 0)
		);
	end component;
end package;

library ieee, lib_util;
use ieee.std_logic_1164.all;
use lib_util.pkg_synchronizer.all;

entity synchronizer is
	generic (bits, stages: positive);
	port (Clk: in std_logic; I: in std_logic_vector(bits - 1 downto 0); O: out std_logic_vector(bits - 1 downto 0));
end entity;

architecture main of synchronizer is
	type sync_t is array(stages downto 0) of std_logic_vector(bits - 1 downto 0);
	signal sync: sync_t;
begin
	sync_stage: for s in stages downto 1 generate
	begin
		step: process (Clk) is
		begin
			if rising_edge(Clk) then
				sync(s) <= sync(s - 1);
			end if;
		end process;
	end generate;
	sync(0) <= I;
	O <= sync(stages);
end architecture;