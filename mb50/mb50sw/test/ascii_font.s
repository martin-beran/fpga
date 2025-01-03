# Font demo - display all printable ASCII characters

$use start, ../sys/start.s
$use macros, ../sys/macros.s
$use stdlib, ../sys/stdlib.s
$use font, ../sys/font.s

# Main program entry point
main:
.set r0, .BG_BLACK | .FG_BLACK
.call .clear_screen
 # Set black on white/yellow checkered pattern
.set r0, .VIDEO_ATTR_ADDR
.set r1, 32 / 2
.set r2, .BG_WHITE + (.BG_YELLOW << 8)
.call .memset_w
.set r0, .VIDEO_ATTR_ADDR + 32
.set r1, 32 / 2
.set r2, .BG_YELLOW + (.BG_WHITE << 8)
.call .memset_w
.set r0, .VIDEO_ATTR_ADDR + 2 * 32
.set r1, 32 / 2
.set r2, .BG_WHITE + (.BG_YELLOW << 8)
.call .memset_w
 # Draw characters
.set r0, ' ' # r0 = current character
.set r1, .VIDEO_ADDR # r1 = current position in video RAM
char_loop:
    .set r3, 0x7f # r3 = tmp
    cmpu r0, r3
    .jmpz char_end
    # display character
    mv r2, r0 # r2 = current character
    .set r3, 0x0020
    sub r2, r3
    .set r3, 3
    shl r2, r3
    .set r3, font.ascii_0x20
    add r2, r3 # r2 = address of first byte of character bitmap
    mv r4, r1 # r4 = target address
    .set r5, 8 # r5 = number of pixel lines in character
    pixel_loop:
        ldb r6, r2
        rev r6, r6
        .set r3, 8
        shr r6, r3
        stob r4, r6
        inc1 r2, r2
        .set r3, 32
        add r4, r3
        dec1 r5, r5
        .jmpnz pixel_loop
    # next character
    inc1 r0, r0
    inc1 r1, r1
    .set r3, 31
    and r3, r1
    .jmpnz eol
    .set r3, 32 * 7
    add r1, r3
    eol: .jmp char_loop
char_end:

# End of program
ill r0, r0 # halt
