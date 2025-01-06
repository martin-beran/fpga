# Displays counts of intrerrupts.

$use init, ../sys/init.s
$use start, ../sys/start.s
$use constants, ../sys/constants.s
$use macros, ../sys/macros.s
$use stdlib, ../sys/stdlib.s

title_iclk: $data_b "Clock interrupts:    \0"
title_ikbd: $data_b "Keyboard interrupts: \0"
cnt_iclk: $data_w 0
cnt_ikbd: $data_w 0

hnd_iclk:
.push ca
.set r0, 0
.set r1, 0
.set r2, title_iclk
.call .putstr0
.set r10, cnt_iclk
ld r2, r10
inc1 r2, r2
sto r10, r2
.call .print_word
.pop ca
.ret

hnd_ikbd:
.push ca
.set r0, 0
.set r1, 1
.set r2, title_ikbd
.call .putstr0
.set r10, cnt_ikbd
ld r2, r10
inc1 r2, r2
sto r10, r2
.call .print_word
.pop ca
.ret

main:
 # Install interrupt handlers
.set r10, hnd_iclk
.set r9, .addr_intr_hnd_iclk
sto r9, r10
.set r10, hnd_ikbd
.set r9, .addr_intr_hnd_ikbd
sto r9, r10
 # Clear screen
.set r0, .BG_WHITE | .FG_BLACK
.call .clear_screen
 # Infinite loop, interrupt counts are displayed by interrupt handlers
forever: .jmp forever
