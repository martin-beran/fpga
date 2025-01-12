# Interrupt handling

$use constants, constants.s
$use macros, macros.s
$use stdlib, stdlib.s
$use dev_clk, dev_clk.s
$use dev_kbd, dev_kbd.s

# Do not execute any code in this file.
.jmp _skip_this_file

### Interrupt handler #########################################################

# Addresses of subroutines called from intr_hnd for an exceptions.
# Each of these routines is called with interrupts disabled, after the
# respective pending interrupt bit is cleared in register f. It may modify any
# registers, but must not enable interrupts or clear pending interrupt bits in
# register f. This implies that push/pop pair for register f is forbidden in an
# interrupt handler.

# Handler for interrupt bit exc (E, exception)
addr_intr_hnd_iexc: $data_w 0x0000

# Handler for interrupt bit iclk (C, system clock)
addr_intr_hnd_iclk: $data_w 0x0000

# Handler for interrupt bit ikbd (K keyboard)
addr_intr_hnd_ikbd: $data_w 0x0000

# The main interrupt handler
$macro _handle_intr_bit, BIT, HANDLER
    .set r10, BIT
    and r10, f
    .jmpz _not_exc$
    xor f, r10 # clears the bit, which is 1 here
    .lda ca, HANDLER
    exch pc, ca
    _not_exc$:
$end_macro

# Variant of the interrupt handler that saves registers to the stack.
$macro _intr_hnd_stack
    intr_hnd:
    .save_all
    _handle_intr_bit .FLAG_BIT_IEXC, addr_intr_hnd_iexc
    _handle_intr_bit .FLAG_BIT_ICLK, addr_intr_hnd_iclk
    _handle_intr_bit .FLAG_BIT_IKBD, addr_intr_hnd_ikbd
    .restore_all_intr
    reti pc, pc
$end_macro

# Variant of the interrupt handler that saves registers to a fixed memory area.
$macro _intr_hnd_mem
    _intr_reg_begin: $addr _intr_reg_begin + 14 * 2
    _intr_reg_end:
    intr_hnd:
    .mem_save_all_intr _intr_reg_end
    _handle_intr_bit .FLAG_BIT_IEXC, addr_intr_hnd_iexc
    _handle_intr_bit .FLAG_BIT_ICLK, addr_intr_hnd_iclk
    _handle_intr_bit .FLAG_BIT_IKBD, addr_intr_hnd_ikbd
    .mem_restore_all_intr _intr_reg_begin
    reti pc, pc
$end_macro

# Select a variant of the interrupt handler (_intr_hnd_stack or _intr_hnd_mem)
#_intr_hnd_stack
_intr_hnd_mem

# A no-operation subroutine that can be used as any addr_intr_hnd_*
noop_intr_hnd:
.ret

_exc_msg: $data_b "Exception, CPU halted\0"

# Default exception handler
# It displays registers. Then it halts the CPU for a hardware interrupt and
# returns for a software interrupt.
default_intr_hnd_exc:
.push ca
.call .display_registers
csrr r10, csr0
.set r9, 0x0100
and r10, r9
.pop ca
.retz
.set r0, 0
.set r1, 23
.set r2, _exc_msg
.call .putstr0
ill r0, r0 # halt

### Initialize interrupt handling #############################################

# Install the main interrupt handler
intr_init:
 # install interrupt handler
.set r10, default_intr_hnd_exc
.set r9, addr_intr_hnd_iexc
sto r9, r10
.set r10, .dev_clk_intr_hnd
inc2 r9, r9
sto r9, r10
.set r10, .dev_kbd_intr_hnd
inc2 r9, r9
sto r9, r10
.set ia, intr_hnd
csrw csr1, ia
 # enable interrupts
.eintr r10
.ret

### Keep this label at the end of this file ###################################

_skip_this_file:
