# Projects

Unless specified otherwise, all projects are for a development kit containing
Altera Cyclone IV EP4CE6E22C8N.

## full_adder

A 1-bit full adder

## half_adder

A 1-bit half adder

## led_blink

A counter driven by on-board 50 MHz crystal, with 4 highest (most slowly
changing) bits indicated by LEDs

# Knowledge base

## FPGA

FPGA __Altera Cyclone IV EP4CE6E22C8N__

Kit __RZ-EasyFPGA A2.2__

- 87 LED1
- 86 LED2
- 85 LED3
- 84 LED4
- 88 S1 (KEY1)
- 89 S2 (KEY2)
- 90 S3 (KEY3)
- 91 S4 (KEY4)

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
