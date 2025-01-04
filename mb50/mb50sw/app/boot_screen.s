# Display boot screen

# This program performs system initialization, which displays the boot message,
# the program name, and enters an infinite loop.

$use init, ../sys/init.s
$use start, ../sys/start.s
$use constants, ../sys/constants.s
$use macros, ../sys/macros.s
$use stdlib, ../sys/stdlib.s

program_name: $data_b "Program: boot_screen"
$const end, __addr
$const program_name_len, __addr - program_name

main:
.set r0, end
.set r0, end
.set0 r0
.set r1, 23
.set r2, program_name
.set r3, program_name_len
.call .putstr_len
loop: .jmp loop
