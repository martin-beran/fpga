# Display boot screen

# This program performs system initialization, which displays the boot message,
# and enters an infinite loop.

$use init, ../sys/init.s
$use start, ../sys/start.s
$use constants, ../sys/constants.s
$use macros, ../sys/macros.s
$use stdlib, ../sys/stdlib.s

main:
.jmp main
