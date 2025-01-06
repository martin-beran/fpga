# Interrupt handling

$use constants, constants.s
$use macros, macros.s
$use stdlib, stdlib.s

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
addr_intr_hnd_exc: $data_w default_intr_hnd_exc

# Handler for interrupt bit iclk (C, system clock)
addr_intr_hnd_iclk: $data_w noop_intr_hnd

# Handler for interrupt bit ikbd (K keyboard)
addr_intr_hnd_ikbd: $data_w noop_intr_hnd

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

intr_hnd:
.save_all
_handle_intr_bit .flag_bit_exc, addr_intr_hnd_exc
_handle_intr_bit .flag_bit_iclk, addr_intr_hnd_iclk
_handle_intr_bit .flag_bit_ikbd, addr_intr_hnd_ikbd
.restore_all_intr
reti pc, pc

# A no-operation subroutine that can be used as any addr_intr_hnd_*
noop_intr_hnd:
.ret

_exc_msg: $data_b "Exception, CPU halted\0"

# Default exception handler
# It displays registers and halts the CPU. Subroutine display_registers pushes
# and pops register f, which may lose new pending interrupts, but it does not
# matter here, because the CPU is halted anyway.
default_intr_hnd_exc:
.call .display_registers
.set r0, 0
.set r1, 23
.set r2, _exc_msg
.call .putstr0
ill r0, r0 # halt

### Initialize interrupt handling #############################################

# Install the main interrupt handler
intr_init:
 # install interrupt handler
.set ia, intr_hnd
csrw csr1, ia
 # enable interrupts
.set r10, .flag_bit_ie
or f, r10
.ret

### Keep this label at the end of this file ###################################

_skip_this_file:
