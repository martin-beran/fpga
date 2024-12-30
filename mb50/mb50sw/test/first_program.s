# Assembler source of the historically first program used for initial debugging
# of MB50. It was originally hand-coded in machine code and stored in file
# mb50.mif in the VHDL directory.

# video coordinates [x, y]
#
# video attr [0, 0]
ldis r0, pc
$data_w 0x7200

# video blink, colors [0,0]=bw, [1,0]=RG
ldis r1, pc
$data_w 0xc287

sto r0, r1

# video pixel [0, 2]
ldis r0, pc
$data_w 0x5a40

not r2, r2
sto r0, r2

#video border, blink
ldis r0, pc
$data_w 0x7500

# border color C, blink 1 Hz
ldis r1, pc
$data_w 0x1e03

sto r0, r1
