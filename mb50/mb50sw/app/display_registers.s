# Display values of all registers

# This program displays values of all registers (normal and CSRs) in hexadecimal.
# Then it enters an infinite loop.

$use init, ../sys/init.s
$use start, ../sys/start.s
$use constants, ../sys/constants.s
$use macros, ../sys/macros.s
$use stdlib, ../sys/stdlib.s

main:
.call .display_registers

forever: .jmp forever
