# Communication with PS/2 keyboard

$use start, ../sys/start.s
$use constants, ../sys/constants.s
$use macros, ../sys/macros.s
$use stdlib, ../sys/stdlib.s

 # Wait for TxReady
$macro wait_tx
    _wait$:
    .set r10, .KBD_READY
    ldb r9, r10
    .set r8, .KBD_BIT_TX_RDY
    and r9, r8
    .jmpz _wait$
$end_macro

 # Write byte
$macro tx, BYTE
    wait_tx
    .set r10, .KBD_TXD
    .set r9, BYTE
    sto r10, r9
$end_macro

 # Ack
$macro ack
    .set r10, .KBD_RXD
    stob r10, r10
$end_macro

 # Receive and acknowledge byte
$macro rx
    _wait$:
    .set r10, .KBD_READY
    ldb r9, r10
    .set r8, .KBD_BIT_RX_RDY
    and r9, r8
    .jmpz _wait$
    .set r10, .KBD_RXD
    .set0 r0
    ldb r0, r10
    ack
$end_macro

main:
.set sp, .STACK_BOTTOM
.set r0, .BG_WHITE | .FG_BLACK
.call .clear_screen
.set r1, 0 # Y
.set r3, 0 # X
 # Set keyboard LEDs
ack # Acknowledge any pending received byte
wait_ack: tx 0xff # Reset
#tx 0xed # Write command byte
    rx
    mv r10, r0
    mv r0, r3
    mv r2, r10
    .save10
    .call .print_byte
    mv r3, r0
    .restore10
    .set r10, 0xfa
    .jmpne r9, r10, wait_ack
tx 0x02 # Write data byte (NumLock)


