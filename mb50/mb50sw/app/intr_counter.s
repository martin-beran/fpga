# Displays counts of intrerrupts.

$use init, ../sys/init.s
$use start, ../sys/start.s
$use constants, ../sys/constants.s
$use macros, ../sys/macros.s
$use stdlib, ../sys/stdlib.s

title_clock: $data_b    "=== Clock ===\0"
title_iclk: $data_b     "Interrupts: \0"
title_clk_reg: $data_b  "Register:   \0"
title_clk_val: $data_b  "Value:      \0"
title_keyboard: $data_b "=== Keyboard ===\0"
title_ikbd: $data_b     "Interrupts: \0"

cnt_iclk: $data_w 0
cnt_ikbd: $data_w 0

orig_hnd_iclk: $data_w 0
hnd_iclk:
.push ca
.lda ca, orig_hnd_iclk
exch pc, ca
.set r0, 0
.set r1, 1
.set r2, title_iclk
.call .putstr0
.set r10, cnt_iclk
ld r2, r10
inc1 r2, r2
sto r10, r2
.call .print_word
.pop ca
.ret

orig_hnd_ikbd: $data_w 0
hnd_ikbd:
.push ca
.lda ca, orig_hnd_iclk
exch pc, ca
.set r0, 0
.set r1, 13
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
 # Install clock interrupt handler
.set r10, .addr_intr_hnd_iclk
.set r9, orig_hnd_iclk
ld r8, r10
sto r9, r8
.set r8, hnd_iclk
sto r10, r8
 # Install keyboard interrupt handler
.set r10, .addr_intr_hnd_ikbd
.set r9, orig_hnd_ikbd
ld r8, r10
sto r9, r8
.set r8, hnd_ikbd
sto r10, r8
 # Clear screen
.set r0, .BG_WHITE | .FG_BLACK
.call .clear_screen
.set r0, 0
.set r1, 0
.set r2, title_clock
.call .putstr0
.set r0, 0
.set r1, 12
.set r2, title_keyboard
.call .putstr0
 # Infinite loop, interrupt counts are displayed by interrupt handlers
forever:
     # Display raw clock counter register
    .set r0, 0
    .set r1, 2
    .set r2, title_clk_reg
    .call .putstr0
    .lda r2, .CLK_ADDR
    .call .print_word
    # Read clock value with disabled interrupts
    .set r10, ~.flag_bit_ie
    and f, r10
    .lda r4, .dev_clk_val_s
    .lda r5, .dev_clk_val_ms
    not r10, r10
    or f, r10
    # Display processed clock value
    .set r0, 0
    .set r1, 3
    .set r2, title_clk_val
    .call .putstr0
    mv r2, r4
    .call .print_word
    .set r2, '.'
    .call .putchar
    mv r2, r5
    .call .print_word
    .jmp forever