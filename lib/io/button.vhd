-- Reading states of a group of buttons

library ieee;
use ieee.std_logic_1164.all;
library lib_io;
use lib_io.pkg_crystal;

package pkg_button is
	component button_group is
		generic (
			-- the number of buttons in the group
			count: positive := 4;
			-- Whether it uses inverted logical levels ('0' for pressed)
			inverted: boolean := true;
			-- The number of Clk cycles that Button must be stable (1 ms)
			debounce: positive := pkg_crystal.crystal_hz / 1000
		);
		port (
			-- the master system clock
			Clk: in std_logic;
			-- reset and start in the "not pressed" state
			Rst: in std_logic := '0';
			-- signals to be connected to physical buttons
			Button: in std_logic_vector(count - 1 downto 0);
			-- the output states of buttons ('1'=pressed)
			O: out std_logic_vector(count - 1 downto 0)
		);
	end component;
end package;

library ieee;
use ieee.std_logic_1164.all;
library lib_io;
use lib_io.pkg_button;

entity button_group is
	generic (
		count: positive;
		inverted: boolean;
		debounce: positive
	);
	port (
		Clk, Rst: in std_logic;
		Button: in std_logic_vector(count - 1 downto 0);
		O: out std_logic_vector(count - 1 downto 0)
	);
end entity;

architecture main of button_group is
	type sync_t is array (Button'range) of std_logic_vector(0 to 1);
	signal sync: sync_t := (others=>"00");
	signal edge: std_logic_vector(Button'range);
begin
	test_edge: for i in Button'range generate
	begin
		edge(i) <= sync(i)(0) xor sync(i)(1);
		process (Clk, Rst) is
			variable cnt: natural range 0 to debounce - 1 := 0;
		begin
			if Rst = '1' then
				sync(i) <= "00";
				cnt := 0;
				O(i) <= '0';
			elsif rising_edge(Clk) then
				sync(i)(0) <= Button(i);
				sync(i)(1) <= sync(i)(0);
				if edge(i) = '1' then
					cnt := 0;
				elsif cnt < debounce - 1 then
					cnt := cnt + 1;
				else
					cnt := 0;
					if inverted then
						O(i) <= not sync(i)(1);
					else
						O(i) <= sync(i)(1);
					end if;
				end if;
			end if;
		end process;
	end generate;
end architecture;