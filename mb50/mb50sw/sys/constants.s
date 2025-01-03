# System parameters and other useful constants

### System parameters #########################################################

# See section "System parameters" in README.md for details.

$const ADDR_MAX,   0xffff # Maximum address
$const CLK_ADDR,   0xfff0 # Address of the system clock counter register
$const HZ,            100 # System clock frequency in Hz
$const KBD_ADDR,   0xffe0 # Address of the first keyboard controller register
$const MEM_MAX,    0x752f # Address of the last byte of memory
$const VIDEO_ADDR, 0x5a00 # Video RAM start address

### Video parameters ##########################################################

# See section "VGA display" in README.md for details.

$const VIDEO_PX_W,  256 # Horizontal resolution (width in pixels)
$const VIDEO_PX_H,  192 # Vertical resolution (height in pixels)
$const VIDEO_ATTR_W, 32 # Horizontal resolution (characters and attributes)
$const VIDEO_ATTR_H, 24 # Vertical resolution (characters and attributes)
$const VIDEO_PX_ADDR,     VIDEO_ADDR                                    # Pixels start address
$const VIDEO_ATTR_ADDR,   VIDEO_PX_ADDR + (VIDEO_PX_W * VIDEO_PX_H) / 8 # Attributes start address
$const VIDEO_BORDER_ADDR, VIDEO_ATTR_ADDR + VIDEO_ATTR_W * VIDEO_ATTR_H # Border color address
$const VIDEO_BLINK_ADDR,  VIDEO_BORDER_ADDR + 1                         # Blinking period address

# Background and border colors
$const BG_BLACK,   0b0000_0000
$const BG_RED,     0b0000_0100
$const BG_GREEN,   0b0000_0010
$const BG_BLUE,    0b0000_0001
$const BG_CYAN,    0b0000_0011
$const BG_MAGENTA, 0b0000_0101
$const BG_YELLOW,  0b0000_0110
$const BG_WHITE,   0b0000_0111

# Foreground colors
$const FG_BLACK,   0b0000_0000
$const FG_RED,     0b0100_0000
$const FG_GREEN,   0b0010_0000
$const FG_BLUE,    0b0001_0000
$const FG_CYAN,    0b0011_0000
$const FG_MAGENTA, 0b0101_0000
$const FG_YELLOW,  0b0110_0000
$const FG_WHITE,   0b0111_0000

# Blinking
$const BLINK_ON, 0b1000_0000 # enable
$const BLINK_1HZ, 30 # blinking frequency 1 Hz

### Keyboard parameters #######################################################

# See section "PS/2 keyboard" in README.md for details.

$const KBD_TXD,   KBD_ADDR     # Transmitted data
$const KBD_RXD,   KBD_ADDR + 1 # Received data
$const KBD_READY, KBD_ADDR + 2 # Received or ready to transmit data
