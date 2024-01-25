library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common.all;

entity decoder_7seg is
	port (
		N: in val_t;
		D7: out digit7_t
	);
end entity;

architecture main of decoder_7seg is
	type decoder_t is array(0 to 15) of digit7_t;
	constant decoder: decoder_t := (
		"1000000", -- 0
		"1111001", -- 1
		"0100100", -- 2
		"0110000", -- 3
		"0011001", -- 4
		"0010010", -- 5
		"0000010", -- 6
		"1111000", -- 7
		"0000000", -- 8
		"0010000", -- 9
		"0001000", -- A
		"0000011", -- B
		"1000110", -- C
		"0100001", -- D
		"0000110", -- E
		"0001110" -- F
	);
begin
	D7 <= decoder(to_integer(N));
end;