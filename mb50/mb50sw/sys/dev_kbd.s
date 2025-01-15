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
# - Other keys are stored as KEY_* constants, with values 0x01..0x19 and 0x7f..0xff.
# - Keys on the numeric pad are not distinguished from the main block of keys.
# - Modifier keys are not reported as received characters. Their KEY_*
#   constants are used only for translation from scan codes to a modifier state
#   bitmap. Modifiers are recognized by KEY_* = 0xfX (0b1111_00XY non-locks,
#   0b1111_01XY locks)
_kbd_state: $data_w 0

$const KEY_ESC    0x1b # ASCII ESC
$const KEY_F1     0x81
$const KEY_F2     0x82
$const KEY_F3     0x83
$const KEY_F4     0x84
$const KEY_F5     0x85
$const KEY_F6     0x86
$const KEY_F7     0x87
$const KEY_F8     0x88
$const KEY_F9     0x89
$const KEY_F10    0x8a
$const KEY_F11    0x8b
$const KEY_F12    0x8c
$const KEY_BS     0x08 # ASCII BS (backspace)
$const KEY_TAB    0x09 # ASCII HT (horizontal tab)
$const KEY_ENTER  0x0a # ASCII LF ('\n', not CR '\r')
$const KEY_LEFT   0xa0
$const KEY_RIGHT  0xa1
$const KEY_UP     0xa2
$const KEY_DOWN   0xa3
$const KEY_INSERT 0xa4
$const KEY_DELETE 0x7f
$const KEY_HOME   0xa5
$const KEY_END    0xa6
$const KEY_PGUP   0xa7
$const KEY_PGDN   0xa8

$const KEY_SHIFT  0xf0
$const KEY_CTRL   0xf1
$const KEY_ALT    0xf2
$const KEY_WIN    0xf3
$const KEY_CAPS   0xf4 # CapsLock
$const KEY_NUM    0xf5 # NumLock
$const KEY_SCROLL 0xf6 # ScrollLock

# Bits for modifier keys. Left and right modifier keys are not distinguished.
$const KEY_BIT_SHIFT       0x01
$const KEY_BIT_CTRL        0x02
$const KEY_BIT_ALT         0x04
$const KEY_BIT_WIN         0x08
$const KEY_BIT_CAPS_LOCK   0x10
$const KEY_BIT_NUM_LOCK    0x20
$const KEY_BIT_SCROLL_LOCK 0x40

# Conversion table from single-byte (basic) scan codes to KEY_* constants (0=unused code)
#               X0          X1          X2          X3          X4          X5          X6          X7
#               X8          X9          Xa          Xb          Xc          Xd          Xe          Xf
_scan_codes:
$data_b          0,     KEY_F9,          0,     KEY_F5,     KEY_F3,     KEY_F1,     KEY_F2,    KEY_F12, # 00
$data_b          0,    KEY_F10,     KEY_F8,     KEY_F6,     KEY_F4,    KEY_TAB,        '`',          0, # 08
$data_b          0,    KEY_ALT,  KEY_SHIFT,          0,   KEY_CTRL,        'q',        '1',          0, # 10
$data_b          0,          0,        'z',        's',        'a',        'w',        '2',          0, # 18
$data_b          0,        'c',        'x',        'd',        'e',        '4',        '3',          0, # 20
$data_b          0,        ' ',        'v',        'f',        't',        'r',        '5',          0, # 28
$data_b          0,        'n',        'b',        'h',        'g',        'y',        '6',          0, # 30
$data_b          0,          0,        'm',        'j',        'u',        '7',        '8',          0, # 38
$data_b          0,        ',',        'k',        'i',        'o',        '0',        '9',          0, # 40
$data_b          0,        '.',        '/',        'l',        ';',        'p',        '-',          0, # 48
$data_b          0,          0,       '\'',          0,        '[',        '=',          0,          0, # 50
$data_b   KEY_CAPS,  KEY_SHIFT,  KEY_ENTER,        ']',          0,       '\\',          0,          0, # 58
$data_b          0,          0,          0,          0,          0,          0,     KEY_BS,          0, # 60
$data_b          0,        '1',          0,        '4',        '7',          0,          0,          0, # 68
$data_b        '0',        '.',        '2',        '5',        '6',        '8',    KEY_ESC,    KEY_NUM, # 70
$data_b    KEY_F11,        '+',        '3',        '-',        '*',        '9', KEY_SCROLL,          0, # 78
$data_b          0,          0,          0,     KEY_F7,          0,          0,          0,          0, # 80
_scan_codes_end:

# Conversion table from extended (prefixed by 0xe0) scan codes to KEY_* constants (0=unused code)
#               X0          X1          X2          X3          X4          X5          X6          X7
#               X8          X9          Xa          Xb          Xc          Xd          Xe          Xf
_scan_codes_e0:
$data_b          0,          0,          0,          0,          0,          0,          0,          0, # 00
$data_b          0,          0,          0,          0,          0,          0,          0,          0, # 08
$data_b          0,    KEY_ALT,          0,          0,   KEY_CTRL,          0,          0,          0, # 10
$data_b          0,          0,          0,          0,          0,          0,          0,    KEY_WIN, # 18
$data_b          0,          0,          0,          0,          0,          0,          0,    KEY_WIN, # 20
$data_b          0,          0,          0,          0,          0,          0,          0,          0, # 28
$data_b          0,          0,          0,          0,          0,          0,          0,          0, # 30
$data_b          0,          0,          0,          0,          0,          0,          0,          0, # 38
$data_b          0,          0,          0,          0,          0,          0,          0,          0, # 40
$data_b          0,          0,        '/',          0,          0,          0,          0,          0, # 48
$data_b          0,          0,          0,          0,          0,          0,          0,          0, # 50
$data_b          0,          0,  KEY_ENTER,          0,          0,          0,          0,          0, # 58
$data_b          0,          0,          0,          0,          0,          0,          0,          0, # 60
$data_b          0,    KEY_END,          0,   KEY_LEFT,   KEY_HOME,          0,          0,          0, # 68
$data_b KEY_INSERT, KEY_DELETE,   KEY_DOWN,          0,  KEY_RIGHT,     KEY_UP,          0,          0, # 70
$data_b          0,          0,   KEY_PGDN,          0,          0,   KEY_PGUP,          0,          0, # 78
_scan_codes_e0_end:

# Conversion table for scan codes of in the interval used by numeric keypad without NumLock
#               X0          X1          X2          X3          X4          X5          X6          X7
#               X8          X9          Xa          Xb          Xc          Xd          Xe          Xf
_kp_codes:
$data_b          0,    KEY_END,          0,   KEY_LEFT,   KEY_HOME,          0,          0,          0, # 68
$data_b KEY_INSERT, KEY_DELETE,   KEY_DOWN,          0,  KEY_RIGHT,     KEY_UP,    KEY_ESC,    KEY_NUM, # 70
$data_b    KEY_F11,        '+',   KEY_PGDN,        '-',        '*',   KEY_PGDN, KEY_SCROLL,          0, # 78
_kp_codes_end:

# Conversion table to keys with Shift
#               X0          X1          X2          X3          X4          X5          X6          X7
#               X8          X9          Xa          Xb          Xc          Xd          Xe          Xf
_shift_codes:
$data_b          0,          0,          0,          0,          0,          0,          0,        '"', # 20
$data_b          0,          0,          0,          0,        '<',        '_',        '>',        '?', # 28
$data_b        ')',        '!',        '@',        '#',        '$',        '%',        '^',        '&', # 30
$data_b        '*',        '(',          0,        ':',          0,        '+',          0,          0, # 38
$data_b          0,          0,          0,          0,          0,          0,          0,          0, # 40
$data_b          0,          0,          0,          0,          0,          0,          0,          0, # 48
$data_b          0,          0,          0,          0,          0,          0,          0,          0, # 50
$data_b          0,          0,          0,        '{',        '|',        '}',          0,          0, # 58
$data_b        '~',        'A',        'B',        'C',        'D',        'E',        'F',        'G', # 60
$data_b        'H',        'I',        'J',        'K',        'L',        'M',        'N',        'O', # 68
$data_b        'P',        'Q',        'R',        'S',        'T',        'U',        'V',        'W', # 70
$data_b        'X',        'Y',        'Z',          0,          0,          0,          0,          0, # 78
_shift_codes_end:

# Read the keyboard state.
# A repeated call returns 0 in r0 if no key has been pressed since the previous
# call.
# In:
# Out:
# r0 = the last entered character (printable ASCII or one of KEY_*, or 0 if no key pressed)
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
# Received data (last 3 bytes in r0, r1, r2)
# r0 r1 r2
# XX YY SC = basic key with scan code 0xSC pressed (YY != 0xf0, 0xe0)
# XX f0 SC = basic key with scan code 0xSC released (XX != 0xe0)
# XX e0 SC = extended key with scan code 0xSC pressed
# e0 f0 SC = extended key with scan code 0xSC released
 # Process received data
.set r10, ~(.FLAG_BIT_F0 | .FLAG_BIT_F1 | .FLAG_BIT_F2 | .FLAG_BIT_F3)
and f, r10 # clear f0, f1, f2, f3
.set r10, 0xf0
.set r9, 0xe0
.jmpne r1, r9, _not_e0
    .set r8, .FLAG_BIT_F0 # r1 == 0xe0
    or f, r8 # f0 = extended key
_not_e0:
.jmpne r1, r10, _not_f0
    .set r7, .FLAG_BIT_F1 # r1 == 0xf0
    or f, r7 # f1 = key released
    .jmpne r0, r9, _not_f0
        or f, r8 # r0 == 0xe0, f0 = extended key
_not_f0:
 # r2 == basic or extended scan code
.set r10, 0x80
.jmplt r2, r10, _is_key
    # TODO: handle sending LED states
    .ret
_is_key:
.set0 r0
.jmpnf0 _basic
    # extended key
    .set r10, _scan_codes_e0
    add r2, r10
    ldb r0, r2 # r0 = char = _scan_codes_e0[scan_code]
    .jmp _basic_end
_basic:
    # basic key
    .lda r10, _kbd_state
    .set r9, KEY_BIT_SHIFT
    and r9, r10
    .set r8, KEY_BIT_NUM_LOCK
    and r10, r8
    .set r8, 5
    shr r10, r8
    xor r10, r9 # r10 = SHIFT xor NUM_LOCK
    .jmpnz _kp_numbers
    .set r10, 0x68
    .jmplt r2, r10, _kp_numbers
    .set r10, 0x80
    .jmpge r2, r10, _kp_numbers
        # keypad not numbers (arrows)
        .set r10, _kp_codes - 0x68
        add r2, r10
        ldb r0, r2 # r0 = char = _kp_codes[scan_code]
        .jmp _basic_end
    _kp_numbers:
        .set r10, _scan_codes
        add r2, r10
        ldb r0, r2 # r0 = char = _scan_codes[scan_code]
_basic_end:
 # r0 == char
.lda r10, _kbd_state
.set r9, KEY_BIT_SHIFT
and r9, r10
.set r8, KEY_BIT_CAPS_LOCK
and r10, r8
.set r8, 4
shr r10, r8
xor r10, r9 # r10 = SHIFT xor CAPS_LOCK
.jmpz _not_shift
.set r10, 0x20
.jmplt r0, r10, _not_shift
.set r10, 0x80
.jmpge r0, r10, _not_shift
    .set r10, _shift_codes - 0x20
    add r0, r10
    ldb r0, r0 # r0 = shifted char
not_shift:
 # r0 == optionally shifted char
.set0 r1
.set r10, _kbd_state + 1 # r10 = &modifiers
ld r1, r10 # r1 = current state of modifiers
mv r2, r1 # r2 = new state of modifiers
.jmpf1 _released
    # Key pressed
    .set r9, _kbd_state
    stob r9, r0 # store pressed key
    # Handle non-lock modifiers
    .set r9, KEY_SHIFT
    .jmpne r0, r9, _not_mod_shift
        .set r9, KEY_BIT_SHIFT
        or r2, r9
    _not_mod_shift: set r9, KEY_CTRL
    .jmpne r0, r9, _not_mod_ctrl
        .set r9, KEY_BIT_CTRL
        or r2, r9
    _not_mod_ctrl: set r9, KEY_ALT
    .jmpne r0, r9, _not_mod_alt
        .set r9, KEY_BIT_ALT
        or r2, r9
    _not_mod_alt: set r9, KEY_WIN
    .jmpne r0, r9, _not_mod_win
        .set r9, KEY_BIT_WIN
        or r2, r9
    # Handle lock modifiers
    _not_mod_win: set r9, KEY_CAPS
    .jmpne r0, r9, _not_mod_caps
        .set r9, KEY_BIT_CAPS_LOCK
        xor r2, r9
    _not_mod_caps: set r9, KEY_NUM
    .jmpne r0, r9, _not_mod_num
        .set r9, KEY_BIT_NUM_LOCK
        xor r2, r9
    _not_mod_num: set r9, KEY_SCROLL
    .jmpne r0, r9, _released_end
        .set r9, KEY_BIT_SCROLL_LOCK
        xor r2, r9
_released:
    # Key released, handle non-lock modifiers
    .set r9, KEY_SHIFT
    .jmpne r0, r9, _not_rel_shift
        .set r9, ~KEY_BIT_SHIFT
        and r2, r9
    _not_rel_shift: set r9, KEY_CTRL
    .jmpne r0, r9, _not_rel_ctrl
        .set r9, ~KEY_BIT_CTRL
        and r2, r9
    _not_rel_ctrl: set r9, KEY_ALT
    .jmpne r0, r9, _not_rel_alt
        .set r9, ~KEY_BIT_ALT
        and r2, r9
    _not_rel_alt: set r9, KEY_WIN
    .jmpne r0, r9, _released_end
        .set r9, ~KEY_BIT_WIN
        and r2, r9
_released_end:
stob r10, r2 # *&modifiers = new state of modifiers
.set r10, KEY_BIT_CAPS_LOCK | KEY_BIT_NUM_LOCK | KEY_BIT_SCROLL_LOCK
and r1, r10
and r2, r10
cmpu r1, r2
.retz
 # Lock modifiers changes, modify LEDs
# TODO
.ret

### Keep this label at the end of this file ###################################

_skip_this_file:
