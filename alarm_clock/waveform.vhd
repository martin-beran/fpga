-- Generating waveform with a specified frequency

library ieee;
use ieee.std_logic_1164.all;

entity waveform is
	generic (
		period: positive;
		use_i: boolean -- use or ignore signal I
	);
	port (
		Clk: in std_logic; -- main system clock
		Rst: in std_logic; -- reset to beginning
		I: in std_logic; -- input waveform
		O: out std_logic -- output
	);
end entity;

-- If use_i=false then it divides Clk frequency by 2

architecture main of waveform is
begin
	process (Clk) is
		variable n: natural := 0;
		variable state: std_logic := '0';
		variable prev: std_logic := '0';
		variable tick: boolean;
	begin
		if rising_edge(Clk) then
			if Rst = '1' then
				n := 0;
				state := '0';
			end if;
			if use_i then
				tick := I /= prev;
				prev := I;
			else
				tick := true;
			end if;
			if tick then
				n := n + 1;
				if n = period then
					n := 0;
					state := not state;
				end if;
			end if;
		end if;
		O <= state;
	end process;	
end;
	