# Draw a horizontal line
# The first program containing, $const, expressions, a loop and a label

# Addresses in video RAM
$const VIDEO_ADDR, 0x5a00
$const ATTR_ADDR, VIDEO_ADDR + 32 * 192
$const BORDER_ADDR, ATTR_ADDR + 32 * 24

 # set border blue
ldis r0, pc
$data_w 0x01
ldis r1, pc
$data_w BORDER_ADDR
sto r1, r0
 # iteration counter
ldis r0, pc
$data_w 32
 # pixel [0, 4]
ldis r1, pc
$data_w VIDEO_ADDR + 4 * 32
 # attribute [0, 0]
ldis r2, pc
$data_w ATTR_ADDR

loop:
    # break if r0 == 0
    and r0, r0
    ldzis pc, pc
    $data_w end
    # draw line segment (pixels)
    ldis r3, pc
    $data_w 0b0110_0110
    stob r1, r3
    # set line segment attributes
    ldis r3, pc
    $data_w 0x70
    stob r2, r3
    # next iteration
    inc1 r1, r1
    inc1 r2, r2
    dec1 r0, r0
    ld pc, pc
    $data_w loop
end:
    ill r0, r0
