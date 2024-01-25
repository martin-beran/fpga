library ieee;
use ieee.std_logic_1164.all;
use work.common.all;

-- counter displaying a hexadecimal value on 7-segment LED

entity hex_counter_7seg is
	port (
		clk: in std_logic;
		D7: out digit7_t;
		dp:out std_logic;
		DIG1, DIG2, DIG3, DIG4: out std_logic
	);
end entity;

architecture main of hex_counter_7seg is
	signal N: val_t;
begin
	DIG1 <= '0';
	DIG2 <= not N(1);
	DIG3 <= not N(2);
	DIG4 <= not N(3);
	dp <= N(0);
	counter: entity work.counter16 port map (clk=>clk, N=>N);
	decoder: entity work.decoder_7seg port map (N=>N, D7=>D7);
end architecture;