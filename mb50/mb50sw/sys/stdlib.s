# Standard library: Basic subroutines

$use constants, constants.s
$use macros, macros.s
$use font, font.s

# Do not execute any code in this file.
.jmp _skip_this_file

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
# X=32 is allowed for character output and is interpreted so that newline moves
# to the beginning of the next line and any other character is displayed at X=0
# on the next line.

# Clear screen and set attributes.
# In:
# r0 = the attribute value to use for the whole screen
# Out:
# Modifies: r0, r9, r10
clear_screen:
.set r10, .VIDEO_ATTR_W * .VIDEO_ATTR_H
.set r9, .VIDEO_ATTR_ADDR
_clear_screen_attr:
    stob r9, r0
    inc1 r9, r9
    dec1 r10, r10
    .jmpnz _clear_screen_attr
.set r10, (.VIDEO_PX_W * .VIDEO_PX_H) / 8
.set0 r0
.set r9, .VIDEO_PX_ADDR
_clear_screen_px:
    stob r9, r0
    inc1 r9, r9
    dec1 r10, r10
    .jmpnz _clear_screen_px
.ret

# Set attribute.
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

# Display a single character.
# The character must be printable (ASCII 32-126) or newline (LF, ASCII 10).
# The routine works correctly for other character codes, but interprets bytes
# not belonging to the font as glyph definitions.
# Each call move X one character to the right in the range 0..32. Displaying
# newline moves to the beginning of the next line. Any other character
# displayed with X==32 is displayed at the beginning of the next line.
# Y wraps from 23 back to 0.
# In:
# R0 = coordinate X (0..32)
# R1 = coordinate Y (0..23)
# R2 = the character to be displayed
# Out:
# R0 = coordinate X for the next character
# R1 = coordinate Y for the next character
# Modifies: r2, r7, r8, r9, r10
putchar:
 # Handle newline
.set r10, '\n'
cmpu r2, r10
.jmpnz _not_nl
.set0 r0
inc1 r1, r1
.set r10, .VIDEO_ATTR_H
cmpu r1, r10
.retnz
.set0 r1
.ret
 # Handle X==32
_not_nl:
.set r10, .VIDEO_ATTR_W
cmpu r0, r10
.jmpnz _not32
.set0 r0
inc1 r1, r1
.set r10, .VIDEO_ATTR_H
cmpu r1, r10
.jmpnz _not32
.set0 r1
# Display the character
_not32:
.set r10, ' '
sub r2, r10
.set r10, 3
shl r2, r10
.set r10, .ascii_0x20
add r2, r10 # r2 = address of 1st pixel line in font
mv r9, r1
.set r10, 8
shl r9, r10
add r9, r0
.set r10, .VIDEO_PX_ADDR
add r9, r10 # r9 = address of 1st pixel line on screen
.set r8, 8
_pixel_line:
    ldb r7, r2
    rev r7, r7
    .set r10, 8
    shr r7, r10
    stob r9, r7
    inc1 r2, r2
    .set r10, .VIDEO_ATTR_W
    add r9, r10
    dec1 r8, r8
    .jmpnz _pixel_line
 # Move X to the next character
inc1 r0, r0
.ret

# Display a zero-terminated string.
# In:
# R0 = coordinate X (0..32) of the 1st character
# R1 = coordinate Y (0..23) of the 1st character
# R2 = address of the string
# Out:
# R0 = coordinate X for the next character
# R1 = coordinate Y for the next character
# Modifies: r2, r6, r7, r8, r9, r10
putstr0:
mv r6, r2
_char_loop:
.set0 r2
ldb r2, r6
.testz r2
.retz
.push ca
.call putchar
.pop ca
inc1 r6, r6
.jmp _char_loop

### Keep this label at the end of this file ###################################

_skip_this_file:
