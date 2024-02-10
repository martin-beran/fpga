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

### lib/infrared

A receiver for infrared control

### lib/util

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

## full_adder

A 1-bit full adder

## half_adder

A 1-bit half adder

## hex_counter_7seg

A counter displaying a hexadecimal value on 7-segment LED

## infrared_rcv

A receiver for infrared control. It displays received codes. It demonstrates
using library `infrared`.

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

- 23 FPGA_CLK 50 MHz
- 87 LED1
- 86 LED2
- 85 LED3
- 84 LED4
- 88 S1 (KEY1)
- 89 S2 (KEY2)
- 90 S3 (KEY3)
- 91 S4 (KEY4)
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
- 110 BEEP (speaker)

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

### New project checklist

1. Set _Use all available processors_ in _Settings / Compilation Process
   Settings_
1. The default logic for pins is 2.5 V. Change to 3.3 V LVTTL in _Device
   / Device and Pin Options_.

# Glossary

## DUT

Design Under Test

## DUV

Design Under Verification

## full adder

An adder with input carry and output carry

## half adder

An adder without input carry and with output carry

## test bench (TB)

A piece of VHDL code used to verify functional correctness

## UUT

Unit Under Test
