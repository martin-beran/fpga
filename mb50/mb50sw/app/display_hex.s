# Display 4 bit and 1 byte values in hex

# This program displays all 16 hexadecimal digits, then all single byte
# values in hexadecimal, and then a fixed word in hexadecimal.
# Then it enters an infinite loop.

$use init, ../sys/init.s
$use start, ../sys/start.s
$use constants, ../sys/constants.s
$use macros, ../sys/macros.s
$use stdlib, ../sys/stdlib.s

main:
.set r0, .BG_WHITE | .FG_BLACK
.call .clear_screen

# Display all hexadecimal digits
.set0 r0
.set0 r1
.set0 r9
.set r10, 0x0f
loop_4bits:
    mv r2, r9
    .save9
    .call .print_hex_digit
    .restore9
    inc1 r9, r9
    .jmpleu r9, r10, loop_4bits

# One line space
.set r2, '\n'
.call .putchar
.set r2, '\n'
.call .putchar

# Display all byte values in hexadecimal
.set0 r9
.set r10, 0xff
.set r8, (.BG_WHITE | .FG_BLACK) | .BLINK_OFF
.set r7, (.BG_YELLOW | .FG_BLUE) | .BLINK_OFF
loop_byte:
    .save9
    mv r2, r8
    .call .set_attr
    inc1 r0, r0
    .call .set_attr
    .restore9
    dec1 r0, r0
    exch r7, r8
    .save7
    mv r2, r9
    .call .print_byte
    .restore7
    inc1 r9, r9
    .jmpleu r9, r10, loop_byte

# One line space
.set r2, '\n'
.call .putchar
.set r2, '\n'
.call .putchar

# Display a fixed hexadecimal value
.set r2, 0x369c
.call .print_word

forever: .jmp forever
