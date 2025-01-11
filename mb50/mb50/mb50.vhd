-- MB50 main entity, it composes all components of computer MB50

library ieee, lib_io;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.types.all;
use work.sys_params.all;
use lib_io.pkg_reset.all;
use lib_io.pkg_ps2;
use lib_io.pkg_vga;

-- The top level entity that defines computer MB50
entity mb50 is
	port (
		-- The CPU clock
		FPGA_CLK: in std_logic;
		-- The reset button
		RESET: in std_logic;
		-- RS-232 interface
		UART_TXD: out std_logic;
		UART_RXD: in std_logic;
		-- PS/2 keyboard interface
		PS_DATA: inout std_logic;
		PS_CLOCK: inout std_logic;
		-- VGA interface
		VGA_VSYNC: out std_logic;
		VGA_HSYNC: out std_logic;
		VGA_R: out std_logic;
		VGA_G: out std_logic;
		VGA_B: out std_logic
	);
end entity;

architecture main of mb50 is
	signal Rst, run, busy, halted: std_logic;
	signal irq_clk, irq_keyboard: std_logic;
	signal cpu_addr_bus, cdi_addr_bus, memctl_addr_bus: addr_t;
	signal data_bus_rd, cpu_data_bus_wr, cdi_data_bus_wr, memctl_data_bus_wr: byte_t;
	signal cpu_rd, cpu_wr, cdi_rd, cdi_wr, memctl_rd, memctl_wr: std_logic;
	signal reg_idx: reg_idx_t;
	signal reg_data_rd, reg_data_wr: word_t;
	signal reg_rd, reg_wr, reg_csr: std_logic;
	signal ram_addr_bus: std_logic_vector(14 downto 0);
	signal vga_addr_bus: std_logic_vector(15 downto 0);
	signal ram_data_bus_rd, ram_data_bus_wr, vga_data_bus_rd: std_logic_vector(7 downto 0);
	signal ram_wr, vga_clk: std_logic;
	signal sysclk_value: word_t;
	signal ps2_txd, ps2_rxd: std_logic_vector(7 downto 0);
	signal ps2_tx_start, ps2_tx_ready, ps2_rx_valid, ps2_rx_ack: std_logic;
begin
	reset_hnd: reset_button generic map (initial_rst=>true) port map (Clk=>FPGA_CLK, RstBtn=>RESET, Rst=>Rst);
	
	memctl_addr_bus <=
		cpu_addr_bus when busy = '1' else
		cdi_addr_bus;
	memctl_data_bus_wr <=
		cpu_data_bus_wr when busy = '1' else
		cdi_data_bus_wr;
	memctl_rd <=
		cpu_rd when busy = '1' else
		cdi_rd;
	memctl_wr <=
		cpu_wr when busy = '1' else
		cdi_wr;
		
	cpu: entity work.mb5016_cpu port map (
		Clk=>FPGA_CLK, Rst=>Rst,
		Run=>run, Busy=>busy, Halted=>halted,
		Irq(11)=>irq_clk, Irq(12)=>irq_keyboard, Irq(15 downto 13)=>(others=>'0'),
		AddrBus=>cpu_addr_bus,
		DataBusRd=>data_bus_rd, DataBusWr=>cpu_data_bus_wr, Rd=>cpu_rd, Wr=>cpu_wr,
		RegIdx=>reg_idx, RegDataRd=>reg_data_rd, RegDataWr=>reg_data_wr, RegRd=>reg_rd, RegWr=>reg_wr, RegCsr=>reg_csr
	);
	
	memctl: entity work.memctl port map (
		Clk=>FPGA_CLK, Rst=>Rst,
		CpuAddrBus=>memctl_addr_bus, CpuDataBusRd=>data_bus_rd, CpuDataBusWr=>memctl_data_bus_wr,
		CpuRd=>memctl_rd, CpuWr=>memctl_wr,
		RamAddrBus=>ram_addr_bus, RamDataBusRd=>ram_data_bus_rd, RamDataBusWr=>ram_data_bus_wr, RamWr=>ram_wr,
		SysClkValue=>sysclk_value,
		Ps2TxD=>ps2_txd, Ps2TxStart=>ps2_tx_start, Ps2TxReady=>ps2_tx_ready,
		Ps2RxD=>ps2_rxd, Ps2RxValid=>ps2_rx_valid, Ps2RxAck=>ps2_rx_ack
	);
	
	ram: entity work.ram port map (
		address_a=>ram_addr_bus, address_b=>vga_addr_bus(14 downto 0),
		clock_a=>FPGA_CLK, clock_b=>vga_clk,
		data_a=>ram_data_bus_wr, data_b=>(others=>'0'), wren_a=>ram_wr, wren_b=>'0',
		q_a=>ram_data_bus_rd, q_b=>vga_data_bus_rd
	);
	
	system_clock: entity work.system_clock port map (
		Clk=>FPGA_CLK, Rst=>Rst,
		Value=>sysclk_value, Intr=>irq_clk
	);
	
	keyboard: pkg_ps2.ps2 port map (
		Clk=>FPGA_CLK, Rst=>Rst,
		Ps2Clk=>PS_CLOCK, Ps2Data=>PS_DATA,
		TxD=>ps2_txd, TxStart=>ps2_tx_start, TxReady=>ps2_tx_ready,
		RxD=>ps2_rxd, RxValid=>ps2_rx_valid, RxAck=>ps2_rx_ack
	);
	
	keyboard_irq: process (Rst, FPGA_CLK) is
		variable prev_tx_ready, prev_rx_valid: std_logic := '0';
	begin
		if Rst = '1' then
			irq_keyboard <= '0';
			prev_tx_ready := '0';
			prev_rx_valid := '0';
		elsif rising_edge(FPGA_CLK) then
			irq_keyboard <= '0';
			if prev_tx_ready = '0' and ps2_tx_ready = '1' then
				irq_keyboard <= '1';
			end if;
			if prev_rx_valid = '0' and ps2_rx_valid = '1' then
				irq_keyboard <= '1';
			end if;
			prev_tx_ready := ps2_tx_ready;
			prev_rx_valid := ps2_rx_valid;
		end if;
	end process;
	
	display: pkg_vga.vga
		generic map (
			AddrPx => VIDEO_ADDR, -- 0x5a00 = 23040
			AddrAttr => VIDEO_ADDR + 32 * 192, -- 0x7200 = 29184
			AddrBorder => VIDEO_ADDR + 32 * 192 + 32 * 24, -- 0x7500 = 29952
			AddrBlink => VIDEO_ADDR + 32 * 192 + 32 * 24 + 1 -- 0x7501 = 29953
		)
		port map (
			PxClk=>vga_clk,
			HSync=>VGA_HSYNC, VSync=>VGA_VSYNC,
			R=>VGA_R, G=>VGA_G, B=>VGA_B,
			std_logic_vector(Addr)=>vga_addr_bus, Data=>pkg_vga.data_t(vga_data_bus_rd)
		);
	
	pixel_clk: entity lib_io.vga_pixel_clk_pll port map (
		inclk0=>FPGA_CLK, c0=>vga_clk
	);
	
	cdi: entity work.cdi port map (
		Clk=>FPGA_CLK, Rst=>Rst,
		UartTxD=>UART_TXD, UartRxD=>UART_RXD,
		CpuRun=>run, CpuBusy=>busy, CpuHalted=>halted,
		CpuRegIdx=>reg_idx, CpuRegDataRd=>reg_data_rd,
		CpuRegDataWr=>reg_data_wr, CpuRegRd=>reg_rd, CpuRegWr=>reg_wr, CpuRegCsr=>reg_csr,
		AddrBus=>cdi_addr_bus, DataBusRd=>data_bus_rd, DataBusWr=>cdi_data_bus_wr, Rd=>cdi_rd, Wr=>cdi_wr
	);
end architecture;