# Standard set of macros

### No operation ##############################################################

# An instruction that does nothing
$macro nop
    mv r0, r0
$end_macro

### Store a constant to a register ############################################

# Set a register to a constant value.
# REG = the target register
# EXPR = the value of the register
$macro set, REG, EXPR
    ldis REG, pc
    $data_w EXPR
$end_macro

# Set a register to zero
# REG = the target register
$macro set0, REG
    xor REG, REG
$end_macro

### Jumps #####################################################################

# Unconditional jump to a constant address
# ADDR = the target address
$macro jmp, ADDR
    ld pc, pc
    $data_w ADDR
$end_macro

# Do not execute any code in this file.
.jmp _skip_this_file

# Conditional jump to a constant address
# ADDR = the target address
$macro jmpf0, ADDR
    ldf0is pc, pc
    $data_w ADDR
$end_macro

$macro jmpnf0, ADDR
    ldnf0is pc, pc
    $data_w ADDR
$end_macro

$macro jmpf1, ADDR
    ldf1is pc, pc
    $data_w ADDR
$end_macro

$macro jmpnf1, ADDR
    ldnf1is pc, pc
    $data_w ADDR
$end_macro

$macro jmpf2, ADDR
    ldf2is pc, pc
    $data_w ADDR
$end_macro

$macro jmpnf2, ADDR
    ldnf2is pc, pc
    $data_w ADDR
$end_macro

$macro jmpf3, ADDR
    ldf3is pc, pc
    $data_w ADDR
$end_macro

$macro jmpnf3, ADDR
    ldnf3is pc, pc
    $data_w ADDR
$end_macro

$macro jmpz, ADDR
    ldzis pc, pc
    $data_w ADDR
$end_macro

$macro jmpnz, ADDR
    ldnzis pc, pc
    $data_w ADDR
$end_macro

$macro jmpc, ADDR
    ldcis pc, pc
    $data_w ADDR
$end_macro

$macro jmpnc, ADDR
    ldncis pc, pc
    $data_w ADDR
$end_macro

$macro jmps, ADDR
    ldsis pc, pc
    $data_w ADDR
$end_macro

$macro jmpns, ADDR
    ldnsis pc, pc
    $data_w ADDR
$end_macro

$macro jmpo, ADDR
    ldois pc, pc
    $data_w ADDR
$end_macro

$macro jmpno, ADDR
    ldnois pc, pc
    $data_w ADDR
$end_macro

### Comparisons ###############################################################

# Test if a register contains 0.
# REG = the tested register
# flag z=1 iff REG==0
$macro testz, REG
    and REG, REG
$end_macro

# Jump if REG == 0.
# REG = the tested register
# ADDR = the target address
$macro jmp0, REG, ADDR
    testz, REG
    .jmpz ADDR
$end_macro

# Jump if REG != 0.
# REG = the tested register
# ADDR = the target address
$macro jmpn0, REG, ADDR
    testz, REG
    .jmpnz ADDR
$end_macro

# Jump if REG1 == REG2.
# REG1 = first register
# REG2 = second register
# ADDR = the target address
$macro jmpeq, REG1, REG2, ADDR
    cmpu REG1, REG2
    jmpz ADDR
$end_macro

# Jump if REG1 != REG2.
# REG1 = first register
# REG2 = second register
# ADDR = the target address
$macro jmpne, REG1, REG2, ADDR
    cmpu REG1, REG2
    jmpnz ADDR
$end_macro

# Compare registers as unsigned values: < lt, <= le, > gt, >= ge
# REG1 = first register
# REG2 = second register
# ADDR = the target address
$macro jmpltu, REG1, REG2, ADDR
    cmpu REG1, REG2
    jmps ADDR
$end_macro

$macro jmpleu, REG1, REG2, ADDR
    cmpu REG1, REG2
    jmpc ADDR
$end_macro

$macro jmpgtu, REG1, REG2, ADDR
    cmpu REG2, REG1
    jmps ADDR
$end_macro

$macro jmpgeu, REG1, REG2, ADDR
    cmpu REG2, REG1
    jmpc ADDR
$end_macro

# Compare registers as signed values: < lt, <= le, > gt, >= ge
# REG1 = first register
# REG2 = second register
# ADDR = the target address
$macro jmplts, REG1, REG2, ADDR
    cmps REG1, REG2
    jmps ADDR
$end_macro

$macro jmples, REG1, REG2, ADDR
    cmps REG1, REG2
    jmpc ADDR
$end_macro

$macro jmpgts, REG1, REG2, ADDR
    cmps REG2, REG1
    jmps ADDR
$end_macro

$macro jmpges, REG1, REG2, ADDR
    cmps REG2, REG1
    jmpc ADDR
$end_macro

### Calls and returns #########################################################

# Call a subroutine at a constant address.
# The return address is stored in register ca.
# ADDR = the target address
$macro call, ADDR
    set ca, ADDR
    exch pc, ca
$end_macro

# Unconditional return from a subroutine.
# The return address is expected in register ca.
$macro ret
    mv pc, ca
$end_macro

# Conditional return from a subroutine.
# The return address is expected in register ca.
$macro retf0
    mvf0 pc, ca
$end_macro

$macro retnf0
    mvnf0 pc, ca
$end_macro

$macro retf1
    mvf1 pc, ca
$end_macro

$macro retnf1
    mvnf1 pc, ca
$end_macro

$macro retf2
    mvf2 pc, ca
$end_macro

$macro retnf2
    mvnf2 pc, ca
$end_macro

$macro retf3
    mvf3 pc, ca
$end_macro

$macro retnf3
    mvnf3 pc, ca
$end_macro

$macro retz
    mvz pc, ca
$end_macro

$macro retnz
    mvnz pc, ca
$end_macro

$macro retc
    mvc pc, ca
$end_macro

$macro retnc
    mvnc pc, ca
$end_macro

$macro rets
    mvs pc, ca
$end_macro

$macro retns
    mvns pc, ca
$end_macro

$macro reto
    mvo pc, ca
$end_macro

$macro retno
    mvno pc, ca
$end_macro

### Operations with stack #####################################################

# Push a register to the stack.
# REG = the pushed register
$macro push, REG
    ddsto sp, REG
$end_macro

# Pop a register from the stack.
# REG = the popped register
$macro pop, REG
    ldis REG, sp
$end_macro

# Save all registers to the stack.
$macro save_all
    push ca
    call _save0_10
    push r11
    push r12
    push r13
    push r14
    push r15
$end_macro

# Restore all registers from the stack.
$macro restore_all
    pop r0 # do not change pc
    pop r14
    pop r13
    pop r12
    pop r0 # do not change sp
    call _restore0_10
    pop ca
$end_macro

# Save registers to the stack.
# Macro saveN saves registers `ca` and from rN to r10.
# In order to reduce code size, saving of more than 2 general purpose registers
# is implemented by a subroutine, because a call takes 4 B, which is the same
# as 2 push (ddsto) instructions. Register `ca` must be saved before calling
# the subroutine, therefore it is always saved directly by the macro.
$macro save10
    push ca
    push r10
$end_macro

$macro save9
    push ca
    push r10
    push r9
$end_macro

$macro save8
    push ca
    call _save8_10
$end_macro

$macro save7
    push ca
    call _save7_10
$end_macro

$macro save6
    push ca
    call _save6_10
$end_macro

$macro save5
    push ca
    call _save5_10
$end_macro

$macro save4
    push ca
    call _save4_10
$end_macro

$macro save3
    push ca
    call _save3_10
$end_macro

$macro save2
    push ca
    call _save2_10
$end_macro

$macro save1
    push ca
    call _save1_10
$end_macro

$macro save0
    push ca
    call _save0_10
$end_macro

_save0_10: push r0
_save1_10: push r1
_save2_10: push r2
_save3_10: push r3
_save4_10: push r4
_save5_10: push r5
_save6_10: push r6
_save7_10: push r7
_save8_10: push r8
_save9_10: push r9
_save10_10: push r10
ret

# Restore registers from the stack.
# Macro restoreN restores registers from r10 to rN and `ca`.
$macro restore10
    pop r10
    pop ca
$end_macro

$macro restore9
    pop r9
    pop r10
    pop ca
$end_macro

$macro restore8
    call _restore8_10
    pop ca
$end_macro

$macro restore7
    call _restore7_10
    pop ca
$end_macro

$macro restore6
    call _restore6_10
    pop ca
$end_macro

$macro restore5
    call _restore5_10
    pop ca
$end_macro

$macro restore4
    call _restore4_10
    pop ca
$end_macro

$macro restore3
    call _restore3_10
    pop ca
$end_macro

$macro restore2
    call _restore2_10
    pop ca
$end_macro

$macro restore1
    call _restore1_10
    pop ca
$end_macro

$macro restore0
    call _restore0_10
    pop ca
$end_macro

_restore0_10:
pop r10
pop r9
pop r8
pop r7
pop r6
pop r5
pop r4
pop r3
pop r2
pop r1
pop r0
ret

_restore1_10:
pop r10
pop r9
pop r8
pop r7
pop r6
pop r5
pop r4
pop r3
pop r2
pop r1
ret

_restore2_10:
pop r10
pop r9
pop r8
pop r7
pop r6
pop r5
pop r4
pop r3
pop r2
ret

_restore3_10:
pop r10
pop r9
pop r8
pop r7
pop r6
pop r5
pop r4
pop r3
ret

_restore4_10:
pop r10
pop r9
pop r8
pop r7
pop r6
pop r5
pop r4
ret

_restore5_10:
pop r10
pop r9
pop r8
pop r7
pop r6
pop r5
ret

_restore6_10:
pop r10
pop r9
pop r8
pop r7
pop r6
ret

_restore7_10:
pop r10
pop r9
pop r8
pop r7
ret

_restore8_10:
pop r10
pop r9
pop r8
ret

### Keep this label at the end of this file ###################################

_skip_this_file:
