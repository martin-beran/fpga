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
		-- Read interface: register index
		RdIdx: in reg_idx_t;
		-- Read interface: value
		RdData: out word_t;
		-- Write interface: register index
		WrIdx: in reg_idx_t;
		-- Write interface: value
		WrData: in word_t;
		-- Write interface: enable write
		Wr: in std_logic;
		-- Permit write of csr0 bit H
		WrCsr0H: in std_logic;
		-- Value of csr1
		Csr1Data: out word_t
	);
end entity;

architecture main of mb5016_csr is
	signal csr0: unsigned(8 downto 0) := (others=>'0');
	signal csr1: word_t := (others=>'0');
begin
	with RdIdx select RdData <=
		unsigned("0000000" & std_logic_vector(csr0)) when to_reg_idx(0),
		csr1 when to_reg_idx(1),
		X"0000" when others;
	Csr1Data <= csr1;
	process (Clk, Rst) is
	begin
		if Rst = '1' then
			csr0 <= (others=>'0');
			csr1 <= (others=>'0');
		elsif rising_edge(Clk) then
			if Wr = '1' then
				case WrIdx is
					when to_reg_idx(0) =>
						csr0 <= (WrData(8) and WrCsr0H) & WrData(7 downto 0);
					when to_reg_idx(1) =>
						csr1 <= WrData;
					when others=>
						null;
				end case;
			end if;
		end if;
	end process;
end architecture;