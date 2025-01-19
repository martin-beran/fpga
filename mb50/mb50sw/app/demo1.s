# A demo program

$use init, ../sys/init.s
$use start, ../sys/start.s
$use constants, ../sys/constants.s
$use macros, ../sys/macros.s
$use stdlib, ../sys/stdlib.s

menu_txt:
$data_b "1) ASCII table\n"
$data_b "2) Time since boot\n"
$data_b "3) Colors\n"
$data_b "4) Panic\n"
$data_b "\n(Esc for return to this menu)\0"

main:
.set r0, 5
.set0 r1
.call .sleep

main_menu:
.set r0, .BG_WHITE | .FG_BLACK | .BLINK_OFF
.call .clear_screen
.set0 r0
.set0 r1
.set r2, menu_txt
.call .putstr0

select_menu:
.call .read_keyboard
.set r10, '1'
.jmpeq r0, r10, sub_ascii
.set r10, '2'
.jmpeq r0, r10, sub_time
.set r10, '3'
.jmpeq r0, r10, sub_colors
.set r10, '4'
.jmpeq r0, r10, sub_panic
.jmp select_menu

# Display printable ASCII characters
sub_ascii:
 # Set black background
.set r0, .BG_BLACK | .FG_BLACK | .BLINK_OFF
.call .clear_screen
.set r0, .BG_BLACK
.set r1, .VIDEO_BORDER_ADDR
stob r1, r0
 # Draw characters
.set r3, ' ' # r3 = current character
.set0 r0
.set0 r1
char_loop:
    # Set black on white/yellow checkered pattern
    .set r2, .BG_WHITE | .FG_BLACK
    mv r10, r0
    xor r10, r1
    .set r9, 0x01
    and r10, r9
    .jmpz checkers
    .set r2, .BG_YELLOW | .FG_BLACK
    checkers: .call .set_attr
    mv r2, r3
    .call .putchar
    # Next character
    inc1 r3, r3
    .set r10, 0x7f
    .jmpltu r3, r10, char_loop
 # Show blinking colors
.set r0, 12 # r0 = x
.set r1, 12 # r1 = y
.set r10, .BG_WHITE
.set r9, .FG_BLACK | .BLINK_ON
colors_loop:
    mv r2, r10
    or r2, r9
    .save9
    .call .set_attr
    .restore9
    inc1 r0, r0
    dec1 r10, r10
    .set r8, 0x10
    add r9, r8
    .testz r10
    .jmpnz colors_loop
ascii_kbd_loop:
    .call .read_keyboard
    .set r10, .KEY_ESC
    .jmpeq r0, r10, main_menu
.jmp ascii_kbd_loop

# Display time from boot
title_clk_val: $data_b  "Time from boot: \0"

dec_buf: $addr __addr + 6 # buffer for printing decimal numbers

sub_time:
.set r0, .BG_WHITE | .FG_BLACK | .BLINK_OFF
.call .clear_screen
 # Read clock value
time_loop: .dev_clk_read r1, r5, r10
 # Display processed clock value
.set r0, dec_buf
.set r2, ' '
.call .to_dec_w
.set0 r0
.set r1, 4
.set r2, title_clk_val
.call .putstr0
.set r1, 4
.set r2, dec_buf
.call .putstr0
.set r2, '.'
.call .putchar
mv r4, r0 # save x position
.set r0, dec_buf
mv r1, r5 # milliseconds
.set r2, '0'
.call .to_dec_w
mv r0, r4
.set r1, 4
.set r2, dec_buf + 2 # milliseconds are last 3 digits
.call .putstr0
 # Wait for Esc
.call .read_keyboard
.set r10, .KEY_ESC
.jmpeq r0, r10, main_menu
.jmp time_loop

# Interactive display of background/foreground/border colors
colors_menu:
$data_b " +---------------+\n"
$data_b " + f) Foreground +\n"
$data_b " + b) Background +\n"
$data_b " + o) Border     +\n"
$data_b " +---------------+\n\0"

sub_colors:
 # White on black, with black background
.set r0, .BG_BLACK | .FG_WHITE | .BLINK_OFF
.call .clear_screen
.set r0, .BG_BLACK
.set r1, .VIDEO_BORDER_ADDR
stob r1, r0
 # Show menu
.set r0, 0
.set r1, 1
.set r2, colors_menu 
.call .putstr0
 # Set colors
.set r3, 0x07 # r3 = background
.set r4, 0x00 # r4 = foreground
.set r5, 0x00 # r5 = border
set_fg_bg_bo:
    # Set foreground/background
    .set r0, 1
    mv r1, r0
    .set r10, 4
    mv r2, r4
    shl r2, r10
    or r2, r3
    loop_fg_bg:
        .call .set_attr
        inc1 r0, r0
        .set r10, 18
        .jmpltu r0, r10, loop_fg_bg
        .set r0, 1
        inc1 r1, r1
        .set r10, 6
        .jmpltu r1, r10, loop_fg_bg
    # Set border
    .set r10, .VIDEO_BORDER_ADDR
    stob r10, r5
    # Process keys
    .call .read_keyboard
    .set r10, 'f'
    .jmpne r0, r10, colors_not_f
    inc1 r4, r4
    .set r10, 0x0f
    and r4, r10
    colors_not_f: .set r10, 'b'
    .jmpne r0, r10, colors_not_b
    inc1 r3, r3
    .set r10, 0x07
    and r3, r10
    colors_not_b: .set r10, 'o'
    .jmpne r0, r10, colors_not_o
    inc1 r5, r5
    .set r10, 0x07
    and r5, r10
    colors_not_o: .set r10, .KEY_ESC
    .jmpeq r0, r10, main_menu
.jmp set_fg_bg_bo

# Halt the CPU by illegal instruction
sub_panic:
ill r0, r0
