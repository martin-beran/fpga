-- Shift registers

library ieee;
use ieee.std_logic_1164.all;

package pkg_shift_register is
	-- shift direction
	type direction is (
		left, -- MSB to LSB
		right -- LSB to MSB
	);
	-- Shift register with inout parallel and serial ports
	component shift_register_io is
		generic (
			-- number of bits in the register
			bits: positive;
			-- shift direction of serial reading/writing
			shift_dir: direction
		);
		port (
			-- the master system clock
			Clk: in std_logic;
			-- reset the register content
			Rst: in std_logic;
			-- read from the register to Data
			R: in std_logic;
			-- write Data to the register
			W: in std_logic;
			-- shift the register and return one bit in Serial
			ShiftR: in std_logic;
			-- shift the register and write Serial to it
			ShiftW: in std_logic;
			-- parallel access to data (all bits)
			Data: inout std_logic_vector(bits - 1 downto 0);
			-- serial access to data (one bit)
			Serial: inout std_logic
		);
	end component;
end package;

library ieee;
use ieee.std_logic_1164.all;
library lib_util;
use lib_util.pkg_shift_register.all;

entity shift_register_io is
	generic (
		bits: positive := 8;
		shift_dir: direction := left
	);
	port (
		Clk, Rst, R, W, ShiftR, ShiftW: in std_logic;
		Data: inout std_logic_vector(bits - 1 downto 0);
		Serial: inout std_logic
	);
end entity;

architecture main of shift_register_io is
begin
	process (Clk, Rst, R, W, ShiftR, ShiftW) is
		variable memory: std_logic_vector(bits - 1 downto 0) := (others=>'0');
	begin
		if rising_edge(Clk) then
			Data <= (others=>'Z');
			Serial <= 'Z';
			if Rst = '1' then
				memory := (others=>'0');
			else
				if W = '1' then
					memory := Data;
				elsif ShiftW = '1' then
					case shift_dir is
						when left => memory := memory(bits - 2 downto 0) & Serial;
						when right => memory := Serial & memory(bits - 1 downto 1);
						when others => null; -- should not occur
					end case;
				end if;
				if R = '1' then
					Data <= memory;
				end if;
				if ShiftR = '1' then
					case shift_dir is
						when left =>
							Serial <= memory(bits - 1);
							memory := memory(bits - 2 downto 0) & '0';
						when right =>
							Serial <= memory(0);
							memory := '0' & memory(bits - 1 downto 1);
						when others => null; -- should not occur
					end case;
				end if;
			end if;
		end if;
	end process;
end architecture;