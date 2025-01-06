# Device driver for the system clock
# The system clock value is kept in two unsigned words: seconds and
# milliseconds, hence it wraps around after every 18h12m16s.
# Using 16-bit raw clock value could provide correct time keeping with two
# maximum time 65535 / HZ seconds between interrupt handler calls. The current
# implementation handles correctly at most 1 s.
# TODO: Improve maximum allowed time between handler calls.

$use constants, constants.s
$use macros, macros.s
$use stdlib, stdlib.s

# Do not execute any code in this file.
.jmp _skip_this_file

# Previous value of the clock register
_dev_clk_prev: $data_w 0

# Clock value (seconds)
dev_clk_val_s: $data_w 0

# Clock value (milliseconds)
dev_clk_val_ms: $data_w 0

# The clock interrupt handler
dev_clk_intr_hnd:
.lda r10, .CLK_ADDR # r10 = current raw clock value
.set r8, _dev_clk_prev
ld r9, r8 # r9 = previous raw clock value
sto r8, r10 # store new value
sub r10, r9 # r10 = increment in 1/HZ (mod 0x10000)
.set r9, .HZ
.jmpleu r10, r9, _small_diff
mv r10, r9 # saturate at HZ (1 s)
_small_diff:
.set r9, 1000 / .HZ
muluu r10, r9 # r10 = increment in ms <= 1000
.set r9, dev_clk_val_ms # r9 = dev_clk_val_ms
ld r8, r9 # r8 = old *dev_clk_val_ms <= 999
add r10, r8 # r10 = new *dev_clk_val_ms <= 1999
.set r8, 1000
.jmpltu r10, r8, _small_ms
sub r10, r8 # new *dev_clk_val_ms -= 1000
.set r8, dev_clk_val_s # ++dev_clk_val_s
ld r7, r8
inc1 r7, r7
sto r8, r7
_small_ms: # new *dev_clk_val_ms < 1000
sto r9, r10
.ret

### Keep this label at the end of this file ###################################

_skip_this_file:
