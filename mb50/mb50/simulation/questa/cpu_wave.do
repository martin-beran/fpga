onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_mb5016_cpu/M_A_R_K
add wave -noupdate /tb_mb5016_cpu/S_T_E_P
add wave -noupdate /tb_mb5016_cpu/Clk
add wave -noupdate /tb_mb5016_cpu/Rst
add wave -noupdate /tb_mb5016_cpu/Run
add wave -noupdate /tb_mb5016_cpu/Busy
add wave -noupdate /tb_mb5016_cpu/Halted
add wave -noupdate /tb_mb5016_cpu/Irq
add wave -noupdate /tb_mb5016_cpu/AddrBus
add wave -noupdate /tb_mb5016_cpu/DataBusRd
add wave -noupdate /tb_mb5016_cpu/DataBusWr
add wave -noupdate /tb_mb5016_cpu/Rd
add wave -noupdate /tb_mb5016_cpu/Wr
add wave -noupdate /tb_mb5016_cpu/RegIdx
add wave -noupdate /tb_mb5016_cpu/RegDataRd
add wave -noupdate /tb_mb5016_cpu/RegDataWr
add wave -noupdate /tb_mb5016_cpu/RegRd
add wave -noupdate /tb_mb5016_cpu/RegWr
add wave -noupdate /tb_mb5016_cpu/RegCsr
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ns} 0} {{Cursor 2} {0 ns} 0}
quietly wave cursor active 2
configure wave -namecolwidth 167
configure wave -valuecolwidth 65
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
WaveRestoreZoom {0 ns} {1017 ns}
