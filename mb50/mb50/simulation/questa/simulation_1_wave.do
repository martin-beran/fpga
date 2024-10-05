onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_mb5016_registers/Clk
add wave -noupdate /tb_mb5016_registers/IdxA
add wave -noupdate /tb_mb5016_registers/IdxB
add wave -noupdate /tb_mb5016_registers/RdDataA
add wave -noupdate /tb_mb5016_registers/RdDataB
add wave -noupdate /tb_mb5016_registers/Rst
add wave -noupdate /tb_mb5016_registers/WrA
add wave -noupdate /tb_mb5016_registers/WrB
add wave -noupdate /tb_mb5016_registers/WrDataA
add wave -noupdate /tb_mb5016_registers/WrDataB
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ns} 0} {{Cursor 2} {310 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 186
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
WaveRestoreZoom {0 ns} {313 ns}
