# Projects

Unless stated otherwise, for all projects:

- Source files are contained in a directory of the same name as the project
- Usually each `ENTITY` is defined in its own file `ENTITY.vhd`
- Test files of a project are stored in subdirectory `test/` of the project
  directory
    - Projects created before adding this rule do not have subdirectory
      `test/`: adder4b, alarm_clock, full_adder, half_adder, hex_counter_7seg,
      led_blink, led_blink_vhdl
- Test entity for an `ENTITY` is named `tb_ENTITY` and is stored in file
  `test/tb_ENTITY.vhd`
- Implementation language is VHDL
- Implementation is intended for a development kit containing Altera Cyclone IV
  EP4CE6E22C8N

## lib

Libraries intended to be used in multiple other projects. Individual libraries
are in subdirectories. Tests of library `XYZ` are stored in subdirectory `test`
of the library directory (`lib/XYZ/test/`).

### lib_io

Controllers for I/O devices

### lib_util

Various common definitions and utilities

## adder4b

A 4-bit full adder

## alarm_clock

An alarm clock that uses on-board peripherals

- 4x7 segment display shows:
    - time as HH.MM, with . blinking each second
    - seconds as .SS
    - time of alarm as HH.MM
    - setting of clock or alarm time, blinking the value being currently
      adjusted (either HH or MM)
- LEDs indicating modes:
    - LED1: off = clock view, on = alarm view
    - LED4: off = alarm disabled, on = alarm enabled
    - LED2+3: blinking = alarm time
- Speaker: playing sound at alarm time
- Buttons:
    - Button1: selection
        - when viewing: switches HH.MM -> .SS -> alarm HH.MM
        - when setting clock or alarm: switches between HH and MM
    - Button2:
        - when viewing alarm: enables/disables the alarm
        - when setting clock or alarm: increases the currently selected value
    - Button3:
        - when viewing alarm: enables/disables the alarm
        - when setting clock or alarm: decreases the currently selected value
    - Button4: set
        - long press switches from clock/alarm view to clock/alarm set mode
        - switches from clock set to view mode and sets seconds to 00 
        - switches from alarm set to view mode
    - any button: stops a sounding alarm

## demo_lib_led

Four blinking LED with periods 100, 200, 300, 500 ms and 7-segment display,
speaker, controlled by buttons and the reset button. A demo of library
packages:

- lib_util.pkg_clock
- lib_io.pkg_button
- lib_io.pkg_crystal
- lib_io.pkg_led
- lib_io.pkg_reset
- lib_io.pkg_seg7
- lib_io.pkg_speaker

## demo_uart

A demo of a serial port controller

## full_adder

A 1-bit full adder

## half_adder

A 1-bit half adder

## hex_counter_7seg

A counter displaying a hexadecimal value on 7-segment LED

## infrared_receiver

A receiver for infrared control. It displays received codes. It demonstrates
using library package `lib_io.pkg_infrared`.

## led_blink

A counter driven by on-board 50 MHz crystal, with 4 highest (most slowly
changing) bits indicated by LEDs. Defined by a block diagram.

## led_blink_vhdl

Alternatively blinking LEDs controlled by a counter driven by the on-board 50
MHz crystal.

# Knowledge base

## FPGA

FPGA __Altera Cyclone IV EP4CE6E22C8N__

Configuration memory: __EPCS16__

Kit __RZ-EasyFPGA A2.2__

### Pins

All pins are inverted (active level '0')

- crystal (50 MHz)
    - 23 FPGA_CLK
- reset button
    - 25 RESET
- LEDs
    - 87 LED1
    - 86 LED2
    - 85 LED3
    - 84 LED4
- buttons
    - 88 S1 (KEY1)
    - 89 S2 (KEY2)
    - 90 S3 (KEY3)
    - 91 S4 (KEY4)
- 7-segment display
    - 133 DIG1 (7seg. digit 1)
    - 135 DIG2 (7seg. digit 2)
    - 136 DIG3 (7seg. digit 3)
    - 137 DIG4 (7seg. digit 4)
    - 128 SEG0 (7seg. a)
    - 121 SEG1 (7seg. b)
    - 125 SEG2 (7seg. c)
    - 129 SEG3 (7seg. d)
    - 132 SEG4 (7seg. e)
    - 126 SEG5 (7seg. f)
    - 124 SEG6 (7seg. g)
    - 127 SEG7 (7seg. dp)
- speaker
    - 110 BEEP
- infrared receiver (1838)
    - 100 IR
- RS-232 serial port (MAX3232E multichannel RS-323 line driver and receiver;
  signaling rate up to 250 kbit/s)
    - 114 UART TXD
    - 115 UART RXD
- 1602 12864 LCD
    - 141 LCD1
    - 138 LCD2
    - 143 LCD3
    - 142 LCD4
    - 1 LCD5
    - 144 LCD6
    - 3 LCD7
    - 2 LCD8
    - 10 LCD9
    - 7 LCD10
    - 11 LCD11
- temperature sensor (LM75A)
    - 113 SDA
    - 112 SCL
- serial EEPROM (8192 b, 1024 B, AT24C08)
    - 99 I2C_SCL
    - 98 I2C_SDA
- PS2
    - 120 PS_DATA
    - 119 PS_CLOCK
- VGA
    - 103 VGA_VSYNC
    - 101 VGA_HSYNC
    - 106 VGA_R
    - 105 VGA_G
    - 104 VGA_B
- SDRAM (64 Mb, 4 banks x 1 M x 16 b, HY57V641620FTP-H)
    - 58 SD_CKE
    - 43 SD_CKL
    - 72 SD_CS
    - 71 SD_RAS
    - 70 SD_CAS
    - 69 SD_WE
    - 42 SD_LDQM
    - 55 SD_UDQM
    - 73 SD_BS0
    - 74 SD_BS1
    - 76 S_A0
    - 77 S_A1
    - 80 S_A2
    - 83 S_A3
    - 68 S_A4
    - 67 S_A5
    - 66 S_A6
    - 65 S_A7
    - 64 S_A8
    - 60 S_A9
    - 75 S_A10
    - 59 S_A11
    - 28 S_DQ0
    - 30 S_DQ1
    - 31 S_DQ2
    - 32 S_DQ3
    - 33 S_DQ4
    - 34 S_DQ5
    - 38 S_DQ6
    - 39 S_DQ7
    - 54 S_DQ8
    - 53 S_DQ9
    - 52 S_DQ10
    - 51 S_DQ11
    - 50 S_DQ12
    - 49 S_DQ13
    - 46 S_DQ14
    - 44 S_DQ15

### 7 segment display

     aaa
    f   b
    f   b
     ggg
    e   c
    e   c
     ddd  dp

### Flash programming

1. Quartus / File /Convert Programming Files – configuration device EPCS16, set
   output file name to `output_files/*.pof`, click "SOF Data", click "Add
   File", select `output_files/*.sof` file, click
   "Generate"
1. Programmer – switch mode to "Active Serial Programming", click "Add Device",
   select EPCS16, click device line, click "Change File", select
   `output_files/*.sof` file, check "Program/Configure" and "Verify", click
   "Start"

### Infrared remote control

Uses NEC IR transmission protocol

Button codes:

- 0045 CH-
- 0046 CH
- 0047 CH+
- 0044 <<
- 0040 >>
- 0043 >|
- 0007 -
- 0015 +
- 0009 EQ
- 0016 0
- 0019 FOL- 100+
- 000d FOL+ 200+
- 000c 1
- 0018 2
- 005e 3
- 0008 4
- 001c 5
- 005a 6
- 0042 7
- 0052 8
- 004a 9

## VHDL

Comments start with `--` (like in SQL)

Identifiers case-insensitive, letters, digits (not on the beginning),
underscores (not on the beginning or end, not two adjacent)

## Quartus

Files to be stored in Git [Getting started 2.9.41]

- Logic design files (.v, .vdh, .bdf, .edf, .vqm)
- Timing constraint files (.sdc)
- Quartus project settings and constraints (.qdf, .qpf, .qsf)
- IP files (.ip, .v, .sv, .vhd, .qip, .sip, .qsys)
- Platform Designer (Standard)-generated files (.qsys, .ip, .sip)
- EDA tool files (.vo, .vho )

The top level entity has the same name as the project by default. It can be
changed in _Project Navigator / Settings_.

In order to correctly detect FSM state transitions and show them in State
Machine Viewer, the transitions must be written directly in the process
implementing the transition table and not in a called procedure or function.

### New project checklist

1. Set _Use all available processors_ in _Settings / Compilation Process
   Settings_
1. The default logic for pins is 2.5 V. Change to 3.3 V LVTTL in _Device
   / Device and Pin Options_.

# Glossary

## DUT

Design Under Test

## duty cycle

The ratio of time a signal in ON to the time the signal is OFF

## DUV

Design Under Verification

## FSM

Finite State Machine

## full adder

An adder with input carry and output carry

## half adder

An adder without input carry and with output carry

## test bench (TB)

A piece of VHDL code used to verify functional correctness

## UART

Universal Asynchronous Receiver-Transmitter

## UUT

Unit Under Test
