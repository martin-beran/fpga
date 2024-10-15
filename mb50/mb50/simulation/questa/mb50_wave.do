onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_mb50/FPGA_CLK
add wave -noupdate /tb_mb50/period
add wave -noupdate /tb_mb50/PS_CLOCK
add wave -noupdate /tb_mb50/PS_DATA
add wave -noupdate /tb_mb50/RESET
add wave -noupdate /tb_mb50/step
add wave -noupdate /tb_mb50/UART_RXD
add wave -noupdate /tb_mb50/UART_TXD
add wave -noupdate /tb_mb50/VGA_B
add wave -noupdate /tb_mb50/VGA_G
add wave -noupdate /tb_mb50/VGA_HSYNC
add wave -noupdate /tb_mb50/VGA_R
add wave -noupdate /tb_mb50/VGA_VSYNC
add wave -noupdate /tb_mb50/dut/cpu/AddrBus
add wave -noupdate /tb_mb50/dut/cpu/Busy
add wave -noupdate /tb_mb50/dut/cpu/cpu_running
add wave -noupdate /tb_mb50/dut/cpu/DataBusRd
add wave -noupdate /tb_mb50/dut/cpu/DataBusWr
add wave -noupdate /tb_mb50/dut/cpu/Halted
add wave -noupdate /tb_mb50/dut/cpu/Rd
add wave -noupdate /tb_mb50/dut/cpu/Rst
add wave -noupdate /tb_mb50/dut/cpu/Run
add wave -noupdate /tb_mb50/dut/cpu/Wr
add wave -noupdate /tb_mb50/dut/memctl/RamAddrBus
add wave -noupdate /tb_mb50/dut/memctl/RamDataBusRd
add wave -noupdate /tb_mb50/dut/memctl/RamDataBusWr
add wave -noupdate /tb_mb50/dut/memctl/RamWr
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {1000400 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 202
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 10
configure wave -griddelta 4
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {1000006 ns} {1000955 ns}
