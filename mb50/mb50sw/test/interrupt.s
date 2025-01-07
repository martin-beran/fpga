# A simple interrupt handler

$use start, ../sys/start.s
$use constants, ../sys/constants.s
$use macros, ../sys/macros.s
$use stdlib, ../sys/stdlib.s

hnd:
.save_all
.set r10, .FLAG_BIT_ICLK
not r10, r10
and f, r10
.restore_all_intr
reti pc, pc

main:
.set sp, .STACK_BOTTOM
.set ia, hnd
csrw csr1, ia
csrr r5, csr1
.set r10, .FLAG_BIT_IE
or f, r10
forever: .jmp forever
