# Starting the main program
# This file should be included by a $use in the main program after including
# any initialization code. It jumps over other included code to the entry point
# marked by global label "main".
start:
ld pc, pc
$data_w .main
