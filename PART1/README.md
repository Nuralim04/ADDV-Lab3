# Part I — FP8 Arithmetic Unit Verification

## Overview

This project implements and verifies the two core FP8 E3M4 arithmetic building blocks for the matrix-multiply datapath:

- `fp8_adder.sv`
- `fp8_multiplier.sv`

The design is validated with a self-checking SystemVerilog testbench that exercises a set of representative add and multiply cases, including edge conditions such as zero, infinity, NaN, rounding, and underflow.

---

## Design Files

### `RTL/fp8_adder.sv`

Implements the FP8 E3M4 floating-point adder.

Features:
- Signed zero handling
- Infinity and NaN propagation
- Rounding to nearest, ties to even
- Denormal flush-to-zero behavior

### `RTL/fp8_multiplier.sv`

Implements the FP8 E3M4 floating-point multiplier.

Features:
- Signed zero handling
- Infinity and NaN propagation
- Rounding to nearest, ties to even
- Underflow handling

### `TESTBENCH/fp8_arithmetic_tb.sv`

Self-checking testbench for both arithmetic units.

It applies a series of directed test vectors covering:
- simple finite arithmetic
- signed values
- zero cases
- overflow and underflow
- NaN propagation
- rounding behavior

---

## Project Structure

```text
PART1/
|
|-- RTL/
|   |-- fp8_adder.sv
|   `-- fp8_multiplier.sv
|
|-- TESTBENCH/
|   `-- fp8_arithmetic_tb.sv
|
|-- sim/
|   `-- Makefile
|
|-- env.cshrc
`-- README.md
```

---

## Simulation

From the `sim/` directory, run:

```bash
make clean
make compile
./simv
```

Or simply:

```bash
make run
```

This compiles the design and executes the FP8 arithmetic testbench.

---

## Verdi / Waveform Viewing

To compile the design with debug support and open it in Synopsys Verdi:

```bash
make compile_verdi
make verdi
```

To run the simulation and launch the waveform viewer with the generated FSDB file:

```bash
make waves_verdi
```

The waveform output is generated as:

```text
fp8_arithmetic.fsdb
```

---

## Expected Result

The testbench prints a pass/fail summary for all add and multiply cases. A successful simulation ends with a message indicating that all FP8 arithmetic tests passed without any mismatches.
