# Projects

Unless specified otherwise, all projects are for a development kit containing
Altera Cyclone IV EP4CE6E22C8N.

## half_adder

A 1-bit half adder

## led_blink

A counter driven by on-board 50 MHz crystal, with 4 highest (most slowly
changing) bits indicated by LEDs

# Knowledge base

## FPGA

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
