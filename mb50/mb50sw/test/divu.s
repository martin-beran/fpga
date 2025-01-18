# Testing unsigned division subroutine

$use start, ../sys/start.s
$use constants, ../sys/constants.s
$use macros, ../sys/macros.s
$use stdlib, ../sys/stdlib.s

main:
.set sp, .STACK_BOTTOM
.set r0, (.BG_WHITE | .FG_BLACK) | .BLINK_OFF
.call .clear_screen
.set r0, .BG_WHITE | (.BLINK_1HZ << 8)
.set r1, .VIDEO_BORDER_ADDR
sto r1, r0

$macro do_divu, LINE, A, B
    .set r0, 0
    .set r1, LINE
    .set r2, A
    .call .print_word
    .set r2, '/'
    .call .putchar
    .set r2, B
    .call .print_word
    .set r2, '='
    .call .putchar
    .push r0
    .set r0, A
    .set r1, B
    .call .divu
    mv r3, r1
    mv r2, r0
    .pop r0
    .set r1, LINE
    .call .print_word
    .set r2, '('
    .call .putchar
    mv r2, r3
    .call .print_word
    .set r2, ')'
    .call .putchar
$end_macro

do_divu 0, 1, 0
do_divu 1, 4, 2
do_divu 2, 5, 3
do_divu 3, 1024, 4
do_divu 4, 1025, 4
do_divu 5, 1026, 4
do_divu 6, 1027, 4
do_divu 7, 1028, 4
do_divu 8, 32758, 1000
do_divu 9, 54321, 65535
do_divu 10, 54321, 40000
do_divu 11, 54321, 300
