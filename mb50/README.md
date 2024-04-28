<style>
table, td, th {
    border-collapse: collapse;
    border: 1px solid;
    padding: 1ex
}
</style>

# Computer MB50

[TOC]

## Introduction

This project is an FPGA implementation of a complete computer _MB50_. It
consists of custom CPU _MB5016_, on-chip SRAM, serial control and debugging
interface, and peripherals (VGA display, PS/2 keyboard, system clock). It is
written in VHDL.

Compilation of assembler source to machine code, loading program code,
controlling program execution, and debugging is handled by development
environment _MB50DEV_, which runs on a host computer connected to the FPGA
board by a standard serial RS-232 port. The development environment is written
mainly in C++. It is developed on Linux, but should be easily portable.

This is an original design from scratch, not a reimplementation of any existing
CPU or computer.

This is a hobby project. It does not have a goal to be useful for any
production deployment. My motivation is to learn low level CPU and computer
logical design by experimenting. I have been programming various computer
systems in low level and high level languages for many years, but up to now,
I always stopped at the machine code level. I knew general principles of a CPU
and other hardware, but I have not studied them in detail. Now, I want to go
deeper into hardware and understand in detail how logic gates can be composed
into a working computer. I am interested in logical functionality of hardware,
so using an FPGA seems to be a perfect fit. I am not currently trying to learn
building physical electronic circuits nor to understand their physics and
engineering.

-------------------------------------------------------------------------------

## Design
 
### MB50 system architecture overview
 
The MB50 system consists of:

- The MB5016 CPU
- A single-level system memory (no instruction nor data caches)
- A serial control interface connected to the MB50DEV development environment
  running on a host computer
- A basic set of I/O devices (PS/2 keyboard, VGA display, system clock)

Important design criteria are clean architecture, easy implementation, and
fitting into available resources (an FPGA with only 6272 logic elements for the
whole computer), not performance optimization.

Initial estimates indicate that around 5000 LEs should be available for CPU
implementation, with the rest used for I/O devices and the serial control
interface. Common 8-bit CPUs from 1970's (e.g., MOS Technology 6502, Intel
8080, Zilog Z80) used 3000–9000 transistors, with multiple transistors needed
to create an equivalent of an FPGA logic element, hence the available FPGA
should be sufficient for this task.

The MB5016 is a 16-bit, single-core, single-thread, non-pipelined, in-order (no
instruction reordering, no speculation), scalar CPU. It contains a set of
registers, a 16-bit arithmetic-logic unit (ALU), and a hardwired control unit
(CU).

The CPU does not use microcode, because its main advantage of replacing hard
circuit design by easier (micro)programming does not apply to FPGA
implementation. To make design in (relatively high-level) VHDL and let the
synthesis tool to do the layout is much easier than developing a microcode
engine and defining the CU logic either directly in binary microcode or using
a custom-created microcode assembler.

Possible reasons for switching to microcode are:

- Desire to learn how to make a microcode engine
- Using less FPGA resources for the CU by moving parts of the logic from logic
  elements to on-chip SRAM

System memory is currently limited to the on-chip SRAM blocks. It is fast and
easy to use, but there are only 30 KiB (30720 B) available. As a possible
future improvement, a larger DRAM available on the FPGA board could be used,
maybe with using on-chip SRAM as a cache.

### CPU MB5016
 
#### Instruction Set Architecture (ISA)
 
MB5016 is a 16-bit CPU. It uses 8-bit bytes and 16-bit words. All registers
are 16 bits long. _Rationale:_ 8bit architecture would be too limiting and it
would need at least 16-bit addressing anyway. 

Little endian is used for multibyte values. _Rationale:_ Little endian is used
by common contemporary architectures: x86 and ARM. A small value stored in
multiple bytes can be read using a smaller byte length from the same address.

##### Registers

The CPU has 16 registers of size 16 bits, named `r0` ... `r15`. All registers
are equal regarding their use in instructions. _Rationale_: There should be
enough registers for use by a program, but too many registers are hard to
implement. 16 is a good number, because two arbitrary registers can be
specified by a single byte of an instruction.

Some registers have special meaning (and an alias name):

| Name | Alias | Purpose |
|:-----|:-----:|:--------|
| `r0`...`r10` | | General purpose registers |
| `r11` | `sp` | Stack Pointer (or general purpose) |
| `r12` | `ca` | Call Address (or general purpose) |
| `r13` | `ia` | Interrupt Address |
| `r14` | `f` | Flags |
| `r15` | `pc` | Program Counter |

Only registers `pc`, `f`, and `ia` have fixed special meaning. Registers `sp`
and `ca` can be used as general purpose, or any other general purpose register
can be assigned their special meaning.

- `pc` – Controls the program execution. It contains the address of the next
  instruction.
- `f` – The lower byte contains flags set by (mainly arithmetic) instructions
  and read by conditional instructions. The upper byte is used by interrupts.
- `ia` – Outside the interrupt handler, it contains the address of the
  interrupt handler. Inside the interrupt handler, it contains the return
  address. When entering or exiting the interrupt handler, contents of
  registers `ia` and `pc` are exchanged.
- `ca` – Used for call and return. Before a call, it contains a subroutine
  address. After a call, it contains the return address. During a subroutine
  call or return, contents of registers `ca` and `pc` are exchanged.
- `sp` – Used as the stack pointer

All registers are initialized to zero upon power-up and reset.

##### Flags

Meaning of bits of register `f`:

| Bit | Name | Meaning | Description |
|----:|:----:|:-------:|:------------|
| 0 | `f0` | User-defined | A program can store any condition here |
| 1 | `f1` | User-defined | A program can store any condition here |
| 2 | `f2` | User-defined | A program can store any condition here |
| 3 | `f3` | User-defined | A program can store any condition here |
| 4 | `z` | Zero | The result is: 1 = zero, 0 = nonzero |
| 5 | `c` | Carry | Carry (or borrow) from the highest bit |
| 6 | `s` | Sign | Sign of a result (0 = zero or positive, 1 = negative) |
| 7 | `o` | Overflow | Arithmetic overflow |
| 8 | `ie` | Interrupts enabled | Enables (1) or disables (0) interrupts |
| 9 | `trap` | Trap | An exception generated by the CPU |
|10 | `iclk` | System clock interrupt | Pending interrupt from system clock | 
|11 | `ikbd` | Keyboard interrupt | Pending interrupt from the keyboard |
|12 | `ir12` | Reserved | Reserved for future devices |
|13 | `ir13` | Reserved | Reserved for future devices |
|14 | `ir14` | Reserved | Reserved for future devices |
|15 | `ir15` | Reserved | Reserved for future devices |

- Values of individual flags are unchanged unless it is explicitly specified
  that an instruction modifies some flags.
- The Carry flag is also used in shifts and rotations to store the highest bit
  (in left shift or rotation) or lowest bit (in right shift or rotation).

##### Instructions

All instructions have a common format. Each instruction has 16 bits. Lower
8 bits contain the opcode. Higher 8 bits contain the numbers of a destination
(`DSTR`) and a source (`SRCR`) register.

    +--------+--------+----------------+
    |1 1 1 1 |1 1 0 0 |0 0 0 0 0 0 0 0 | Bits
    |5 4 3 2 |1 0 9 8 |7 6 5 4 3 2 1 0 |
    +--------+--------+----------------+
    |  DSTR  |  SRCR  |     OPCODE     | Meaning
    +--------+--------+----------------+

- Instruction mnemonics are written as:
    
    op dstr, srcr

- Any register `r0`–`r15` may be used as the destination and the source in
  every instruction.
- Ordering of instruction bits is chosen so that if memory content is viewed as
  hexadecimal bytes, an instruction is displayed as 4 digits `OP DS`, that is,
  `OPCODE DSTR, SRCR`.
- During program execution, an instruction is read from the address stored in
  register `pc`. When the instruction execution starts, register `pc` is
  already incremented by 2 and contains the address after the instruction.

Groups of instructions:

- _No-op_ – A dedicated no-op instruction is not needed, because there are
  already several istructions that do nothing, for example, a move or exchange
  with the same source and destination register.
- _Move_ – Copy value from the source to the destination register.
- _Exchange_ – Exchange values of the source and the destination register
- _Load_
    - Simple: Read the value at the memory address stored in the source
      register and put it into the destination register.
    - Complex (load and increment source): Like simple, but then increment the
      source register by the number of bytes read. This is intended for loading
      a constant contained in the program immediately after the load
      instruction. The source register is `pc`, which must be incremented to
      skip to the next instruction. If the source register is `sp`, it pops
      a value from the stack.
- _Store_
    - Simple: Write the source register to the memory address stored in the
      destination register.
    - Complex (store and decrement destination): Like simple, but then
      decrement the destination register by the number of bytes written. If the
      destination register is `sp`, it pushes a value to the stack.
- _Arithmetic_ – Various computations performed by the ALU.
    - Unary operations use the source register as the operand
    - Binary operations use the destination register as the first and the
      source register as the second operand.
    - Output is stored in the destination register.
    - Some operations produce two outputs, the first stored in the destination,
      the second in the source register. For example, division producing
      a quotient and a remainder.
    - An operation may change some flags (bits of register `f`).
- _Conditional_ – One of two possible operations (one can be no-op) is selected
  according to content of register `f`.
- _Special_ – Perform operations with special purposes that do not fit to other
  groups. Examples:
    - "exchange and enable interrupts", used to return from an interrupt
      handler

##### Jumps and calls

- A jump to an address in a register is implemented by a move with destination
  register `pc`.
- A jump to an address stored in memory is implemented by a load with
  destination register `pc`.
- A jump to an address stored after the jump instruction in the program is
  implemented by a load with both source and destination register `pc`.
- A call is implemented by first storing the subroutine address in register
  `ca` and an exchange of registers `pc` and `ca`. Note that when the exchange
  is executed, `pc` already contains the address of the next instruction.
- A return from subroutine is implemented by an exchange of registers `pc` and
  `ca`.
- If more than one level of subroutine calls is needed, register `ca` can be
  pushed to the stack by a "store and decrement destination" with source `ca`
  and destination `sp`. Then nested subroutine call is executed and after it
  returns, before the return from the current subroutine, `ca` is popped from
  the stack by a "load and increment source" with source `sp` and destination
  `ca`.
- _Optional_: There can be additional instructions for doing calls and returns
  that would otherwise require several instructions. For example:
    - A call to an address stored in memory = "load (to `ca`) and exchange
      (with `pc`)"
    - A call using stack = "exchange (`ca`, `pc`), store (`sp`, `ca`), and
      decrement destination (`sp`)"
    - A combination of the previous two
    - A return using stack = "load (`ca`, `sp`), increment source (`sp`), and
      exchange (`pc`, `ca`)"

##### Conditional execution

- A conditional instruction executes one of two possible operations according
  to the value of flags, that is, the lower byte of register `f`.
- An instruction can test a single bit of flags for being 0 or 1.
- _Conditional jump, address in a register_ = move or no-op
- _Conditional jump, address in memory_ = load or no-op
- _Conditional call_ = exchange or no-op
- _Conditional mask (structured condition)_ – Started by instruction "if(TAG)"
  that tests a flag in `f`. If the condition does not hold, perform no-op
  instead of following instructions until instruction "else(TAG)" or
  "endif(TAG)" is executed, with the same TAG. Instruction "else" switches
  between executing instructions normally and doing no-ops. Instructions
  "endif" starts executing instructions normally. These instructions implement
  "if...endif" and "if...else...endif" blocks without using conditional jump.
  Using different TAGs permits nested "if" blocks.

##### Interrupts

- An interrupt is generated by the CPU (a trap), by an I/O device, or by
  setting a bit 9–15 of register `f` (a software interrupt).
- An interrupt sets the appropriate bit 9–15 of register `f`according to the
  interrupt source.
- After each instruction, if interrupts are enabled (bit `ie` of `f` is 1),
  bits 9–15 of `f` are tested. If at least one bit is 1 then interrupts are
  disabled (`ie` is set to 0) and the interrupt handler is called by exchanging
  registers `ia` and `pc`.
- When interrupts are disabled (bit `ie` is 0), e.g., during execution of an
  interrupt handler, pending interrupt are recorded in the respective bits of
  `f`.
- Return from the interrupt handler is performed by a special instruction that
  atomically sets `ie` to 1 and exchanges `ia` and `pc`.
- The interrupt handler must clear bits corresponding to handled interrupts.
- If an interrupt bit in `f` remains set when returning from the handler, the
  handler is called immediately again, without executing any instructions of
  the interrupted program.

#### External signals and buses

**TODO**

Control registers of I/O device controllers are mapped into memory. In
addition, a device controller can generate interrupts and set its assigned bit
in the high byte of register `f`.

#### Microarchitecture
 
**TODO**

### Memory
 
Memory is implemented by FPGA on-chip SRAM memory blocks. The memory has 16-bit
address bus and 8-bit data bus. The memory is dual-port, that is, it uses two
independent address and data buses and control signals. Both ports can be
accessed simultaneously. One port is read/write and is used by the CPU and the
control interface. The second port is read only and is used by the display
controller to obtain framebuffer data.

It is possible to configure the system so that writing by the CPU to an
interval of addresses is prohibited, effectively making it a ROM.

### Serial control interface
 
**TODO**

### VGA display
 
The display controller implements a VGA interface with resolution 640x480
pixels at 60 Hz with 1 bit per color channel. To the rest of the system, the
display controller provides a framebuffer with resolution 256x192 and 8 colors. 
Each logical pixel is displayed as 2x2 VGA pixels, taking 512x384 VGA pixels.
The remaining area of the VGA screen is assigned a single color.

The screen output is performed by direct writing to video memory. It starts
at the address defined by system parameter `VIDEO_ADDR`. It is organized in
a manner similar to ZX Spectrum, with some differences. _Rationale_: The chosen
resolution provides basic graphic capabilities while relatively small amount of
memory. Splitting video data into a bitmap and attributes provides a basic
color support with only 1/8 additional bit per pixel (1 B for 64 pixels). The
whole video memory fits into less than 7 KiB of memory.

First 32 x 192 = 6144 B of video memory is a bitmap setting individual pixels
to a background (0) or a foreground (1) color. Bytes of memory are ordered line
by line from the top to the bottom, and left to right in each line. Every byte
controls 8 pixels, with the least significant bit controlling the leftmost
pixel.

The following 32 x 24 = 768 B set attributes, that is, a background and
a foreground color and optional blinking (periodic exchange of background and
foreground colors) of a block of 8x8 pixels. Each of RGB channels is controlled
by one bit. A single attribute byte is:

    +-----+-----+-----+-----+-----+-----+-----+-----+
    |  7  |  6  |  5  |  4  |  3  |  2  |  1  |  0  |
    +-----+-----+-----+-----+-----+-----+-----+-----+
    |  b  |  R  |  G  |  B  |  0  |  R  |  G  |  B  |
    +-----+-----+-----+-----+-----+-----+-----+-----+
    |blink|    fg color     |        bg color       |
    +-----+-----------------+-----------------------+

Then, a single byte sets the border color:

    +-----+-----+-----+-----+-----+-----+-----+-----+
    |  7  |  6  |  5  |  4  |  3  |  2  |  1  |  0  |
    +-----+-----+-----+-----+-----+-----+-----+-----+
    |  0  |  0  |  0  |  0  |  0  |  R  |  G  |  B  |
    +-----+-----+-----+-----+-----+-----+-----+-----+

The final byte of the video memory defines the blinking period for pixels with
bit `b` set to 1 in their attributes. Value 0 disables blinking. Values 1–255
set the number of frames displayed between exchanges of background and
foreground colors. With 60 frames/s, it sets the blinking half-period between
17 ms and 4.25 s.

The controller reads each bitmap, attribute, and border color byte every time
they are needed to display a pixel. This allows creating of various effects, for
example, periodic changes of the border color can create border stripes (like
the tape loader effect known from ZX Spectrum).

### PS/2 keyboard
 
The keyboard controller implements the standard PS/2 keyboard interface. It
provides receiving and sending individual bytes from/to the keyboard. Send and
receive registers are mapped into memory at address specified by system
parameter `KBD_ADDR`. After receiving or sending a byte, bit `ikbd` is set in
register `f` and an interrupt is generated.

**TODO** Define control registers.

### System clock
 
The system clock is a cyclic 16-bit counter starting at zero, incremented
with frequency specified by system parameter `HZ`, and mapped to address
`CLK_ADDR`. After each increment, bit `iclk` is set in register `f` and an
interrupt is generated.

Using a counter in addition to an interrupt ensures that clock ticks are not
missed if some interrupts are lost. For correct timekeeping, it is sufficient
to handle at least one interrupt during each full period of the counter, which
is 655.36 s (almost 11 minutes) with the default system clock frequency 100 Hz.

### Development environment MB50DEV
 
**TODO**

#### Debugger
 
**TODO**

#### Assembler
 
**TODO**

-------------------------------------------------------------------------------

## Instruction set

**TODO**

-------------------------------------------------------------------------------

## System parameters

The following table summarizes values of various parameters and constants.

| Name | Value | Description |
| :----: | ----: | :----------- |
| `CPU_HZ` | `50000000` | CPU clock frequency in Hz |
| `HZ` | `100` | System clock frequency in Hz |
| `CLK_ADDR` | `???` | Address of the system clock counter register |
| `KBD_ADDR` | `???` | Address of the first keyboard controller register |
| `MEM_SZ` | `30000` | Memory size in bytes |
| `VIDEO_ADDR` | `???` | Video RAM start address |

**TODO**: Specify all parameters

-------------------------------------------------------------------------------

## Assembler reference

**TODO**

### Invocation

**TODO**

### Syntax

**TODO**

### Output

**TODO**

### Directives

**TODO**

-------------------------------------------------------------------------------

## Debugger reference

**TODO**

### Invocation

**TODO**

### Commands

**TODO**

-------------------------------------------------------------------------------

## Building the system from source code

These instructions assume using the specific FPGA development board described
in the top-level [README.md](../README.md) of this Git repository and Intel
Quartus Prime development suite for the FPGA part. For building and running the
development environment, recent GCC or Clang on Linux is expected. Porting to
other FPGAs, operating systems, or compilers should be a relatively easy task.

### Building MB50

**TODO**

### Building MB50DEV

**TODO**

-------------------------------------------------------------------------------

## ToDo

- [x] Project structure
    - [x] Structure of documentation
    - [x] Directory structure
- [ ] Building instructions
    - [ ] MB50 system
    - [ ] MB50DEV development environment
- [ ] Design
    - [x] Specify overall system design including rationale
    - [ ] Specify CPU ISA
        - [x] Define the register set
        - [x] Define program execution, including CPU initialization, reset, and
          interrupt handling
        - [ ] Define individual instructions (name, operands, description,
          mnemonic, detailed semantics)
    - [ ] Specify external signals and buses of the CPU, including memory, I/O
      devices, and control/debugging interfaces
    - [ ] Design the CPU microarchitecture
        - [ ] Control Unit (CU)
        - [ ] Arithmetic-Logic Unit (ALU)
        - [ ] Registers (architectural and microarchitectural)
        - [ ] Internal interconnection of CPU parts and external interfaces
- [ ] Implementation
    - [ ] On FPGA
        - [ ] CPU
        - [ ] Memory
        - [ ] Serial control interface
        - [ ] VGA display
        - [ ] PS/2 keyboard
        - [ ] System clock
    - [ ] Development environment for a host computer
        - [ ] Debugger
            - [ ] Serial communication with the target computer
            - [ ] CLI
        - [ ] Assembler
            - [ ] Generic processing
            - [ ] Instruction set

-------------------------------------------------------------------------------

## Author

Martin Beran

<martin@mber.cz>

This project was started in April 2024.
