-- CPU MB5016: The array of Control and Status Registers (csr0...csr15)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.types.all;

-- There is hardwired logic of read/write permissions for individual bits.
-- There are special signals (e.g., Csr0H) to override some permisions. These signals are
-- intended for internal logic of CPU that neads more permissions than CSRR/CSRW instructions.
-- There are also signals for direct reading of some bits, which are always available without
-- setting RdIdx first.
entity mb5016_csr is
	port (
		-- CPU clock
		Clk: in std_logic;
		-- Reset (sets registers to all zeros)
		Rst: in std_logic;
		-- Read/write interface: register index
		Idx: in reg_idx_t;
		-- Read interface: value
		RdData: out word_t;
		-- Write interface: value
		WrData: in word_t;
		-- Write interface: enable write
		Wr: in std_logic;
		-- Enable write of csr0 bit H
		EnaCsr0H: in std_logic
	);
end entity;

architecture main of mb5016_csr is
	signal csr0: unsigned(8 downto 0) := (others=>'0');
	signal csr1, csr2, csr3: word_t := (others=>'0');
begin
	with Idx select RdData <=
		-- With to_reg_idx(0), compilation in Questa reports:
		-- Warning: (vcom-1563) Choice in ordinary selected signal assignment must be locally static.
		-- unsigned("0000000" & std_logic_vector(csr0)) when to_reg_idx(0),
		unsigned("0000000" & std_logic_vector(csr0)) when X"0",
		-- csr1 when to_reg_idx(1),
		csr1 when X"1",
		-- csr2..csr3 when to_reg_idx(2..3)
		csr2 when X"2",
		csr3 when X"3",
		X"0000" when others;
	process (Clk, Rst) is
	begin
		if Rst = '1' then
			csr0 <= (others=>'0');
			csr1 <= (others=>'0');
			csr2 <= (others=>'0');
			csr3 <= (others=>'0');
		elsif rising_edge(Clk) then
			if Wr = '1' then
				case Idx is
					-- when to_reg_idx(0) =>
					when X"0" =>
						csr0 <= (WrData(8) and EnaCsr0H) & WrData(7 downto 0);
					-- when to_reg_idx(1) =>
					when X"1" =>
						csr1 <= WrData;
					-- when to_reg_idx(2..5) =>
					when X"2" =>
						csr2 <= WrData;
					when X"3" =>
						csr3 <= WrData;
					when others=>
						null;
				end case;
			end if;
		end if;
	end process;
end architecture;