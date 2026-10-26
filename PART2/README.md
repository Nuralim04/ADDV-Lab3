# Part 2 – FP8 4×4 Systolic Matrix Multiplier

## Overview

Part 2 integrates the FP8 E3M4 arithmetic units developed in Part 1 into the provided 4×4 systolic matrix multiplier.

The original integer MAC arithmetic in `matmul.sv` was replaced with the FP8 multiplier and FP8 adder. The original systolic array architecture and data flow between processing elements were retained.

Exception handling was also added throughout the systolic array.

## Design Changes

The following changes were made in `matmul.sv`:

- Replaced the integer multiplication operation with `fp8_multiplier`.
- Replaced the integer addition operation with `fp8_adder`.
- Combined the multiplier and adder exception signals using a logical OR.
- Added an exception output to each processing element.
- Combined the exception signals from all 16 processing elements into a single exception output for `matmul_4x4_systolic`.
- Updated the MAC timing configuration for the combinational FP8 arithmetic implementation.

The provided `matmul_with_ram.sv` architecture was not modified for the Part 2 implementation.

## RTL Files

```text
RTL/
├── fp8_adder.sv
├── fp8_multiplier.sv
├── matmul.sv
├── matmul_with_ram.sv
└── apb_slave.sv
```

The main files used for Part 2 are:

- `fp8_adder.sv` – FP8 E3M4 adder from Part 1.
- `fp8_multiplier.sv` – FP8 E3M4 multiplier from Part 1.
- `matmul.sv` – modified 4×4 systolic matrix multiplier containing the FP8 MAC integration.
- `matmul_with_ram.sv` – provided matrix multiplier wrapper and RAM/control logic.

`apb_slave.sv` is included in the provided RTL directory but is not used for the Part 2 FP8 matrix multiplier implementation.

## Testbench

The Part 2 verification testbench is:

```text
TESTBENCH/matmul_with_ram_tb.sv
```

Two main FP8 matrix multiplication cases are tested.

### Test 1 – Normal FP8 Operation

Matrix A is configured as an identity matrix and Matrix B contains FP8 values representing `1.0`.

FP8 encoding:

```text
1.0 = 8'h30
```

Expected result:

```text
0x30303030
```

The combined exception signal is expected to remain deasserted.

### Test 2 – FP8 Exception Operation

The second test exercises the invalid infinity-times-zero operation.

FP8 encodings:

```text
Infinity = 8'h70
Zero     = 8'h00
NaN      = 8'h78
```

Expected result:

```text
0x78787878
```

The combined exception signal is expected to assert.

## Simulation

The design was compiled and simulated using Synopsys VCS.

From the `PART2` directory, load the provided Synopsys environment and compile using:

```bash
vcs -full64 -sverilog -debug_access+all -kdb \
RTL/fp8_adder.sv \
RTL/fp8_multiplier.sv \
RTL/matmul.sv \
RTL/matmul_with_ram.sv \
TESTBENCH/matmul_with_ram_tb.sv \
-o simv
```

Run the simulation with:

```bash
./simv
```

A successful regression reports:

```text
PASS: Normal FP8 matrix multiplication
PASS: FP8 exception asserted
PASS: All Part 2 FP8 tests passed
```

## Waveform Verification

The simulation generates an FSDB waveform database that can be opened using Synopsys Verdi:

```bash
verdi -ssf novas.fsdb &
```

The waveforms were used to verify:

- Input matrix RAM activity
- `start` assertion
- `done` assertion
- FP8 exception behavior
- Output data
- Output RAM writes

For the normal test, the exception signal remains low and the output is `0x30303030`.

For the exception test, the exception signal asserts and the NaN output is `0x78787878`.

## Synthesis

The baseline integer design and the FP8 design were synthesized separately using Synopsys Design Compiler and the OSU FreePDK 45 nm standard-cell library.

Only the `matmul_4x4_systolic` module was used as the synthesis top-level module.

The same synthesis constraints were used for both designs to provide a consistent comparison.

### Synthesis Results

| Design | Total Cell Area | Critical Path | Approx. Fmax |
| --- | ---: | ---: | ---: |
| Integer baseline | 24,803.91 µm² | 0.94 ns | ≈ 1063.8 MHz |
| FP8 | 60,604.93 µm² | 1.99 ns | ≈ 502.5 MHz |

Compared with the integer baseline, the FP8 implementation increased the total cell area by approximately 144.3% and reduced the approximate maximum operating frequency by approximately 52.8%.

The synthesis reports are located under:

```text
SYNTHESIS/
├── INTEGER/
│   ├── area.rep
│   ├── clock.rep
│   ├── power.rep
│   └── timing.rep
└── FP8/
    ├── area.rep
    ├── clock.rep
    ├── power.rep
    └── timing.rep
```

## Tools Used

- SystemVerilog
- Synopsys VCS
- Synopsys Verdi
- Synopsys Design Compiler
- OSU FreePDK 45 nm standard-cell library

## Contributor

**Nuralim Otegen**

Implemented the Part 2 FP8 systolic matrix multiplier integration, exception propagation, testbench verification, VCS/Verdi simulation and waveform analysis, synthesis comparison, and Part 2 report results.
