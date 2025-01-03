# Standard set of macros

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

### Tests #####################################################################

# Test if a register contains 0.
# REG = the tested register
# flag z=1 iff REG==0
$macro testz, REG
    and REG, REG
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
