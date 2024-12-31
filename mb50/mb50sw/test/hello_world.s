# A classical "Hello World!" program

$use init, ../sys/init.s
$use char_out, ../sys/char_out.s

# Addresses in video RAM
$const VIDEO_ADDR, 0x5a00
$const ATTR_ADDR, VIDEO_ADDR + 32 * 192

# String to display
hello: $data_b "Hello World!\0"

# Main program entry point
main:
 # Set black on white
ldis r0, pc
$data_w 32 * 24 # number of attribute bytes
ldis r1, pc
$data_w 0x07 # fg=black, bg=white
ldis r2, pc
$data_w ATTR_ADDR # pointer to attribute memory
attr_loop:
    and r0, r0
    ldzis pc, pc
    $data_w attr_end
    stob r2, r1
    inc1 r2, r2
    dec1 r0, r0
    ld pc, pc
    $data_w attr_loop
attr_end:

 # Write string
ldis r0, pc # r0 = address of current character
$data_w hello
ldis r1, pc # r1 = current position in video RAM
$data_w VIDEO_ADDR
char_loop:
    xor r2, r2
    ldb r2, r0 # r2 = current character
    and r2, r2
    ldzis pc, pc
    $data_w char_end
    # display character
    ldis r3, pc # r3 = tmp
    $data_w 0x0020
    sub r2, r3
    ldis r3, pc
    $data_w 3
    shl r2, r3
    ldis r3, pc
    $data_w char_out.ascii_0x20
    add r2, r3 # r2 = address of first byte of character bitmap
    mv r4, r1 # r4 = target address
    ldis r5, pc # r5 = number of pixel lines in character
    $data_w 8
    pixel_loop:
        ldb r6, r2
        rev r6, r6
        ldis r3, pc
        $data_w 8
        shr r6, r3
        stob r4, r6
        inc1 r2, r2
        ldis r3, pc
        $data_w 32
        add r4, r3
        dec1 r5, r5
        ldnzis pc, pc
        $data_w pixel_loop
    # next character
    inc1 r0, r0
    inc1 r1, r1
    ld pc, pc
    $data_w char_loop
char_end:

# End of program
ill r0, r0 # halt
