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

# Set keyboard LEDs
# In:
# r0 = LED state bits: 0=ScrollLock, 1=NumLock, 2=CapsLock
# Out:
# Modifies: r0, r9, r10
kbd_set_leds:
# TODO
_wait_txr:
    .set r10, .KBD_READY
    ldb r10, r10 # upper byte ignored
    .set r9, .KBD_BIT_TX_RDY
    and r10, r9
    .jmpz _wait_txr
.set0 r10
.set r9, kbd_rx_buf
sto r9, r10
.set r9, .KBD_TXD
.set r10, 0xed
stob r9, r10
_wait_ack:
    .set0 r10
    .set r9, kbd_rx_buf
    ldb r10, r9
    .testz r10
    .jmpz _wait_ack
    .set r9, 0xfa
    .jmpne r10, r9, _wait_txr
_wait_txr1:
    .set r10, .KBD_READY
    ldb r10, r10 # upper byte ignored
    .set r9, .KBD_BIT_TX_RDY
    and r10, r9
    .jmpz _wait_txr1
.set r9, .KBD_TXD
stob r9, r0
.ret

# Buffer for the last two received bytes (lower byte = last, upper byte = previous)
kbd_rx_buf: $data_w 0

# The keyboard interrupt handler
dev_kbd_intr_hnd:
.set r10, .KBD_READY
ldb r10, r10 # upper byte ignored
.set r9, .KBD_BIT_RX_RDY
and r10, r9
.retz
.set r8, kbd_rx_buf
ld r10, r8
.set r9, 8
shl r10, r9
.set r9, .KBD_RXD
ldb r10, r9
stob r9, r10 # acknowledge
sto r8, r10
.ret

### Keep this label at the end of this file ###################################

_skip_this_file:
