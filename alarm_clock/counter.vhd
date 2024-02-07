-- An incrementing/decrementing counter

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- The counter counts from 0 to max - 1, but resets also
-- when the second internal counter reaches max2, if max2 > max
-- This weird funcionality is intended for hour counter composed of
-- two instances of counter, with combined range 00-23
entity counter is
	generic (
		bits: integer; -- bit width of the counter
		max: integer; -- maximum value of the counter
		max2: integer := 0 -- a second maximum value
	);
	port (
		Clk: in std_logic; -- the main system clock
		Rst: in std_logic; -- set the value to 0 (sync)
		Inc: in std_logic; -- increment the value (sync)
		Dec: in std_logic; -- decrement the value (sync)
		InCInc: in std_logic := '0'; -- input carry of increment (async)
		InCDec: in std_logic := '0'; -- input carry of decrement (async)
		InCarry: in std_logic := '0'; -- value changes controlled by InCInc, InCDec
		Value: out unsigned(bits - 1 downto 0); -- the current value
		CInc: out std_logic; -- output carry of increment (async)
		CDec: out std_logic -- output carry of decrement (async)
	);
begin
	assert 2 ** bits > max severity failure;
end entity;

architecture main of counter is
	function maximum(constant a,b: integer) return integer is
	begin
		if a > b then
			return a;
		else
			return b;
		end if;
	end function;
	signal i_cnt, o_inc_cnt, o_dec_cnt: integer range 0 to max;
	signal i_cnt2, o_inc_cnt2, o_dec_cnt2: integer range 0 to maximum(max, max2);
begin
	o_inc_cnt <=
		i_cnt when InCarry = '1' and InCInc = '0' else
		0 when max2 > max and i_cnt2 = max2 else
		0 when i_cnt = max else
		i_cnt + 1;
	o_inc_cnt2 <=
		i_cnt2 when InCarry = '1' and InCInc = '0' else
		0 when max2 > max and i_cnt2 = max2 else
		i_cnt2 + 1 when i_cnt = max and max2 > max else
		i_cnt2 + 1 when max2 > max else
		i_cnt2;
	CInc <=
		'0' when InCarry = '1' and InCInc = '0' else
		'1' when max2 > max and i_cnt2 = max2 else
		'1' when i_cnt = max else
		'0';

	o_dec_cnt <=
		i_cnt when InCarry = '1' and InCDec = '0' else
		max2 mod (max + 1) when max2 > max and i_cnt2 = 0 else
		max when i_cnt = 0 else
		i_cnt - 1;
	o_dec_cnt2 <=
		i_cnt2 when InCarry = '1' and InCDec = '0' else
		max2 when max2 > max and i_cnt2 = 0 else
		i_cnt2 - 1 when i_cnt = 0 and max2 > max else
		i_cnt2 - 1 when max2 > max else
		i_cnt2;
	CDec <=
		'0' when InCarry = '1' and InCDec = '0' else
		'1' when max2 > max and i_cnt2 = 0 else
		'1' when i_cnt = 0 else
		'0';

	update: process (Clk) is
		variable cnt: integer range 0 to max := 0;
		variable cnt2: integer range 0 to maximum(max, max2) := 0;
	begin
		if rising_edge(Clk) then
			If Rst = '1' then
				cnt := 0;
				cnt2 := 0;
			end if;
			if Inc = '1' then
				cnt := o_inc_cnt;
				cnt2 := o_inc_cnt2;
			end if;
			if Dec = '1' then
				cnt := o_dec_cnt;
				cnt2 := o_dec_cnt2;
			end if;
			i_cnt <= cnt;
			i_cnt2 <= cnt2;
			Value <= to_unsigned(cnt, bits);
		end if;
	end process;
end architecture;