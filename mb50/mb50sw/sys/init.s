# System initialization
# This file should be included by the first $use in the main program. It
# performs early system initialization (configures interrupt handling, clears
# screen, etc.).

$use constants, constants.s
$use macros, macros.s
$use stdlib, stdlib.s
$use interrupts, interrupts.s

.jmp init

boot_msg:
$data_b "Computer MB50\n\n"
$data_b "CPU: MB5016\n\n"
$data_b "Author: Martin Beran\n"
$data_b "E-mail: martin@mber.cz\n"
$data_b "GitHub: https://github.com/martin-beran/fpga/tree/master/mb50\0"

init:
 # Disable interrupts
.set0 f
 # Initialize the stack
.set sp, .STACK_BOTTOM
 # Initialize screen
.set r0, (.BG_WHITE | .FG_BLACK) | .BLINK_OFF
.call .clear_screen
.set r0, .BG_WHITE | (.BLINK_1HZ << 8)
.set r1, .VIDEO_BORDER_ADDR
sto r1, r0
# Initialize interrupt handling
.call .intr_init

### Initialization done #######################################################

# Display boot message
.set r0, 9
.set0 r1
.set r2, boot_msg
.call .putstr0
