# Initialization code
# This file should be included by the first $use in the main program, so that
# it starts at address 0x0000. It jumps over other included code to the entry
# point marked by label .main.
start:
ld pc, pc
$data_w .main
