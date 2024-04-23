<style>
table, td, th {
    border-collapse: collapse;
    border: 1px solid;
    padding: 1ex
}
</style>

# Computer MB50

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
 
#### External signals and buses
 
#### Microarchitecture
 
### Memory
 
### Serial control interface
 
### VGA display
 
### PS/2 keyboard
 
### System clock
 
### Development environment MB50DEV
 
#### Debugger
 
#### Assembler
 
-------------------------------------------------------------------------------

## Instruction set

-------------------------------------------------------------------------------

## System parameters

The following table summarizes values of various parameters and constants.

| Name | Value | Description |
| :----: | ----: | :----------- |
| `CPU_HZ` | `50000000` | CPU clock frequency in Hz |
| `HZ` | `100` | System clock frequency in Hz |
| `KBD_ADDR` | `???` | Address of the first keyboard controller register |
| `MEM_SZ` | `30000` | Memory size in bytes |
| `VIDEO_ADDR` | `???` | Video RAM start address |

-------------------------------------------------------------------------------

## Assembler reference

### Invocation

### Syntax

### Output

### Directives

-------------------------------------------------------------------------------

## Debugger reference

### Invocation

### Commands

-------------------------------------------------------------------------------

## Building the system from source code

These instructions assume using the specific FPGA development board described
in the top-level [README.md](../README.md) of this Git repository and Intel
Quartus Prime development suite for the FPGA part. For building and running the
development environment, recent GCC or Clang on Linux is expected. Porting to
other FPGAs, operating systems, or compilers should be a relatively easy task.

### Building MB50

### Building MB50DEV

-------------------------------------------------------------------------------

## ToDo

- [x] Project structure
    - [x] Structure of documentation
    - [x] Directory structure
- [ ] Building instructions
    - [ ] MB50 system
    - [ ] MB50DEV development environment
- [ ] Design
    - [ ] Specify overall system design including rationale
    - [ ] Specify CPU ISA
        - [ ] Define the register set
        - [ ] Define program execution, including CPU initialization, reset, and
          interrupt handling
        - [ ] Define individual instructions (name, operands, description, mnemonic,
          detailed semantics)
    - [ ] Specify external signals and buses of the CPU, including memory and
      control/debugging interfaces
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
