# ADDV Lab 3 – Systolic Matrix Multiplier

## Team Members

- **Rishabh Asati** – rasati@asu.edu
- **Nuralim Otegen** – notegen@asu.edu
- **Isaak Truong** – itruong@asu.edu
- **Tanmai Parshwanath Jain** – tjain126@asu.edu

## Project Overview

Lab 3 implements and extends a systolic matrix multiplication accelerator using SystemVerilog.

The lab is divided into four parts:

1. FP8 E3M4 arithmetic units
2. FP8 4×4 systolic matrix multiplier
3. 8×8 systolic matrix multiplier
4. APB slave interface and system integration

---

## Part 1 – FP8 Arithmetic Units

**Primary contributor:** Rishabh Asati

Part 1 implements the FP8 E3M4 arithmetic units used by the matrix multiplier.

The FP8 format contains:

- 1 sign bit
- 3 exponent bits
- 4 mantissa bits
- Exponent bias = 3

The implementation includes:

- `fp8_adder.sv`
- `fp8_multiplier.sv`
- FP8 arithmetic testbench
- Support for normal FP8 values
- Zero handling
- Infinity and NaN handling
- Overflow and underflow behavior
- Rounding behavior

### Files

```text
PART1/
├── RTL/
│   ├── fp8_adder.sv
│   └── fp8_multiplier.sv
├── TESTBENCH/
│   ├── fp8_arithmetic_tb.sv
│   └── matmul_with_ram_tb.sv
└── env.cshrc
```

---

## Part 2 – FP8 4×4 Systolic Matrix Multiplier

**Primary contributor:** Nuralim Otegen

Part 2 integrates the FP8 E3M4 arithmetic units from Part 1 into the provided 4×4 systolic matrix multiplier.

The original integer MAC arithmetic was replaced with:

- `fp8_multiplier`
- `fp8_adder`

Each processing element performs an FP8 multiply-accumulate operation.

Exception handling was also added. The exception outputs from the FP8 multiplier and adder are ORed together within each MAC. The exception outputs from all 16 processing elements are then combined into a single exception output for the systolic matrix multiplier.

### Verification

Two primary FP8 matrix multiplication scenarios were verified:

**Normal FP8 operation**

- Matrix A: identity matrix
- Matrix B: FP8 values representing 1.0 (`8'h30`)
- Expected output: `0x30303030`
- Exception: deasserted

**FP8 exception operation**

- Infinity input: `8'h70`
- Zero input: `8'h00`
- Expected NaN output: `8'h78`
- Output word: `0x78787878`
- Exception: asserted

Simulation and waveform verification were performed using Synopsys VCS and Verdi.

### Synthesis

Both the original integer baseline and FP8 implementations were synthesized using the same technology and timing constraints.

| Design | Total Cell Area | Critical Path | Approx. Fmax |
|---|---:|---:|---:|
| Integer baseline | 24,803.91 µm² | 0.94 ns | ≈ 1063.8 MHz |
| FP8 | 60,604.93 µm² | 1.99 ns | ≈ 502.5 MHz |

The FP8 implementation increased the total cell area by approximately 144.3% and reduced the approximate maximum operating frequency by 52.8% compared with the integer baseline.

### Files

```text
PART2/
├── RTL/
│   ├── apb_slave.sv
│   ├── fp8_adder.sv
│   ├── fp8_multiplier.sv
│   ├── matmul.sv
│   └── matmul_with_ram.sv
├── TESTBENCH/
│   ├── example_tb.sv
│   └── matmul_with_ram_tb.sv
├── SYNTHESIS/
│   ├── FP8/
│   └── INTEGER/
└── env.cshrc
```

---

## Part 3 – 8×8 Systolic Matrix Multiplier

**Primary contributor:** Tanmai Parshwanath Jain

Part 3 extends the matrix multiplier architecture from 4×4 to 8×8.

The 8×8 design is constructed using four 4×4 systolic matrix multiplier blocks. The tiles are interconnected so that matrix data can propagate correctly between neighboring blocks.

Part 3 includes:

- 8×8 systolic matrix multiplier integration
- Interconnection of four 4×4 systolic blocks
- RAM interface integration
- Functional simulation and verification
- Synthesis and implementation reports

See the `PART3` directory for the RTL, testbench, synthesis files, and generated reports.

---

## Part 4 – APB Slave Interface

**Primary contributor:** Isaak Truong

Part 4 integrates an APB slave interface with the FP8 E3M4 8×8 systolic matrix multiplier.

The APB interface provides software-visible control and status registers for:

- Starting matrix multiplication
- Matrix A, B, and C starting addresses
- Matrix address strides
- Completion status
- Busy status
- Floating-point exception status

The APB interface uses 16-bit data registers and supports the standard APB setup and access phases.

The controller manages IDLE, PREP, and RUN states. Exception status is preserved so that software can read the result even after a transient exception signal has deasserted.

Verification includes APB register reads and writes, matrix execution, status polling, exception checking, and output RAM verification.

See the `PART4` directory for the RTL, testbench, tools, vectors, verification files, and Makefile.

---

## Tools Used

The project was developed and verified using:

- SystemVerilog
- Synopsys VCS
- Synopsys Verdi
- Synopsys Design Compiler
- OSU FreePDK 45 nm standard-cell library
- Git / GitHub

Additional verification tools may be included in the individual part directories where applicable.

---

## Repository Structure

```text
ADDV-Lab3/
├── PART1/
│   ├── RTL/
│   └── TESTBENCH/
├── PART2/
│   ├── RTL/
│   ├── TESTBENCH/
│   └── SYNTHESIS/
├── PART3/
└── PART4/
    ├── rtl/
    ├── tb/
    ├── tools/
    ├── vectors/
    └── verification/
```

---

## Part 2 Simulation

Load the Synopsys environment before compiling.

Example VCS compilation:

```bash
vcs -full64 -sverilog -debug_access+all -kdb \
RTL/fp8_adder.sv \
RTL/fp8_multiplier.sv \
RTL/matmul.sv \
RTL/matmul_with_ram.sv \
TESTBENCH/matmul_with_ram_tb.sv \
-o simv
```

Run the simulation:

```bash
./simv
```

The Part 2 regression should report successful normal FP8 matrix multiplication and exception handling.

Waveforms can be viewed using Verdi:

```bash
verdi -ssf novas.fsdb &
```

---

## Contributions

- **Rishabh Asati:** Part 1 – FP8 E3M4 arithmetic units
- **Nuralim Otegen:** Part 2 – FP8 4×4 systolic matrix multiplier integration, exception propagation, verification, synthesis comparison, and report results
- **Tanmai Parshwanath Jain:** Part 3 – 8×8 systolic matrix multiplier
- **Isaak Truong:** Part 4 – APB slave interface and system integration
