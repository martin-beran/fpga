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
			R: in std_logic := '0';
			-- write Data to the register
			W: in std_logic := '0';
			-- shift the register and return one bit in Serial
			ShiftR: in std_logic := '0';
			-- shift the register and write Serial to it
			ShiftW: in std_logic := '0';
			-- parallel access to data (all bits)
			Data: inout std_logic_vector(bits - 1 downto 0) := (others=>'Z');
			-- serial access to data (one bit)
			Serial: inout std_logic
		);
	end component;

	-- Shift register with separate input and output ports
	component shift_register_1dir is
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
			-- write PIn to the register
			W: in std_logic := '0';
			-- shift the register and put the next bit to SOut
			ShiftR: in std_logic := '0';
			-- shift the register and write SIn to it
			ShiftW: in std_logic := '0';
			-- parallel input for writing data to the register
			PIn: in std_logic_vector(bits - 1 downto 0) := (others=>'0');
			-- serial input for writing data to the register
			SIn: in std_logic := '0';
			-- parallel output for reading data from the register
			POut: out std_logic_vector(bits - 1 downto 0);
			-- serial output for reading data from the register
			SOut: out std_logic
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
		variable wbit: std_logic;
		variable regR: std_logic;
	begin
		if rising_edge(Clk) then
			Serial <= 'Z';
			regR := R; -- synchronous toggling in/out of Data
			if Rst = '1' then
				memory := (others=>'0');
			else
				if W = '1' then
					memory := Data;
				end if;
				if ShiftW = '1' then
					wbit := Serial;
				else
					wbit := '0';
				end if;
				if ShiftR = '1' then
					case shift_dir is
						when left => Serial <= memory(bits - 1);
						when right => Serial <= memory(0);
					end case;
				end if;
				if ShiftR = '1' or ShiftW = '1' then
					case shift_dir is
						when left => memory := memory(bits - 2 downto 0) & wbit;
						when right => memory := wbit & memory(bits - 1 downto 1);
					end case;
				end if;
			end if;
		end if;
		-- These assignments of output signals must be outside "if rising_edge". Otherwise,
		-- additional LEs and registers would be allocated for a copy of memory, instead of
		-- feeding output signals back to input.
		if regR = '1' then
			Data <= memory;
		else
			Data <= (others=>'Z');
		end if;
	end process;
end architecture;

library ieee;
use ieee.std_logic_1164.all;
library lib_util;
use lib_util.pkg_shift_register.all;

entity shift_register_1dir is
	generic (
		bits: positive := 8;
		shift_dir: direction := left
	);
	port (
		Clk, Rst, W, ShiftR, ShiftW: in std_logic;
		PIn: in std_logic_vector(bits - 1 downto 0);
		SIn: in std_logic;
		POut: out std_logic_vector(bits - 1 downto 0);
		SOut: out std_logic
	);
end entity;

architecture main of shift_register_1dir is
begin
	process (Clk, Rst, W, ShiftW) is
		variable memory: std_logic_vector(bits - 1 downto 0) := (others=>'0');
	begin
		if rising_edge(Clk) then
			if Rst = '1' then
				memory := (others=>'0');
				SOut <= '0';
			else
				if W = '1' then
					memory := PIn;
				end if;
				case shift_dir is
					when left => SOut <= memory(bits - 1);
					when right => SOut <= memory(0);
				end case;
				if ShiftR = '1' then
					case shift_dir is
						when left => memory := memory(bits - 2 downto 0) & '0';
						when right => memory := '0' & memory(bits - 1 downto 1);
					end case;
				end if;
				if ShiftW = '1' then
					case shift_dir is
						when left => memory := memory(bits - 2 downto 0) & SIn;
						when right => memory := SIn & memory(bits - 1 downto 1);
					end case;
				end if;
			end if;
		end if;
		-- These assignments of output signals must be outside "if rising_edge". Otherwise,
		-- additional LEs and registers would be allocated for a copy of memory, instead of
		-- feeding output signals back to input.
		POut <= memory;
	end process;
end architecture;