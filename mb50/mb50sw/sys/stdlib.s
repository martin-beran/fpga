# Standard library: Basic subroutines

$use constants, constants.s
$use macros, macros.s

# Do not execute any code in this file.
.jmp skip_this_file

### Operations on memory ranges ###############################################

# Store a byte to a range of memory addresses.
# In:
# r0 = the start address of the target range
# r1 = the length of the target range in bytes
# r2 = the register containing the value to store in the lower byte
# Out:
# Modifies: r0, r1
memset_b:
.testz r1
.retz
stob r0, r2
inc1 r0, r0
dec1 r1, r1
.jmp memset_b

# Store a word to a range of memory addresses.
# In:
# r0 = the start address of the target range
# r1 = the length of the target range in words
# r2 = the register containing the value to store
# Out:
# Modifies: r0, r1
memset_w:
.testz r1
.retz
sto r0, r2
inc2 r0, r0
dec1 r1, r1
.jmp memset_w

### Display output ############################################################

# Display coordinates are:
# X = left to right, 0-255 (pixels), 0-31 (characters and attributes)
# Y = top to bottom, 0-191 (pixels), 0-23 (characters and attributes)

# Clear screen and set attributes
# In:
# r0 = the attribute value to use for the whole screen
# Out:
# Modifies: r0, r10, r9
clear_screen:
.set r10, .VIDEO_ATTR_W * .VIDEO_ATTR_H
.set r9, .VIDEO_ATTR_ADDR
clear_screen_attr:
    stob r9, r0
    inc1 r9, r9
    dec1 r10, r10
    .jmpnz clear_screen_attr
.set r10, (.VIDEO_PX_W * .VIDEO_PX_H) / 8
.set0 r0
.set r9, .VIDEO_PX_ADDR
clear_screen_px:
    stob r9, r0
    inc1 r9, r9
    dec1 r10, r10
    .jmpnz clear_screen_px
.ret

# Set attribute
# In:
# R0 = coordinate X
# R1 = coordinate Y
# R2 = the attribute value in the lower byte
# Out:
# Modifies: r10, r9
set_attr:
mv r10, r1
.set r9, 5
shl r10, r9
add r10, r0
.set r9, .VIDEO_ATTR_ADDR
add r10, r9
stob r10, r2
.ret

### Keep this label at the end of this file ###################################

skip_this_file:
