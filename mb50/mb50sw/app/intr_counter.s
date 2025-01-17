# Displays counts of intrerrupts, value of system clock, and pressed keys

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
title_scan: $data_b     "Scan code:  \0"
title_kbd_mods: $data_b "Modifiers:  \0"
title_kbd_rxd: $data_b  "Received:   \0"
msg_halt: $data_b "Press Esc to generate exception\0"
msg_reg: $data_b "Press Enter to display registers\0"

cnt_iclk: $data_w 0
cnt_ikbd: $data_w 0

orig_hnd_iclk: $data_w 0
hnd_iclk:
.push ca
.lda ca, orig_hnd_iclk
exch pc, ca
.set0 r0
.set r1, 2
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
.lda ca, orig_hnd_ikbd
exch pc, ca
.set0 r0
.set r1, 14
.set r2, title_ikbd
.call .putstr0
.set r10, cnt_ikbd
ld r2, r10
inc1 r2, r2
sto r10, r2
.call .print_word
.set0 r0
.set r1, 15
.set r2, title_scan
.call .putstr0
.lda r2, ._scan_0
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
.set0 r0
.set r1, 0
.set r2, title_clock
.call .putstr0
.set0 r0
.set r1, 12
.set r2, title_keyboard
.call .putstr0
.set0 r0
.set r1, 22
.set r2, msg_halt
.call .putstr0
.set0 r0
.set r1, 23
.set r2, msg_reg
.call .putstr0
 # Infinite loop, interrupt counts are displayed by interrupt handlers
forever:
     # Display raw clock counter register
    .set0 r0
    .set r1, 3
    .set r2, title_clk_reg
    .call .putstr0
    .lda r2, .CLK_ADDR
    .call .print_word
    # Read clock value
    .dev_clk_read r4, r5, r10
    # Display processed clock value
    .set0 r0
    .set r1, 4
    .set r2, title_clk_val
    .call .putstr0
    mv r2, r4
    .call .print_word
    .set r2, '.'
    .call .putchar
    mv r2, r5
    .call .print_word
    # Display last character received from keyboard
    .set0 r0
    .set r1, 16
    .set r2, title_kbd_mods
    .call .putstr0
    mv r3, r0
    .call .read_keyboard
    exch r3, r0
    mv r4, r1
    .set r1, 16
    mv r2, r4
    .call .print_byte
    .set0 r0
    .set r1, 17
    .set r2, title_kbd_rxd
    .call .putstr0
    .jmp0 r3, forever
    mv r2, r3
    .call .print_byte
    .set r2, ' '
    .call .putchar
    .set r2, ' '
    .set r4, 0x20
    .jmpltu r3, r4, nonprintable
    .set r4, 0x7e
    .jmpgtu r3, r4, nonprintable
    mv r2, r3
    nonprintable: .call .putchar
    # Test for Esc
    .set r10, .KEY_ESC
    .jmpne r3, r10, not_esc
    ill r0, r0 # Hardware exception
    # Test for Enter
    not_esc: .set r10, .KEY_ENTER
    .jmpne r3, r10, not_enter
    .set r10, .FLAG_BIT_EXC
    or f, r10 # Software exception
    not_enter: .jmp forever
