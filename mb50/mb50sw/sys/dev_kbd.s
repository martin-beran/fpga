# Device driver for the PS/2 keyboard
# TODO: Improve receive buffer and indication of new received data.

$use constants, constants.s
$use macros, macros.s
$use stdlib, stdlib.s

# Acknowledge any unacknowledged byte received before initializing the driver
.set r10, .KBD_RXD
sto r10, r10

# Do not execute any code after this line in this file.
.jmp _skip_this_file

# The previous two bytes received from the keyboard. The default scan code set
# 2 is expected. Normally, scan codes consist of 1..3 bytes:
# 0xXX = a key pressed
# 0xf0 0xXX = a key released (corresponds to key press code 0xXX)
# 0xe0 0xXX = a key pressed
# 0xe0 0xf0 0xXX =a key released (corresponds to key press code 0xe0 0xXX)
# Some special (longer) sequences are ignored (for example, sequences for
# PrintScreen, Pause)
_scan_0: $data_b 0
_scan_1: $data_b 0

# Keyboard state.
# State of modifiers in the upper byte.
# The last entered character in the lower byte:
# - Zero means no new character received.
# - Printable ASCII characters are stored using their ASCII codes.
# - Other keys are stored as KEY_CHAR_* constants, with values 0x01..0x19 and 0x7f..0xff.
# - Keys on the numeric pad are not distinguished from the main block of keys.
# - Modifier keys are not reported as received characters. Their KEY_CHAR_*
#   constants are used only for translation from scan codes to a modifier state
#   bitmap. Modifiers are recognized by KEY_CHAR_* = 0xfX
_kbd_state: $data_w 0

$const KEY_CHAR_ESC         0x1b # ASCII ESC
$const KEY_CHAR_F1          0x81
$const KEY_CHAR_F2          0x82
$const KEY_CHAR_F3          0x83
$const KEY_CHAR_F4          0x84
$const KEY_CHAR_F5          0x85
$const KEY_CHAR_F6          0x86
$const KEY_CHAR_F7          0x87
$const KEY_CHAR_F8          0x88
$const KEY_CHAR_F9          0x89
$const KEY_CHAR_F10         0x8a
$const KEY_CHAR_F11         0x8b
$const KEY_CHAR_F12         0x8c
$const KEY_CHAR BACKSPACE   0x08 # ASCII BS
$const KEY_CHAR_TAB         0x09 # ASCII HT
$const KEY_CHAR_ENTER       0x0a # ASCII LF
$const KEY_CHAR_LEFT        0xa0
$const KEY_CHAR_RIGHT       0xa1
$const KEY_CHAR_UP          0xa2
$const KEY_CHAR_DOWN        0xa3
$const KEY_CHAR_INSERT      0xa4
$const KEY_CHAR_DELETE      0x7F
$const KEY_CHAR_HOME        0xa5
$const KEY_CHAR_END         0xa6
$const KEY_CHAR_PGUP        0xa7
$const KEY_CHAR_PGDN        0xa8

$const KEY_CHAR_SHIFT       0xf0
$const KEY_CHAR_CTRL        0xf1
$const KEY_CHAR_SHIFT       0xf2
$const KEY_CHAR_WIN         0xf3
$const KEY_CHAR_CAPS_LOCK   0xf4
$const KEY_CHAR_NUM_LOCK    0xf5
$const KEY_CHAR_SCROLL_LOCK 0xf6

# Bits for modifier keys. Left and right modifier keys are not distinguished.
$const KEY_BIT_SHIFT       0x01
$const KEY_BIT_CTRL        0x02
$const KEY_BIT_SHIFT       0x04
$const KEY_BIT_WIN         0x08
$const KEY_BIT_CAPS_LOCK   0x10
$const KEY_BIT_NUM_LOCK    0x20
$const KEY_BIT_SCROLL_LOCK 0x40

# Read the keyboard state.
# A repeated call returns 0 in r0 if no key has been pressed since the previous
# call.
# In:
# Out:
# r0 = the last entered character (printable ASCII or one of KEY_CHAR_*)
# r1 = the current state of modifier keys (a combination of KEY_BIT_*)
# Modifies: r10
read_keyboard:
.dintr r10
.set r10, _kbd_state
ld r0, r10
.set r1 0xff00
stob r10, r1 # character read, set lower byte of _kbd_state to 0
.eintr r10
and r1, r0
.set r10, 0x00ff
and r0, r10
.set r10, 8
shr r1, r10
.ret

### The keyboard interrupt handler ############################################

dev_kbd_intr_hnd:
 # Test if a byte has been received
.set r10, .KBD_READY
ldb r10, r10
.set r9, KBD_BIT_RX_RDY
and r10, r9
.retz
 # Shift received bytes and add a new one
.set r10, _scan0
.set r9, _scan1
.set0 r0
.set0 r1
.set0 r2
ldb r0, r10 # r0 = *_scan0
ldb r1, r9 # r1 = *_scan1
stob r10, r1 # *_scan0 = *_scan1
.set r10, KDB_RXD
ldb r2, r10
stob r10, r2 # Acknowledge received byte
stob r9, r2 # *_scan1 = received byte
 # Process received data (last 3 bytes in r0, r1, r2)
# TODO
.ret

### Keep this label at the end of this file ###################################

_skip_this_file:
