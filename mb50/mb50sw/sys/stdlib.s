# Standard library: Basic subroutines

$use constants, constants.s
$use macros, macros.s
$use font, font.s

# Do not execute any code in this file.
.jmp _skip_this_file

### Operations on memory ranges and strings ###################################

# Store a byte to a range of memory addresses.
# In:
# r0 = the start address of the target range
# r1 = the length of the target range in bytes
# r2 = the register containing the value to store in the lower byte
# Out:
# r0 = the address of the last stored byte plus one
# r1 = zero
# Modifies:
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
# r0 = the address of the last stored byte plus one
# r1 = zero
# Modifies:
memset_w:
.testz r1
.retz
sto r0, r2
inc2 r0, r0
dec1 r1, r1
.jmp memset_w

# Convert a word to a string in decimal representation.
# It stores the result to the provided buffer as a null-terminated string,
# padded before the first digit by the specified character
# In:
# r0 = the address for storing the result, it must point to a buffer of 6 bytes
# r1 = the word to be converted
# r2 = the padding character
# Out:
# r0 = the address of the first digit of the result (after the last padding character)
# Modifies: r1, r7, r8, r9, r10
to_dec_w:
.push ca
mv r7, r1 # r7 = input word (r7 unused by memset_b, divu)
.set r1, 5 # at most 5 digits
.call memset_b # prepare padding
stob r0, r1 # null-terminate, r1 = 0 set by memset_b
exch r0, r7 # r0 = input word, r7 = digit address
_to_dec_w_digit:
    dec1 r7, r7
    .set r1, 10
    .call divu
    .set r10, '0' # convert remainder to digit
    add r1, r10
    stob r7, r1
    .jmpn0 r0, _to_dec_w_digit
mv r0, r7
.pop ca
.ret

### Arithmetic ################################################################

# Unsigned integer division.
# Division by zero returns r0=0xffff, r1=0.
# In:
# r0 = dividend
# r1 = divisor
# Out:
# r0 = quotient
# r1 = remainder
# Modifies: r10, r9, r8
divu:
 # Handle division by zero
.jmpn0 r1, _divu_not0
.set r0, 0xffff
.set0 r1
.ret
 # Align divisor to dividend, r10 = number of iterations
_divu_not0: .set0 r10
.set r9, 1
_divu_align:
    inc1 r10, r10
    shl r1, r9 # r1 <<= 1
    .jmpnc _divu_align_cmp
    shr r1, r9
    .set r8, 0x8000
    or r1, r8
    .jmp _divu_aligned
    _divu_align_cmp: .jmpleu r1, r0, _divu_align
    shr r1, r9
 # do division (r9 == 1)
_divu_aligned:
.set0 r8 # quotient
_divu_do:
    shl r8, r9 # quotient <<= 1
    .jmpltu r0, r1, _divu_add_0
        inc1 r8, r8
        sub r0, r1
    _divu_add_0: shr r1, r9
    dec1 r10, r10
    .jmpnz _divu_do
 # Set result
mv r1, r0
mv r0, r8
.ret

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

# Get attribute.
# In:
# R0 = coordinate X
# R1 = coordinate Y
# Out:
# R2 = the attribute value in the lower byte
# Modifies: r10, r9
get_attr:
mv r10, r1
.set r9, 5
shl r10, r9
add r10, r0
.set r9, .VIDEO_ATTR_ADDR
add r10, r9
.set0 r2
ldb r2, r10
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

# Display a string of specified length.
# In:
# R0 = coordinate X (0..32) of the 1st character
# R1 = coordinate Y (0..23) of the 1st character
# R2 = address of the string
# R3 = length of the string
# Out:
# R0 = coordinate X for the next character
# R1 = coordinate Y for the next character
# Modifies: r2, r3, r6, r7, r8, r9, r10
putstr_len:
mv r6, r2
_char_loop1:
.testz r3
.retz
.set0 r2
ldb r2, r6
.push ca
.call putchar
.pop ca
inc1 r6, r6
dec1 r3, r3
.jmp _char_loop1

# Display a single hexadecimal digit.
# In:
# R0 = coordinate X (0..32) of the 1st character
# R1 = coordinate Y (0..23) of the 1st character
# R2 = value to be displayed in the lowest 4 bits
# Out:
# R0 = coordinate X for the next character
# R1 = coordinate Y for the next character
# Modifies: r2, r7, r8, r9, r10
print_hex_digit:
.set r10, 0x000f
and r2, r10
.set r10, 10
.jmpltu r2, r10, _lt_a
.set r10, 'a' - ('9' + 1)
add r2, r10
_lt_a:
.set r10, '0'
add r2, r10
.jmp putchar

# Display a single byte as two hexadecimal digits.
# In:
# R0 = coordinate X (0..32) of the 1st character
# R1 = coordinate Y (0..23) of the 1st character
# R2 = value to be displayed in the lower byte
# Out:
# R0 = coordinate X for the next character
# R1 = coordinate Y for the next character
# Modifies: r2, r6, r7, r8, r9, r10
print_byte:
.push ca
mv r6, r2
.set r10, 4
shr r2, r10
.call print_hex_digit
mv r2, r6
.call print_hex_digit
.pop ca
.ret

# Display a word (two bytes) as four hexadecimal digits.
# In:
# R0 = coordinate X (0..32) of the 1st character
# R1 = coordinate Y (0..23) of the 1st character
# R2 = value to be displayed
# Out:
# R0 = coordinate X for the next character
# R1 = coordinate Y for the next character
# Modifies: r2, r6, r7, r8, r9, r10
print_word:
.push ca
mv r6, r2
.set r10, 12
shr r2, r10
.call print_hex_digit
mv r2, r6
.set r10, 8
shr r2, r10
.call print_hex_digit
mv r2, r6
.set r10, 4
shr r2, r10
.call print_hex_digit
mv r2, r6
shr r2, r10
.call print_hex_digit
.pop ca
.ret

# Diagnostics #################################################################

_title_r: $data_b "Registers:\0"
_title_csr: $data_b "CSRs:\0"
_delimiter: $data_b ": \0"
_title_r11: $data_b "sp\0"
_title_r12: $data_b "ca\0"
_title_r13: $data_b "ia\0"
_title_r14: $data_b "f\0"
_title_r15: $data_b "pc\0"

_csrr0: csrr r2, csr0
mv pc, r10
_csrr1: csrr r2, csr1
mv pc, r10
csrr r2, csr2
mv pc, r10
csrr r2, csr3
mv pc, r10
csrr r2, csr4
mv pc, r10
csrr r2, csr5
mv pc, r10
csrr r2, csr6
mv pc, r10
csrr r2, csr7
mv pc, r10
csrr r2, csr8
mv pc, r10
csrr r2, csr9
mv pc, r10
csrr r2, csr10
mv pc, r10
csrr r2, csr11
mv pc, r10
csrr r2, csr12
mv pc, r10
csrr r2, csr13
mv pc, r10
csrr r2, csr14
mv pc, r10
csrr r2, csr15
mv pc, r10

# Displays values of registers and CSRs.
# Note that values of PC do not make much sense.
# In:
# Out:
# Modifies:
display_registers:
.save_all
.set r0, .BG_WHITE | .FG_BLACK
.call .clear_screen
.set r0, 5
.set r1, 0
.set r2, _title_r
.call putstr0
.set r0, 21
.set r2, _title_csr
.call putstr0
.set r0, 2
.set r1, 13
.set r2, _title_r11
.call putstr0
.set r0, 2
.set r1, 14
.set r2, _title_r12
.call putstr0
.set r0, 2
.set r1, 15
.set r2, _title_r13
.call putstr0
.set r0, 2
.set r1, 16
.set r2, _title_r14
.call putstr0
.set r0, 2
.set r1, 17
.set r2, _title_r15
.call putstr0
.set r5, 0 # r5 = register index
.set r4, 15 * 2 # r4 = offset of register index from sp
.set r1, 2
_loop_reg:
    .set r0, 5
    mv r2, r5
    .call print_hex_digit
    .set r2, _delimiter
    .call putstr0
    mv r10, sp
    add r10, r4
    ld r2, r10
    .call print_word
    inc1 r1, r1
    inc1 r5, r5
    dec2 r4, r4
    .set r10, 15
    .jmpleu r5, r10, _loop_reg
.set r5, 0 # r5 = CSR index
.set r4, _csrr0 # r4 = subroutine to read a CSR
.set r1, 2
_loop_csr:
    .set r0, 21
    mv r2, r5
    .call print_hex_digit
    .set r2, _delimiter
    .call putstr0
    mv r10, r4
    exch pc, r10
    .call print_word
    inc1 r1, r1
    inc1 r5, r5
    .set r10, _csrr1 - _csrr0
    add r4, r10
    .set r10, 15
    .jmpleu r5, r10, _loop_csr
.restore_all_intr # allow use in an interrupt handler
.ret

### Keep this label at the end of this file ###################################

_skip_this_file:
