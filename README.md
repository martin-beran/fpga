# Projects

Unless stated otherwise, all projects are:

- implemented in VHDL 
- intended for a development kit containing Altera Cyclone IV EP4CE6E22C8N

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
        - when setting: switches between HH and MM
    - Button2:
        - when viewing: enables/disables the alarm
        - when setting: increases the currently selected value
    - Button3:
        - when viewing: enables/disables the alarm
        - when setting: decreases the currently selected value
    - Button4: set
        - long press switches from view to set mode
        - switches from set to view mode and sets seconds to 00 
    - any button: stops a sounding alarm

## full_adder

A 1-bit full adder

## half_adder

A 1-bit half adder

## #hex_counter_7seg

A counter displaying a hexadecimal value on 7-segment LED

## led_blink

A counter driven by on-board 50 MHz crystal, with 4 highest (most slowly
changing) bits indicated by LEDs. Defined by a block diagram.

## led_blink_vhdl

Alternatively blinking LEDs controlled by a counter driven by the on-board 50
MHz crystal.

# Knowledge base

## FPGA

FPGA __Altera Cyclone IV EP4CE6E22C8N__

Kit __RZ-EasyFPGA A2.2__

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

## Glossary

### DUT

Design Under Test

### DUV

Design Under Verification

### full adder

An adder with input carry and output carry

### half adder

An adder without input carry and with output carry

### test bench (TB)

A piece of VHDL code used to verify functional correctness

### UUT

Unit Under Test
