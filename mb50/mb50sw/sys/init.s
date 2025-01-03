# System initialization
# This file should be included by the first $use in the main program. It
# performs early system initialization (configures interrupt handling, clears
# screen, etc.).

$use constants, constants.s
$use macros, macros.s
$use stdlib, stdlib.s

init:
 # Initialize the stack
.set sp, .STACK_BOTTOM
 # Initialize screen
.set r0, .BG_WHITE | .FG_BLACK
.call clear_screen
.set r0, .BG_BLACK | ((BLINK_1HZ | BLINK_OFF) << 8)
.set r1, VIDEO_BORDER_ADDR
sto r1, r0

# TODO
