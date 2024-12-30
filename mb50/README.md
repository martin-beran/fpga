<style>
table, td, th {
    border-collapse: collapse;
    border: 1px solid;
    padding: 1ex
}
</style>

# Computer MB50

[TOC]

Conversion of this Markdown document to HTML:

    markdown_py -x tables -x toc README.md > README.html

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

The _MB50_ system consists of:

- The _MB5016 CPU_
- A single-level system memory (no instruction nor data caches)
- A serial _control and debugging interface (CDI)_ connected to the MB50DEV
  development environment running on a host computer
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

The _MB5016_ is a 16-bit, single-core, single-thread, non-pipelined, in-order
(no instruction reordering, no speculation), scalar CPU. It contains a set of
registers, a 16-bit _arithmetic-logic unit (ALU)_, and a hardwired _control
unit (CU)_.

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

The serial control and debugging interface and I/O device controllers are
implemented in the same FPGA as the CPU and memory. All connections (signals,
buses) among these components of the system are defined as logical signals
(soft-wires) between functional units inside the FPGA, not as physical wires
among integrated circuits.

### Block schema of the system


                        +=======+   
           interrupts  ||  I/O  ||  
         +-------------+|devices||  
         |              +===+===+   
         |                  | memory mapped I/O
         |                  |
         |                  |
      +==+==+               |                +========+
     ||     ||          +===+====+          ||        ||         +=====+
     ||     |+---------+| MEMCTL |+---------+| Memory |+--------+| VGA ||
     || CPU ||          +===+====+          ||        ||         +=====+
     ||     ||              |                +========+
     ||     ||              |
      +==+==+               |
         |                  |
         |           +======+======+
         |          ||     CDI     ||
         |          ||  (Serial)   ||
         +----------+| Control and ||
                    ||  Debugging  ||
                    ||  Interface  ||
                     +=============+

Details of interconnections among system components can be changed or refined
during implementation. See also the VHDL source code.

Between CPU and memory, there is a 16-bit unidirectional address bus and an
8-bit bidirectional data bus. There are additional signals controlling reading
and writing memory.

The memory controller (MEMCTL) implements mapping of I/O device registers to
the address space, that is, routing memory read/write requests to the memory or
to the appropriate device. It also arbitrates access to the memory by the CPU
and the CDI.

The VGA controller is not directly connected to the CPU. It uses a completely
separated interface to the memory, not shared with any other system component.
This allows to display the image from the video memory continuously and
independently on the rest of the system.

Control registers of I/O device controllers are mapped into memory address
space. In addition, a device controller can generate interrupts and set its
assigned bit in the high byte of register `f`.

There is a set of control signals used to observe and control the internal
state of the CPU. They are used by the CDI to:

- Read values in registers
- Set values of registers
- Stop the CPU
- Run the CPU continuously
- Command the CPU to execute a single instruction

### CPU MB5016

#### Instruction Set Architecture (ISA)

MB5016 is a 16-bit CPU. It uses 8-bit bytes and 16-bit words. All registers
are 16 bits long. _Rationale:_ 8bit architecture would be too limiting and it
would need at least 16-bit addressing anyway.

Little endian is used for multibyte values. _Rationale:_ Little endian is used
by common contemporary architectures: x86 and ARM. A small value stored in
multiple bytes can be read using a smaller byte length from the same address.

Signed arithmetic uses two's complement representation.

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
  address. When entering the interrupt handler, contents of registers `ia` and
  `pc` are exchanged.
- `ca` – Used for call and return. Before a call, it contains a subroutine
  address. After a call, it contains the return address. During a subroutine
  call, contents of registers `ca` and `pc` are exchanged. A return is done by
  moving `ca` to `pc`.
- `sp` – Used as the stack pointer

All registers are initialized to zero upon power-up and reset. This includes
register `pc`, so the CPU starts running code at the address 0x0000.

In addition, there are 16 control and status registers (CSR), named `csr0` ...
`csr15`. They cannot be accessed directly, but there are instructions for
getting a value of a CSR into a register, or storing a value from a register to
a CSR. For each CSR, its meaning and available operations (read, write, or
both) are defined by the ISA.

##### Flags

Meaning of bits of register `f`:

| Bit | Name | Short | Meaning | Description |
|----:|:----:|:-----:|:-------:|:------------|
| 0 | `f0` | `0` | User-defined | A program can store any condition here |
| 1 | `f1` | `1` | User-defined | A program can store any condition here |
| 2 | `f2` | `2` | User-defined | A program can store any condition here |
| 3 | `f3` | `3` | User-defined | A program can store any condition here |
| 4 | `z` |  `z` | Zero | The result is: 1 = zero, 0 = nonzero |
| 5 | `c` |  `c` | Carry | Carry (or borrow) from the highest bit |
| 6 | `s` |  `s` | Sign | Sign of a result (0 = zero or positive, 1 = negative) |
| 7 | `o` |  `o` | Overflow | Arithmetic overflow |
| 8 | `ie` | `I` | Interrupts enabled | Enables (1) or disables (0) interrupts |
| 9 | `exc` | `E` | Exception | An exception generated by the CPU |
|10 | `iclk` | `C` | System clock interrupt | Pending interrupt from system clock |
|11 | `ikbd` | `K` | Keyboard interrupt | Pending interrupt from the keyboard |
|12 | `ir12` | `-` | Reserved | Reserved for future devices |
|13 | `ir13` | `-` | Reserved | Reserved for future devices |
|14 | `ir14` | `-` | Reserved | Reserved for future devices |
|15 | `ir15` | `-` | Reserved | Reserved for future devices |

- Column "Short" shows single-character bit names used in register value
  displayed by the debugger.
- Values of individual flags are unchanged unless it is explicitly specified
  that an instruction modifies some flags.
- If an instruction signals its outcome in a flag bit, it always sets the bit
  to 0 or 1, regardless of its previous value.
- User-defined flags `f0`...`f3` are never used to signal a result of an
  instruction. They are changed only by instructions having `f` as the
  destination register.
- If `f` is a destination register, any modification of flags done by the
  executed instruction is overridden by the stored value. Hence, it is possible
  to set the flags to a particular value by an arithmetic instruction that
  would otherwise set the flags to some other values depending on a calculation
  result.
- The Carry flag is also used in shifts and rotations to store the highest bit
  (in left shift or rotation) or lowest bit (in right shift or rotation).

##### Instructions

All instructions have a common format. Each instruction has 16 bits. Lower
8 bits contain the opcode. Higher 8 bits contain the numbers of a destination
(`DSTR`) and a source (`SRCR`) register.

    +---------+---------+-----------------+
    | 1 1 1 1 | 1 1 0 0 | 0 0 0 0 0 0 0 0 | Bits
    | 5 4 3 2 | 1 0 9 8 | 7 6 5 4 3 2 1 0 |
    +---------+---------+-----------------+
    |   DSTR  |   SRCR  |      OPCODE     | Meaning
    +---------+---------+-----------------+

- Instruction mnemonics are written as:

    op dstr, srcr

- Any register `r0`–`r15` may be used as the destination and the source in
  every instruction.
- _Rationale_: Ordering of instruction bits is chosen so that if memory content
  is viewed as hexadecimal bytes, an instruction is displayed as 4 digits `OP
  DS`, that is, `OPCODE DSTR, SRCR`.
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
    - Complex (decrement destination and store): Like simple, but first
      decrement the destination register by the number of bytes to be written
      written. If the destination register is `sp`, it pushes a value to the
      stack.
- _Computational (arithmetic, logic, comparison)_ – Various computations
  performed by the ALU.
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
    - "Exchange and enable interrupts", used to return from an interrupt
      handler
    - Reading and writing control and status registers
    - Illegal zero instruction – the instruction with opcode 0 causes an
      exception. _Rationale_: The opcode was chosen so that execution of
      cleared memory generates an exception.

##### Control transfer (jumps and calls)

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
    - A call to an address stored in memory after the call instruction = "load
      (to `ca`), increment source (`pc`), and exchange (`ca` with `pc`)"
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
- _Conditional jump, address after the jump instruction_ = load or increment
  `pc`
- _Optional: Conditional call, address in a register_ = exchange or no-op
- _Optional: Conditional call, address in memory after the call instruction_ =
  load, increment source (`pc`) and exchange, or increment source
- _Optional: Conditional mask (structured condition)_
    - An instruction "cond" that tests a flag in `f`. If the test fails, the
      next instruction is skipped.
    - Started by instruction "if(TAG)" that tests a flag in `f`. If the
      condition does not hold, perform no-op instead of following instructions
      until instruction "else(TAG)" or "endif(TAG)" is executed, with the same
      TAG. Instruction "else" switches between executing instructions normally
      and doing no-ops. Instructions "endif" starts executing instructions
      normally. These instructions implement "if...endif" and
      "if...else...endif" blocks without using conditional jump. Using
      different TAGs permits nested "if" blocks.
    - Note that "cond" and "if/else/endif" instructions must also skip two
      bytes following the instruction if these bytes are effectively part of
      the instruction (a load with source register `pc`).
    - _Rationale_: These instructions are proposed as experimental, with two
      potential advantages: easier assembler programming (conditional blocks
      instead of conditional jump) and not needing to flush the instruction
      pipe in a pipelined CPU implementation.

##### Interrupts and exceptions

- An exception is generated by the CPU when some error occurs (a hardware
  exception), for example, if an illegal instruction is to be executed. It can
  be also generated by storing an exception code to the lower 8 bits of
  register `csr0` and setting bit 9 of register `f` (a software exception).
- An interrupt is generated by an I/O device (a hardware interrupt), or by
  setting a bit 10–15 of register `f` (a software interrupt).
- An interrupt sets the appropriate bit 10–15 of register `f` according to the
  interrupt source.
- Before each instruction, if interrupts are enabled (bit `ie` of `f` is 1),
  bits 9–15 of `f` are tested. If at least one bit is 1 then interrupts are
  disabled (`ie` is set to 0) and the interrupt handler is called by exchanging
  registers `ia` and `pc`.
- When interrupts are disabled (bit `ie` is 0), e.g., during execution of an
  interrupt handler, pending interrupt are recorded in the respective bits of
  `f`.
- When interrupts are disabled, an exception halts the CPU, because an
  exception must be handled immediately (synchronously) and there is no way how
  to do it. A reset or clearing the exception flag (bit 9 of register `f`) via
  the CDI must be done in order to make the CPU running again.
- Return from the interrupt handler is performed by a special instruction that
  atomically sets `ie` to 1, moves `ia` to `pc`, and reads `csr1` to `ia`.
- The interrupt handler must clear bits corresponding to handled exceptions and
  interrupts.
- If an exception or interrupt bit in `f` remains set when returning from the
  handler, the handler is called immediately again, without executing any
  instructions of the interrupted program.

#### Microarchitecture

The CPU consists of several functional units:

- _Control Unit (CU)_ – A sequential logic circuit that implements a finite
  state machine. It reads instructions from memory, decodes, and executes them.
- _Arithmetic-Logic Unit (ALU)_ – A combinatorial logic circuit that implements
  computations peformed by instructions. It is used also for operations like
  moving and exchanging data between registers or address computation. It also
  handles communication between the CPU and the CDI. If needed, ALU may contain
  some internal registers and sequential logic for operations that need
  multiple clock cycles for completion.
- _Register array_ — The array of 16 registers `r0`...`r15`. It is connected by
  multiplexers to the inputs and outputs of the ALU in order to use registers
  for operands and result of operations performed by the ALU. Special-purpose
  registers (`ia`, `f`, `pc`) can be also connected directly to the CU.
- _Array of CSRs_ – The array of 16 control and status registers
  `csr0`...`csr15`. It is connected by multiplexers to the inputs and outputs
  of the ALU in order to move data between normal registers and CSRs. Some bits
  or whole CSR0 are connected to the CU, because they are used to indicate or
  control the CPU state.

When the CPU is stopped, the CU waits until the CDI requests starting the CPU
in single-step or continuous program execution. During normal execution, the CU
continuously reads instructions from the memory and executes them. The
single-stepping mode is similar, but the CPU is stopped after executing one
instruction. Instruction processing:

1. The first byte (opcode) of an instruction is read from the memory.
1. The second byte (destination and source registers) of an instruction is read
   from the memory.
1. Register `pc` is incremented to point after the instruction.
1. An ALU function is selected based on the opcode.
1. The source and destination registers are connected to the ALU inputs and
   outputs.
1. The ALU performs the selected operation, stores a result into the
   destination register, and updates flags.
1. If the current instruction is a load or a store, a byte or a word is read
   from or written to the memory.
1. If the current instruction is a read or a write of a CSR, a value is copied
   as requested.

Speed of execution can be increased by optionally implementing a limited form
of pipelining:

- The read of the second byte of an instruction can be initiated when waiting
  for the memory to deliver the first byte.
- Similarly, any other multi-byte read or write can be made faster by sending
  the address of the next byte to the memory while waiting for the transfer of
  the current byte to be completed.
- The next two bytes after the instruction can be prefetched. They could be the
  next istruction (unless a control transfer is performed by the current
  instruction), or they can contain a value to be loaded to a register (if the
  current instruction is a load).

There is no memory cache in the CPU.

### Memory

Memory is implemented by FPGA on-chip SRAM memory blocks. The memory has 16-bit
address bus and 8-bit data bus. The memory is dual-port, that is, it uses two
independent address and data buses and control signals. Both ports can be
accessed simultaneously. One port is read/write and is used by the CPU and the
CDI. The second port is read only and is used by the display controller to
obtain framebuffer data.

It is possible to configure the system so that writing by the CPU to an
interval of addresses is prohibited, effectively making it a ROM.

### Control and Debugging Interface (CDI)

The serial control and debugging interface is connected to a host computer via
the RS-232 serial port with fixed settings: 115200 baud, 8-N-1 (8 data bits, no
parity, one stop bit). It converts control commands received from the serial
port to signals controlling system operation. In the opposite direction, it
sends information about an internal system state (e.g., contents of registers
and memory) to the serial port.

The serial protocol used between the CDI and the debugger running on a host
computer is considered an implementation detail defined only by the source
code of the CDI (in VHDL) and the debugger (in C++).

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

Device control registers:

| Name | Operations | Address | Purpose |
|:----:|:----------:|:-------:|:--------|
| `TXD` | write | `KBD_ADDR + 0` | Transmitted data |
| `RXD` | read/write | `KBD_ADDR + 1` | Received data |
| `READY` | read | `KBD_ADDR + 2` | Received or ready to transmit data |

Bits of register `READY`:

    +-----+-----+-----+-----+-----+-----+-----+-----+
    |  7  |  6  |  5  |  4  |  3  |  2  |  1  |  0  |
    +-----+-----+-----+-----+-----+-----+-----+-----+
    |  0  |  0  |  0  |  0  |  0  |  0  |  T  |  R  |
    +-----+-----+-----+-----+-----+-----+-----+-----+

- `TXD` – Writing to this register starts transmitting the written byte to the
  keyboard.
- `RXD` – Contains the byte (a part of a scan code) read from the keyboard.
  Writing any value to this register acknowledges the read byte and enables
  reading the next byte.
- `READY` – Indicates the current state of the interface. This register should
  be read by the interrupt handler if a keyboard interrupt is indicated by bit
  `ikbd` of register `f`. Meaning of bits:
    - `R` (Received) – 1 if there is an unacknowledged byte in `RXD`
    - `T` (TxReady) – 1 if a new byte can be sent to the keyboard (after
      a reset or after the previous byte has been sent)

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

The development environment runs on a host computer. It consists of an
assembler and a debugger. For details and instructions how to use them, see the
respective assembler and debugger reference sections later in this document.

#### Debugger

The debugger needs a target computer connected via a serial line. It provides
functions for loading binary programs (produced by the assembler), running
them, and examining their state.

#### Assembler

The assembler generates binary files that can be loaded and executed on the
target computer. It does not need a connected target computer.

-------------------------------------------------------------------------------

## Control and status registers

| Name | Operations | Content |
|:----:|:----------:|:--------|
| `csr0` | read all bits, write bits 0–7 | Exception and interrupt information |
| `csr1` | read, write | Address of the interrupt and exception handler |
| `csr2` | read, write | Temporary storage the interrupt and exception handler |
| `csr3` | read, write | Temporary storage the interrupt and exception handler |
| `csr4` | read, write | Temporary storage the interrupt and exception handler |
| `csr5` | read, write | Temporary storage the interrupt and exception handler |
| `csr6`...`csr15` | none | Reserved |

Reading and writing may be allowed for individual CSR bits.

Reading from CSR bits that do not allow reads returns zero values of these
bits. Writing to CSR bits that do not allow writes fails silently for these
bits and does not change a value of the bits.

### csr0

    +-----------------+-----------------+
    | 1 1 1 1 1 1 0 0 | 0 0 0 0 0 0 0 0 | Bits
    | 5 4 3 2 1 0 9 8 | 7 6 5 4 3 2 1 0 |
    +-----------------+-----------------+
    | 0 0 0 0 0 0 0 H |      REASON     | Meaning
    +-----------------+-----------------+

The lower 8 bits `REASON` of `csr0` contain the reason code of the last
exception. It is unchanged until the next exception.

| Value | Name | Meaning |
|------:|:----:|:--------|
| 0 | `UNSPEC` | Unspecified, exception caused by setting bit 9 of `f` |
| 1 | `IZERO` | Illegal instruction with opcode 0 |
| 2 | `IINSTR` | Illegal instruction with nonzero opcode |
| 3...255 | | Reserved |

The upper 8 bits of `csr0` contain additional information about the last
exception or interrupt:

- `H` – Hardware-generated. Set to 0 if the exception or interrupt was
  generated by the program setting a bit in register `f` or by an exception
  instruction. Set to 1 if the exception was generated by CPU or the interrupt
  was generated by an I/O device.
- bits 1...7 – Reserved, containing value 0

### csr1

This CSR is used to store the address of the interrupt handler, normally stored
in register `ia`. Before returning from the handler, the return address is
written to `ia`.

_Rationale_: A return from the handler enables interrupts, therefore the
handler may be called again before executing the first instruction after the
return. This requires having the handler address in `ia`. But before the
return, `ia` contains the return address, which will be moved to `pc`. To be
able to set the handler address to `ia` before enabling interrupts, the address
must be available somewhere. It cannot be stored in a normal register, because
all registers must be restored prior to the return. So, `csr1` is used to store
the handler address.

### csr2...csr5

These CSRs are intended as temporary storage for the interrupt handler. If used
as such, any code executed with interrupts enabled outside the handler must not
expect that any of these registers keeps its value between instructions.

_Rationale_: The interrupt handler must store values of registers and restore
them before return. These CSRs provide an alternative to instruction `ddsto`
for storing registers without changing any register value. Storing registers at
some dedicated memory area (instead on the stack handled by `ldis` and `ddsto`)
needs to load the memory address, overriding the value of one register.
Reserving CSRs as temporary registers allows to save unchanged flags and/or an
address register.

### csr6...csr15

These CSRs are reserved for future use. They cannot be written and reading them
always returns 0.

-------------------------------------------------------------------------------

## Instruction set

### Format of instructions

The common format of all instructions is:

    +---------+---------+-----------------+
    | 1 1 1 1 | 1 1 0 0 | 0 0 0 0 0 0 0 0 | Bits
    | 5 4 3 2 | 1 0 9 8 | 7 6 5 4 3 2 1 0 |
    +---------+---------+-----------------+
    |   DSTR  |   SRCR  |      OPCODE     | Meaning
    +---------+---------+-----------------+

- `OPCODE` - The instruction code
- `DSTR` - The index of the destination register `r0`...`r15` or
  `csr0`...`csr15`.
- `SRCR` - The index of the source register `r0`...`r15` or `csr0`...`csr15`.

Instruction mnemonics are written as:

    opcode dstr, srcr

Unconditional instructions have 0 in bit 7 of an opcode. Remaining 7 bits 0...6
define the instruction, hence there are 128 available unconditional opcodes.

    +---------+---------+---+---------------+
    | 1 1 1 1 | 1 1 0 0 | 0 | 0 0 0 0 0 0 0 | Bits
    | 5 4 3 2 | 1 0 9 8 | 7 | 6 5 4 3 2 1 0 |
    +---------+---------+---+---------------+
    |   DSTR  |   SRCR  |      OPCODE       | Meaning
    +---------+---------+---+---------------+
    |   DSTR  |   SRCR  | 0 |      OP       |
    +---------+---------+---+---------------+

Conditional instructions have 1 in bit 7 of an opcode. Remaining 7 bits are
split between the 3-bit instruction code and 4-bit condition, which can test
any single bit of the flags (the lower 8 bits of register `f`). There are
8 possible conditional instructions.

    +---------+---------+---+-------+---+-------+
    | 1 1 1 1 | 1 1 0 0 | 0 | 0 0 0 | 0 | 0 0 0 | Bits
    | 5 4 3 2 | 1 0 9 8 | 7 | 6 5 4 | 3 | 2 1 0 |
    +---------+---------+---+-------+---+-------+
    |   DSTR  |   SRCR  |          OPCODE       | Meaning
    +---------+---------+---+-------------------+
    |   DSTR  |   SRCR  | 1 |   OP  |   COND    |
    +---------+---------+---+-------+---+-------+
    |   DSTR  |   SRCR  | 1 |   OP  | V | FLAG  |
    +---------+---------+---+-------+---+-------+

- `OP` - The instruction code
- `V` - The expected value of the `FLAG` bit
- `FLAG` - The index of the tested bit in the lower byte of register `f`

_Rationale_:

- The larger part of opcode space is needed for unconditional instructions.
- The conditional instructions have also two register operands and can test any
  of the 8 flags.
- Ordering of conditional instruction bits is chosen so that if memory content
  is viewed as hexadecimal bytes, an instruction is displayed as 4 digits `OC
  DS`, that is, `OP COND DSTR, SRCR`.

### Groups of instructions

- Move values between registers: `csrr`, `csrw`, `exch`, `mv`
- Read and write memory: `ddsto`_(1)_`, ld`, `ldb`, `ldis`, `ldisx`_(2)_, `sto`,
  `stob`
- Conditional: `exchNF`_(3)_, `ldNF`, `ldNFis`, `ldxNFis`_(4)_, `mvNF`
     - `N` is missing if the expected flag value is 1, or `n` if the expected
       value is 0
     - `F` is any flag name: `f0`, `f1`, `f2`, `f3`, `z`, `c`, `s`, `o`
     - Examples of full instruction names: `ldz`, `exchnc`
- Computational (arithmetic, logic, comparison): `add`, `and`, `cmps`, `cmpu`,
  `dec1`, `dec2`, `inc1`, `inc2`, `neg`_(5)_, `not`, `or`, `rev`, `shl`, `shr`,
  `shra`, `sub`, `xor`
- Illegal instruction (zero opcode): `ill`
- Interrupts and exceptions: `reti`

Some instructions are optional, because they could be easily replaced by
sequences of other instructions:

- _(1)_ Push, can be replaced by `dec`, `sto`
- _(2)_ Call, target address in memory at address in `pc`
- _(3)_ Conditional call, target address in a register
- _(4)_ Conditional call, target address in memory at address in `pc`

### Alphabetical list of instructions

Instructions with opcodes not it the list or marked "not implemented" cause
exception with reason `IINSTR`.

#### ADD (Addition)

    add dstr, srcr

Opcode: 0x01

Adds the value in register `srcr` to register `dstr` and stores the result into
`dstr`. It sets flags: `z` to 1 if the result is zero; `c` to the carry from
the highest bit; `s` to 1 if the result is negative (copies the highest bit of
the result); `o` to 1 if a signed overflow occurs.

#### AND (bitwise And)

    and dstr, srcr

Opcode: 0x02

Computes the binary AND of contents of registers `srcr` and `dstr` and stores
the result into `dstr`. It sets flags: `z` to 1 if the result is zero; `c` to
0; `s` to 1 if the result is negative (copies the highest bit of the result);
`o` to 0.

#### CMPS (Compare Signed)

    cmps dstr, srcr

Opcode: 0x1b

Compares the values in registers `dstr` and `srcr` as signed integers and sets
flags: `z` to 1 if the values are equal; `c` to 1 if `dstr` is less or equal to
`srcr`; `s` to 1 if `dstr` is less than `srcr`; `o` to 0.

#### CMPU (Compare Unsigned)

    cmpu dstr, srcr

Opcode: 0x19

Compares the values in registers `dstr` and `srcr` as unsigned integers and
sets flags: `z` to 1 if the values are equal; `c` to 1 if `dstr` is less or
equal to `srcr`, `s` to 1 if `dstr` is less than `srcr`; `o` to 0.

#### CSRR (Control and Status Register Read)

    csrr dstr, src_csr

Opcode: 0x03

Reads the CSR register `src_csr` and stores its value into register `dstr`.
Bits of the CSR that are not readable are returned as 0. It does not modify
flags.

#### CSRW (Control and Status Register Write)

    csrw dst_csr, srcr

Opcode: 0x04

Writes the value from register `srcr` to the CSR register `dst_csr`. Bits of
the CSR that are not writable are unchanged. It does not modify flags.

#### DDSTO (Decrement Destination and Store)

    ddsto dstr, srcr

Opcode: 0x17

Decrements the value in register `dstr` by 2 and then writes the value in
register `srcr` (one word, two bytes) to memory at the address in register
`dstr`. It does not modify flags.

#### DEC1 (Decrement by 1)

    dec1 dstr, srcr

Opcode: 0x05

Subtracts 1 from the value in register `srcr` and stores the result into
register `dstr`. It sets flags: `z` to 1 if the result is zero; `c` to the
borrow from the highest bit (1 if the result is 0xffff); `s` to 1 if the result
is negative (copies the highest bit of the result); `o` to 1 if a signed
overflow occurs (the result is 0x7fff).

#### DEC2 (Decrement by 2)

    dec2 dstr, srcr

Opcode: 0x06

Subtracts 2 from the value in register `srcr` and stores the result into
register `dstr`. It sets flags: `z` to 1 if the result is zero; `c` to the
borrow from the highest bit (1 if the result is 0xffff or 0xfffe); `s` to 1 if
the result is negative (copies the highest bit of the result); `o` to 1 if
a signed overflow occurs (the result is 0x7fff or 0x7ffe).

#### EXCH (Exchange)

    exch dstr, srcr

Opcode: 0x07

Exchanges values in source and destination registers. It does not modify flags.

#### EXCHnf (Exchange if / if Not Flag)

    exchf0 dstr, srcr
    exchnf0 dstr, srcr
    exchf1, exchf2, exchf3, exchz, exchc, exchs, excho
    exchnf1, exchnf2, exchnf3 exchnz, exchnc, exchns, exchno

Opcode: 0x8? __(not implemented)__

If the test is true then it exchanges values in source and destination
registers. Otherwise it does nothing. It does not modify flags.

#### INC1 (Increment by 1)

    inc1 dst, srcr

Opcode: 0x08

Adds 1 to the value in register `srcr` and stores the result into register
`dstr`. It sets flags: `z` to 1 if the result is zero; `c` to the carry from
the highest bit (1 if the result is 0x0000); `s` to 1 if the result is negative
(copies the highest bit of the result); `o` to 1 if a signed overflow occurs
(the result is 0x8000).

#### INC2 (Increment by 2)

    inc2 dst, srcr

Opcode: 0x09

Adds 2 to the value in register `srcr` and stores the result into register
`dstr`. It sets flags: `z` to 1 if the result is zero; `c` to the carry from
the highest bit (1 if the result is 0x0000 or 0x0001); `s` to 1 if the result
is negative (copies the highest bit of the result); `o` to 1 if a signed
overflow occurs (the result is 0x8000 or 0x8001).

#### ILL (Illegal instruction)

    ill dstr, srcr

Opcode: 0x00

It causes exception with reason `IZERO`. It does not modify flags.

#### LD (Load)

    ld dstr, srcr

Opcode: 0x0a

Reads one word (two bytes) from memory at the address in register `srcr` and
stores the value into register `dstr`. It does not modify flags.

#### LDB (Load Byte)

    ldb dstr, srcr

Opcode: 0x0b

Reads one byte from memory at the address in register `srcr` and stores the
value into the lower byte of register `dstr`. The upper byte of `dstr` is
unchanged. It does not modify flags.

#### LDIS (Load and Increment Source)

    ldis dstr, srcr

Opcode: 0x0c

Reads one word (two bytes) from memory at the address in register `srcr`,
stores the value into register `dstr`, and increments `srcr` by 2. It does not
modify flags.

#### LDISX (Load, Increment Source, and Exchange)

    ldisx dstr, srcr

Opcode: 0x0d __(not implemented)__

Reads one word (two bytes) from memory at the address in register `srcr`,
stores the value into register `dstr`, increments `srcr` by 2 and exchanges
values of registers `srcr` and `dstr`. It does not modify flags.

#### LDnf (Load if / if Not Flag)

    ldf0 dstr, srcr
    ldnf0 dstr, srcr
    ldf1, ldf2, ldf3, ldz, ldc, lds, ldo
    ldnf1, ldnf2, ldnf3, ldnz, ldnc, ldns, ldno

Opcode: 0x9?

If the test is true then it reads one word (two bytes) from memory at the
address in register `srcr` into register `dstr`. Otherwise it does nothing. It
does not modify flags.

#### LDnfIS (Load if /if Not Flag or Increment Source)

    ldf0is dstr, srcr
    ldnf0is dstr, srcr
    ldf1is, ldf2is, ldf3is, ldzis, ldcis, ldsis, ldois
    ldnf1is, ldnf2is, ldnf3is, ldnzis, ldncis, ldnsis, ldnois

Opcode: 0xa?

If the test is true then it reads one word (two bytes) from memory at the
address in register `srcr` into register `dstr`. If the test is false then it
increments the value in register `srcr` by 2. It does not modify flags.

#### LDXnfIS (Load and Exchange if / if Not Flag and Increment Source)

    ldxf0is dstr, srcr
    ldxnf0is dstr, srcr
    ldxf1is, ldxf2is, ldxf3is, ldxzis, ldxcis, ldxsis, ldxois
    ldxf1is, ldxnf2is, ldxnf3is ldxnzis, ldxncis, ldxnsis, ldxnois

Opcode: 0xb? __(not implemented)__

If the test is true then it reads one word (two bytes) from memory at the
address in register `srcr` into register `dstr`, increments `srcr` by 2, and
exchanges values in registers `srcr` and `dstr`. If the test is false then it
increments the value in register `srcr` by 2. It does not modify flags.

#### MULSS (Multiply Signed and Signed)

    mulss dstr, srcr

Opcode: 0x1e

Multiplies signed values in registers `srcr` and `dstr` and yields a 32-bit
signed result. The lower 16 bits of the result are stored into `dstr`, the upper
16 bits are stored into `srcr`. It sets flags: `z` to 1 if the result is zero;
`c` to 1 if the upper 16 bits are not all zeros for a nonnegative result or all
ones for a negative result; `s` if the result is negative (copies the highest
bit of a result from `srcr`); `o` if a signed overflow occurs (the result does
not fit in the range of signed 16 bit numbers).

#### MULSU (Multiply Signed and Unsigned)

    mulsu dstr, srcr

Opcode: 0x1f

Multiplies a signed value in register `dstr` and an unsigned value in `srcr`
and yields a 32-bit signed result. The lower 16 bits of the result are stored
into `dstr`, the upper 16 bits are stored into `srcr`. It sets flags: `z` to
1 if the result is zero; `c` to 1 if the upper 16 bits are not all zeros for
a nonnegative result or all ones for a negative result; `s` if the result is
negative (copies the highest bit of a result from `srcr`); `o` if a signed
overflow occurs (the result does not fit in the range of signed 16 bit
numbers).

#### MULUS (Multiply Unsigned and Signed)

    mulus dstr, srcr

Opcode: 0x20

Multiplies an unsigned value in register `dstr` and a signed value in `srcr`
and yields a 32-bit signed result. The lower 16 bits of the result are stored
into `dstr`, the upper 16 bits are stored into `srcr`. It sets flags: `z` to
1 if the result is zero; `c` to 1 if the upper 16 bits are not all zeros for
a nonnegative result or all ones for a negative result; `s` if the result is
negative (copies the highest bit of a result from `srcr`); `o` if a signed
overflow occurs (the result does not fit in the range of signed 16 bit
numbers).

#### MULUU (Multiply Unsigned and Unsigned)

    muluu dstr, srcr

Opcode: 0x21

Multiplies unsigned values in registers `srcr` and `dstr` and yields a 32-bit
unsigned result. The lower 16 bits of the result are stored into `dstr`, the
upper 16 bits are stored into `srcr`. It sets flags: `z` to 1 if the result is
zero; `c` to 1 if the upper 16 bits are not all zeros (the result does not fit
in the range of unsigned 16 bit numbers); `s` to 0; `o` if a signed overflow
occurs (the result does not fit in the range of signed 16 bit numbers).

#### MV (Move)

    mv dstr, srcr

Opcode: 0x0e

Copies the value in register `srcr` into register `dstr`. It does not modify
flags.

#### MVnf (Move if /if Not Flag)

    mvf0 dstr,  srcr
    mvnf0 dstr,  srcr
    mvf1, mvf2, mvf3, mvz, mvc, mvs, mvo
    mvnf1, mvnf2, mvnf3, mvnz, mvnc, mvns, mvno

Opcode: 0xc?

If the test is true then it copies the value in register `srcr` into register
`dstr`. Otherwise it does nothing. It does not modify flags.

#### NEG (Negative, two's complement)

    neg dstr, srcr

Opcode: 0x0f __(not implemented)__

Computes two's complement of the value in register `srcr` (it inverts all bits
and adds 1) and stores the result into register `dstr`). It sets flags: `z` to
1 if the result is zero; `c` to 1 if the result is 0x0000; `s` to 1 if the
result is negative (copies the highest bit of the result); `o` to 1 if signed
overflow occurs (the result is 0x8000).

It can be replaced by the sequence of instructions

    not dstr, srcr
    inc1 dstr, dstr

#### NOT (bitwise Not)

    not dstr, srcr

Opcode: 0x10

Inverts all bits of the value in register `srcr` and stores the result into
register `dstr`. It sets flags: `z` to 1 if the result is zero; `c` to 0; `s`
to 1 if the result is negative (copies the highest bit of the result); `o` to
0.

#### OR (bitwise Or)

    or dstr, srcr

Opcode: 0x11

Computes the binary OR of contents of registers `srcr` and `dstr` and stores
the result into `dstr`. It sets flags: `z` to 1 if the result is zero; `c` to
0; `s` to 1 if the result is negative (copies the highest bit of the result);
`o` to 0.

#### RETI (Return from Interrupt handler)

    reti dstr, srcr
    reti pc, ia

Opcode: 0x1c

Atomically sets bit `ie` (interrupts enabled) in register `f`, moves the value
from register `ia` to register `pc`, and reads the value from `csr1` to `ia`.
This instruction is intended to perform return from the interrupt/exception
handler, therefore it ignores its arguments and always operates on registers
`ia`, `pc`, and `csr1`. It does not modify flags except bit `ie`.

#### REV (Reverse)

    rev dstr, srcr

Opcode: 0x1d

Reverses the order of bits of the value in register `srcr` and stores the
result into register `dstr`. It sets flags: `z` to 1 if the result is zero; `c`
to 0; `s` to 1 if the result is negative (copies the highest bit of the
result); `o` to 0.

#### SHL (Shift Left)

    shl dstr, srcr

Opcode: 0x12

Shifts the value of register `dstr` to the left (adding zeros at the right) by
the number of bits given by the value of the lowest 4 bits of register `srcr`
and stores the result into `dstr`. It sets flags: `z` to 1 if the result is
zero; `c` to the highest bit of the original value of `dstr` if shifting by
1 bit, unspecified otherwise; `s` to 1 if the result is negative (copies the
highest bit of the result); `o` to 1 if the operation changes the value of the
highest bit of `dstr`.

#### SHR (Shift Right)

    shr dstr, srcr

Opcode: 0x13

Shifts the value of register `dstr` to the right (adding zeros at the left) by
the number of bits given by the value of the lowest 4 bits of register `srcr`
and stores the result into `dstr`. It sets flags: `z` to 1 if the result is
zero; `c` to the lowest bit of the original value of `dstr` if shifting by
1 bit, unspecified otherwise; `s` to 1 if the result is negative (copies the
highest bit of the result; can be 1 only if shifting a negative value by
0 bits); `o` to 1 if the operation changes the value of the highest bit of
`dstr` (can be 1 only if shifting a negative value by at least 1 bit).

#### SHRA (Shift Right Arithmetic)

    shra dstr, srcr

Opcode: 0x14

Shifts the value of register `dstr` to the right, setting the shifted-from bits
at the left to the value of the sign (highest) bit, by the number of bits given
by the value of the lowest 4 bits of register `srcr` and stores the result into
`dstr`. It sets flags: `z` to 1 if the result is zero; `c` to the lowest bit of
the original value of `dstr` if shifting by 1 bit, unspecified otherwise; `s`
to 1 if the result is negative (copies the highest bit of the result); `o` to
0 if shifting by 0 bits, `o` to 1 if shifting by 1 bit and the result is 0xffff
but mathematical result should be 0 (can be 1 only if shifting value 0xffff),
unspecified if shifting by more than one bit.

#### STO (Store)

    sto dstr, srcr

Opcode: 0x15

Writes the value in register `srcr` (one word, two bytes) to memory at the
address in register `dstr`. It does not modify flags.

#### STOB (Store Byte)

    stob dstr, srcr

Opcode: 0x16

Writes the lower byte of register `srcr` to memory at the address in register
`dstr`. It does not modify flags.

#### SUB (Subtraction)

    sub dstr, srcr

Opcode: 0x18

Subtracts the value in register `srcr` from register `dstr` and stores the
result into `dstr`. It sets flags: `z` to 1 if the result is zero; `c` to the
borrow from the highest bit; `s` to 1 if the result is negative (copies the
highest bit of the result); `o` to 1 if a signed overflow occurs.

#### XOR (bitwise Xor)

    xor dstr, srcr

Opcode: 0x1a

Computes the binary XOR of contents of registers `srcr` and `dstr` and stores
the result into `dstr`. It sets flags: `z` to 1 if the result is zero; `c` to
0; `s` to 1 if the result is negative (copies the highest bit of the result);
`o` to 0.

### Execution of instructions

Execution of each instruction consists of one or more phases. The following
table shows executed phases for each instruction.

- _Condition_ – evaluation of flag values (for a conditional instruction)
- _Load1_ – load one byte from memory or load the first of two bytes (of a word)
  from memory
- _ALU_ – move data in registers or CSRs, perform an operation by the ALU
- _Flags_ – modify flags
- _Load2_ – load the second of two bytes (of a word) from memory
- _Store1_ – store one byte to memory or store the first of two bytes (of
  a word) to memory
- _Store2_ – store the second of two bytes (of a word) to memory

| Instruction | Implemented | Condition | Load1 | Load2 | ALU | Flags | Store1 | Store2 |
| :---------: | :---------: | :-------: | :---: | :---: | :---: | :---: | :---: | :---: |
| `add` | ✔ | ✘ | ✘ | ✘ | ✔ | ✔ | ✘ | ✘ |
| `and` | ✔ | ✘ | ✘ | ✘ | ✔ | ✔ | ✘ | ✘ |
| `cmps` | ✔ | ✘ | ✘ | ✘ | ✔ | ✔ | ✘ | ✘ |
| `cmpu` | ✔ | ✘ | ✘ | ✘ | ✔ | ✔ | ✘ | ✘ |
| `csrr` | ✔ | ✘ | ✘ | ✘ | ✔ | ✘ | ✘ | ✘ |
| `csrw` | ✔ | ✘ | ✘ | ✘ | ✔ | ✘ | ✘ | ✘ |
| `ddsto` | ✘ | ✘ | ✘ | ✘ | ✔ | ✘ | ✔ | ✔ |
| `dec1` | ✔ | ✘ | ✘ | ✘ | ✔ | ✔ | ✘ | ✘ |
| `dec2` | ✔ | ✘ | ✘ | ✘ | ✔ | ✔ | ✘ | ✘ |
| `exch` | ✔ | ✘ | ✘ | ✘ | ✔ | ✘ | ✘ | ✘ |
| `exchnf` | ✘ | ✔ | ✘ | ✘ | ✔ | ✘ | ✘ | ✘ |
| `inc1` | ✔ | ✘ | ✘ | ✘ | ✔ | ✔ | ✘ | ✘ |
| `inc2` | ✔ | ✘ | ✘ | ✘ | ✔ | ✔ | ✘ | ✘ |
| `ill` | ✔ | ✘ | ✘ | ✘ | ✘ | ✘ | ✘ | ✘ |
| `ld` | ✔ | ✘ | ✔ | ✔ | ✘ | ✘ | ✘ | ✘ |
| `ldb` | ✔ | ✘ | ✔ | ✘ | ✘ | ✘ | ✘ | ✘ |
| `ldis` | ✔ | ✘ | ✔ | ✔ | ✔ | ✘ | ✘ | ✘ |
| `ldisx` | ✘ | ✘ | ✔ | ✔ | ✔ | ✘ | ✘ | ✘ |
| `ldnf` | ✔ | ✔ | ✔ | ✔ | ✘ | ✘ | ✘ | ✘ |
| `ldnfis` | ✔ | ✔ | ✔ | ✔ | ✔ | ✘ | ✘ | ✘ |
| `ldxnfis` | ✘ | ✔ | ✔ | ✔ | ✔ | ✘ | ✘ | ✘ |
| `mulss` | ✘ | ✘ | ✘ | ✘ | ✔ | ✔ | ✘ | ✘ |
| `mulsu` | ✘ | ✘ | ✘ | ✘ | ✔ | ✔ | ✘ | ✘ |
| `mulus` | ✘ | ✘ | ✘ | ✘ | ✔ | ✔ | ✘ | ✘ |
| `muluu` | ✘ | ✘ | ✘ | ✘ | ✔ | ✔ | ✘ | ✘ |
| `mv` | ✔ | ✘ | ✘ | ✘ | ✔ | ✘ | ✘ | ✘ |
| `mvnf` | ✔ | ✔ | ✘ | ✘ | ✔ | ✘ | ✘ | ✘ |
| `neg` | ✘ | ✘ | ✘ | ✘ | ✔ | ✔ | ✘ | ✘ |
| `not` | ✔ | ✘ | ✘ | ✘ | ✔ | ✔ | ✘ | ✘ |
| `or` | ✔ | ✘ | ✘ | ✘ | ✔ | ✔ | ✘ | ✘ |
| `reti` | ✔ | ✘ | ✘ | ✘ | ✔ | ✘ | ✘ | ✘ |
| `rev` | ✔ | ✘ | ✘ | ✘ | ✔ | ✔ | ✘ | ✘ |
| `shl` | ✔ | ✘ | ✘ | ✘ | ✔ | ✔ | ✘ | ✘ |
| `shr` | ✔ | ✘ | ✘ | ✘ | ✔ | ✔ | ✘ | ✘ |
| `shra` | ✔ | ✘ | ✘ | ✘ | ✔ | ✔ | ✘ | ✘ |
| `sto` | ✔ | ✘ | ✘ | ✘ | ✘ | ✘ | ✔ | ✔ |
| `stob` | ✔ | ✘ | ✘ | ✘ | ✘ | ✘ | ✔ | ✘ |
| `sub` | ✔ | ✘ | ✘ | ✘ | ✔ | ✔ | ✘ | ✘ |
| `xor` | ✔ | ✘ | ✘ | ✘ | ✔ | ✔ | ✘ | ✘ |

-------------------------------------------------------------------------------

## System parameters

The following table summarizes values of various parameters and constants.

| Name | Value | Description |
| :----: | ----: | :----------- |
| `ADDR_MAX` | `65535`, `0xffff` | Maximum address in the address space |
| `CLK_ADDR` | `65520`, `0xfff0` | Address of the system clock counter register |
| `CPU_HZ` | `50000000` | CPU clock frequency in Hz |
| `HZ` | `100` | System clock frequency in Hz |
| `KBD_ADDR` | `65504`, `0xffe0` | Address of the first keyboard controller register |
| `MEM_MAX` | `29999`, `0x752f` | Address of the last byte of memory |
| `VIDEO_ADDR` | `23040`, `0x5a00` | Video RAM start address |

_Rationale_: Address of the last byte is used instead of a memory size, because
if the memory size was the same as the address space, the memory size (equal to
an address after the end of the address space) would not be representable as an
address value.

-------------------------------------------------------------------------------

## Assembler reference

The assembler reads a single source file (with extension `.s`). This file can
include (directly or indirectly) other assembler source files. It then produces
a raw binary file (with extension `.bin`), which can be uploaded to the target
system memory by the debugger, and a textual memory initialization file (with
extension `.mif`), which can be used by FPGA development tools to initialize
memory during FPGA configuration. In addition, an output text file (with
extension `.out`) is produced. It contains the assembler input annotated by
content (addresses and byte values) of the binary in hexadecimal format.

### Invocation

    mb50as [-v] FILE.s

Compiles file `FILE.s`. If successful, it produces binary `FILE.bin`, textual
memory initialization file `FILE.mif`, text output `FILE.out`, and terminates
with exit code 0. Any errors and warnings, as well as verbose messages (enabled
by option `-v`), are written to the standard error. After an error, the
assembler terminates with exit code 1.

### Syntax

_The syntax is described informally. A formal grammar is not presented here
(yet)._

_Comments_ start with character `#` (that does not belong to a string constant)
and extend to the end of line.

The assembler uses only printable ASCII characters (character codes 32 to 126),
newline (ASCII 10), and horizontal tab (ASCII 9, which is equivalent to
a single space). In a comment or string constant, any byte with
value 32 to 255 can be used. These bytes are not interpreted in any way.
Letters, except in string constant, are case insensitive (for example, in
identifiers and hexadecimal numbers).

A _string constant_ is a sequence of zero or more characters enclosed in quotes,
e.g., `"string const"`. Quotes must be escape inside string constants.
Following escape sequences are supported in character and string constants:

| Escape sequence | Replaced character | Character code |
|:---------------:|:------------------:|:--------------:|
| `\0` | `NUL` (null character) | 0, 0x00 |
| `\t` | `HT` (horizontal tab) | 9, 0x09 |
| `\n` | `NL` (new line) | 10, 0x0a |
| `\r` | `CR` (carriage return) | 13, 0x0d |
| `\"` | `"` | 34, 0x22 |
| `\'` | `'` | 39, 0x27 |
| `\\` | `\` | 92, 0x5c |
| `\xHH` | Character with hex. code HH | 0xHH |

Outside of string constants, any number of whitespace characters is interpreted
as a single space. Whitespace can be added around any delimiter.

_Identifiers_ consist of letters, digits, and underscores, and must not start
with a digit.

_Names_ refer to instructions, registers (normal and CSRs), labels, constants,
and macros defined elsewhere in the program. All instruction mnemonic names and
register names are implicitly defined in each source file. It is an error to
define a single name (implicitly or explicitly) multiple times in the same
file. A name can be:

- _unqualified_ – a single identifier; it refers to the global definition of
  the name; it is an error if there are multiple definition of the name in the
  whole program
- _qualified_ – two identifiers separated by a period (`namespace.id`); it
  refers to the definition of `id` in a specific `namespace`
- _local_ – an identifier prefixed by a period (`.id`); it refers to the
  definition of `id` in the current source file

Syntax of the assembler source is line-based. Empty lines and lines containing
only whitespace and comments are ignored. Otherwise, a line can contain:

_An instruction_

    opcode DSTR, SRCR

where `opcode` must be a valid instruction, `DSTR` and `SRCR` must be
valid register or CSR names or aliases.

_A label_

    LABEL_NAME:

A label defines a symbolic name for a place (an address) in the generated code.
It can occur on a line by its own, or it can be a prefix of a line containing
an instruction, a directive, or another label. If multiple labels are defined
on the same line, they will all have the same value.

In macro definition, a label name may end with `$`, i.e., `LABEL_NAME$`. In
each expansion of the macro, the character `$` is replaced by a number unique
across all references to any macros. This feature can be used to generate
labels unique for a macro expansion. If used outside a macro definition, `$` is
replaced by `0` (zero).

A label name may end with `$$`, i.e., `LABEL_NAME$$`. The characters `$$` are
replaced by the number replacing `$` in the previous macro expansion done in the
current macro expansion if expanding a macro, or in the current file otherwise.
If there is no previous macro expansion in the current macro expansion or file,
`$$` is replaced by `0` (zero). This feature can be used to access unique
macros `LABEL_NAME$`, created in a macro expansion, from outside.

_A directive_

    $dir ARG1, ARG2, ..., ARGN

It is interpreted by the assembler.

_A macro reference_

    macro ARG1, ARG2, ..., ARGN

It is replaced by the expansion of the macro, defined by directives `$macro`
and `$end_macro`. Macros are expanded recursively, that is, the macro
replacement text is searched again for macros. A cyclic macro definition is an
error.

Each argument of an instruction can be a register name expression. Each
argument of a macro can be a register name expression or an arithmetic
expression. All arithmetic in expressions is done using 16-bit unsigned
integers. Components of an expression:

- An unsigned 16-bit integer, written as a decimal number without a sign, or as
  a hexadecimal constant (started by `0x`), or as a binary constant (started by
  `0b`). Groups of digits may be separated by an underscore to improve
  readability.
- A single character constant, converted to a number with the higher
  byte containing zero and the lower byte containing the character code
- An empty character constant `''`, equal to `'\0'`
- A two-character constant, converted to a number with the lower byte
  containing the first character code and the higher byte containing the second
  character code
- Unary and binary operators with left associativity and the same meaning and
  precedence as in C. From highest to lowest priority:
    - `~` (bitwise NOT), `-` (unary minus, computes two's complement)
    - `*`, `/`, `%` (multiplication, division, remainder)
    - `+`, `-` (addition, subtraction)
    - `<<`, `>>` (left and right shifts)
    - `&` (bitwise AND)
    - `^` (bitwise XOR)
    - `|` (bitwise OR)
- A label, replaced by the corresponding address
- A special label `__addr`, which is replaced by the address of the current
  line. Its value is always equal to the value of any label on the current
  line.
- A name of a register or CSR; such expression cannot consist of anything else
- A name of a register alias, evaluated to the canonical register name
- A name of a constant, evaluated to the constant value. A constant can be
  defined by directive `$const`. Constant names may end with `$` or `$$`, with
  the same meaning as for labels.
- Parentheses

### Compilation process

During code generation, the assembler maintains the current address (the
address where the current instruction or results of directives `$data_b` and
`$data_w` will be written).

The current address is used to define label values. The assembler works in two
phases. In the first phase, source code is read, directives are processed, and
code is generated. During the first phase, it fully evaluates only expressions
without labels or containing only labels with know values, that is, defined
before the expression. In order to fix addresses of generated code in the first
phase, arguments of directives `$addr` must not contain (directly or
indirectly) any forward label references, so that they can be evaluated in the
first phase.

In the second phase, labels are resolved to addresses, expressions containing
labels not known in the first phase are evaluated, and their results are
substituted in the generated code.

### Directives

#### $addr

    $addr EXPRESSION

It evaluates a `EXPRESSION` (which must be fully evaluated during the first
compilation phase) and sets the result as the current address for code
generation.

#### $const

    $const NAME, EXPRESSION

Defines a constant with `NAME` (an identifier), with the value obtained by
evaluating the `EXPRESSION`. Characters `$` in `NAME$` and `NAME$$` are
replaced like in names of labels.

#### $data_b

    $data_b BYTE0, BYTE1, ..., BYTEN

Defines a sequence of bytes starting at the current address and increments the
current address by the number of bytes. Each `BYTE*` is an expression that will
be evaluated, the lower byte stored, and the higher byte discarded.
Alternatively, a `BYTE*` can be a string constant. In this case, bytes from the
string will be stored in their order.

#### $data_w

    $data_w WORD0, WORD1, ..., WORDN

Defines a sequence of 16-bit words starting at the current address and
increments the current address by 2 * number of words. Each `WORD*` is an
expressions that will be evaluated and stored, the lower byte first, followed
by the higher byte.

#### $end_macro

    $end_macro

Indicates the end of a macro definition. See also `$macro`.

#### $macro

    $macro NAME, ARG1, ..., ARGN

Starts definition of a macro. Each source line containing the macro name
followed by arguments will be replaced by the following lines up to
`$end_macro`. The `ARG*` parameters in the replacement text will be substituted
by the respective arguments of the macro call. Arguments are substituted as
expressions, not textually, so it is not needed to add additional parentheses
around parameters like in C macro definitions.

#### $use

    $use NAMESPACE, FILE

Includes the content of a file, identified by path `FILE` (not written in
quotes), if it has not been already included in the same compilation.
Subsequently, identifiers defined in the file can be accessed by qualified
names with the specified `NAMESPACE` name. If `FILE` is not an absolute path,
it is relative to the directory with the file containing the `$use`. Directives
`$use` may be used only at the beginning of a source file, preceded only by
empty lines, comment lines, or other `$use` directives.

### Output

Output files for a main assembler input file `FILE.s`

#### Raw binary file

`FILE.bin`

The binary output file of the assembler starts with one line (four hexadecimal
digits followed by newline) that defines the starting address of the memory
image. Then memory content follows as raw bytes.

#### Binary file in the MIF format

`FILE.mif`

This file contains the same data as the raw binary file, but in the textual
Memory Initialization File format. It can be included into the Quartus Prime
project in order to initialize the memory during FPGA configuration.

#### Text file

`FILE.out`

The output file is a copy of the source file, except lines containing only
a comment starting in the first column, with some additional lines, denoted by
the starting character `;` (semicolon). Comments not starting in the first
column of a line are retained.

- Before each line from a different file than the previous line, a line is
  added with the file name (from the command line or from a `$use` directive)
  and the line number.
- After each line containing an instruction, a line is added with canonical
  mnemonic name and register names.
- After each instruction or data line, a line is added with the address and
  hexadecimal values of the corresponding bytes in the output file.
- If a macro expansion produces several instructions or data lines, multiple
  lines containing instructions and hexadecimal values are added after the
  macro reference.

-------------------------------------------------------------------------------

## Debugger reference

The debugger connects to a MB50 system's serial control and debugging interface
via an RS-232 serial interface. It optionally reads and executes commands from
an initialization file. Then it reads commands from the standard input and
executes them interactively.

### Invocation

    mb50dbg /dev/ttyX [init_file]

It starts the debugger and uses the selected serial device for communication
with the target system. If the optional `init_file` is specified, commands from
it will be executed before entering the interactive mode.

### Groups of commands

- Debugger control: `do`, `help`, `quit`
- Command history and session recording: `history`, `script`
- Running a program: `execute`, `interrupt`, `step`
- Breakpoints and watchpoints: `break`, `watch`
- View and modify CPU state: `csr`, `register`
- Read and write memory: `dump`, `load`, `memset`, `save`

Numeric parameters of commands can use any format recognized by the assembler:
decimal, hexadecimal, or binary, with digit grouping by `_`. A number can use
the minus sign to compute a negative value (two's complement).

### Alphabetical list of commands

In commands, `ADDR` and `SIZE` may be entered as unsigned decimal or hexadecimal
(`0xaabb`) value. Zero `SIZE` means the whole address space, that is, 65536
bytes. `VALUE` may be a decimal number (negative values allowed),
a hexadecimal number (`0x1a2b`), a binary number (`0b1111000010101100`), or
a character constant containing zero (`''` equal to `'\0'`), one (`'x'`), or
two (`'xy'`) characters, the first stored in the lower byte. Groups of digits
may be separated by underscores. Command `memset` permits also strings in
double quotes (unlike in C, there is no terminating null byte appended).
Character and string values can contain the same escape sequences as defined by
the [assembler syntax](#syntax).

#### Break

    break [-] [ADDR]
    b

_The current implementation uses single stepping controlled by the debugger
instead of full-speed execution, therefore a program executes much slower if at
least one breakpoint is defined._

If a breakpoint is set on an address, the program execution is stopped before
executing the instruction at that address. If called without arguments, list
all breakpoints. If called with `ADDR`, set a breakpoint at this address. If
`-` is used before an address, delete a breakpoint at this address. If called
with `-` only, delete all breakpoints.

#### CSR

    csr [NAME] [VALUE]

Like `register`, but operates on `csr0`...`csr15`.

#### Do

    do FILE

Reads and executes commands from `FILE`.

#### Dump

    dump [ADDR [SIZE]]
    dumpd [ADDR [SIZE]]
    dumpw [ADDR [SIZE]]
    dumpwd [ADDR [SIZE]]
    d
    dd
    dw
    dwd

Dump data from memory in a readable format. It dumps `SIZE` bytes rounded up to
a full line of output, or just
a single output line if `SIZE` is not specified, starting at address `ADDR`. If
an address is not specified, it uses `ADDR` and `SIZE` from the previous
`dump[w][d]` command. With suffix `d`, decimal values are dumped, otherwise,
hexadecimal format is used. With suffix `w`, 16-bit words are dumped,
otherwise it dumps individual bytes and shows also ASCII characters when
dumping in hexadecimal.

#### Execute

    execute
    exe
    x

Run the program. Program execution is interrupted by entering a newline. Any
characters on the line before the newline are ignored.

#### Help

    help [COMMAND]
    h
    ?

Show the help for all commands (without an argument), or a help for a single
command (with a command name as the argument). Variant `?` shows only one line
for each command.

#### History

    history [FILE]
    hist

If called with a `FILE` name, start appending all executed commands to the end
of the file. If called without a file name, stop recording commands.

#### Load

    load FILE [ADDR]

Load content of a binary `FILE` from address `ADDR`. If `ADDR` is not
specified, use the starting address from `FILE`. It expects the binary format
produced by the assembler or by command `save`, that is, there is a single line
containing start address in hexadecimal before binary data.

#### Memset

    memset ADDR VALUE [VALUE...]
    m

Store values to memory. Each value can be a number (little endian if more than
one byte) or a string constant (in double quotes, characters stored in the
order of appearance in the string). Size of a binary or hexadecimal constant is
determined by the number of digits (up to 8 binary or 2 hexadecimal digits or
1 character yield a byte, more digits or characters store a little endian
word). Size of a decimal constant is two bytes if the value is outside the
range 0–255 or if it contains more than 3 digits (e.g., 0000, 0009, 0099,
0200). All values are stored sequentially starting at address `ADDR`.

#### Quit

    quit
    q

Terminate the debugger.

#### Register

    register [NAME] [VALUE]
    reg
    r

Display or set values of registers. Without arguments, it shows values of all
registers `r0`...`r15`. With `NAME`, only a single register is shown, where
`NAME` is a register index (`0`...`15`) or a register name or a standard
register alias (`r0`...`r15`, `pc`, `f`, `ia`, `ca`, `sp`). With also `VALUE`,
the value is stored in the register. See section [Flags](#flags) for meaning of
bits of register `f`.

#### Save

    save FILE [ADDR SIZE]

Save binary content of memory starting at `ADDR` and `SIZE` bytes long. If an
address and size is not specified, save the whole memory. It produces the file
format expected by command `load`, that is, there is a single line containing
start address in hexadecimal before binary data.

#### Script

    script [FILE]
    scr

If called with a `FILE` name, start appending all user input and debugger
output to the end of the file. If called without a file name, stop recording.

#### Step

    step
    s

Execute a single instruction.

#### Watch

    watch [r|w|-] [ADDR]
    w

_(not implemented)_

If a watchpoint is set on an address, the program execution is stopped after
executing an instruction that reads or writes that address. Executing an
instruction is considered as reading. If called without arguments, list all
watchpoints. If called with `ADDR`, set a watchpoint at this address that will
be triggered by both reading and writing. If `r` or `w` is used before an
address, the watchpoint is triggered only by reading or writing, respectively.
If `-` is used before an address, delete a watchpoint at this address. If
called with `-` only, delete all watchpoints.

-------------------------------------------------------------------------------

## Building the system from source code

These instructions assume using the specific FPGA development board described
in the top-level [README.md](../README.md) of this Git repository and Intel
Quartus Prime development suite for the FPGA part. For building and running the
development environment, recent GCC or Clang on Linux is expected. Porting to
other FPGAs, operating systems, or compilers should be a relatively easy task.

### Building MB50

Open the Quartus Prime project `mb50/mb50/mb50.qpf`. Compile the project and
program the FPGA.

### Building MB50DEV

Compile the assembler `mb50as` and the debugger `mb50dbg` from C++ sources
`mb50/mb50dev/mb50as.cpp` and `mb50/mb50dev/mb50dbg.cpp`. Both can be built by
running `make` in directory `mb50/mb50dev/`.

Build with Clang 19 and libc++:

    CXX=clang++-19 CXXFLAGS='-fexperimental-library -stdlib=libc++' make

-------------------------------------------------------------------------------

## ToDo

- [x] Project structure
    - [x] Structure of documentation
    - [x] Directory structure
- [x] Building instructions
    - [x] MB50 system
    - [x] MB50DEV development environment
- [x] Design
    - [x] Specify overall system design including rationale
    - [x] Specify CPU ISA
        - [x] Define the register set
        - [x] Define program execution, including CPU initialization, reset, and
          interrupt handling
        - [x] Define individual instructions (name, operands, description,
          mnemonic, detailed semantics)
    - [x] Specify external signals and buses of the CPU, including memory, I/O
      devices, and control/debugging interfaces
    - [x] Design the CPU microarchitecture
        - [x] Control Unit (CU)
        - [x] Arithmetic-Logic Unit (ALU)
        - [x] Registers (architectural and microarchitectural)
        - [x] Internal interconnection of CPU parts and external interfaces
    - [x] Design the development environment
        - [x] Assembler
        - [x] Debugger
- [ ] Implementation
    - [x] On FPGA
        - [x] CPU
        - [x] Memory
        - [x] Serial CDI
        - [x] VGA display
        - [x] PS/2 keyboard
        - [x] System clock
    - [ ] Development environment for a host computer
        - [x] Debugger
            - [x] Serial communication with the target computer
            - [x] CLI
        - [ ] Assembler
            - [ ] Generic processing
            - [ ] Instruction set

-------------------------------------------------------------------------------

## Author

Martin Beran

<martin@mber.cz>

This project was started in April 2024.
