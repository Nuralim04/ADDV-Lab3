# Part III — 8×8 FP8 Systolic Matrix Multiplier

## Overview

This project implements an **8×8 FP8 systolic matrix multiplier** by interconnecting four **4×4 FP8 systolic matrix multiplier** blocks developed in Part II.

The design uses FP8 E3M4 arithmetic for the multiply-accumulate operations. Four 4×4 systolic blocks are connected using their `a_data_out/a_data_in`, `b_data_out/b_data_in`, and `c_data_out/c_data_in` interfaces to form the larger 8×8 architecture.

The design was simulated using Synopsys VCS/Verdi and synthesized using Synopsys Design Compiler.

---

## Design Architecture

The 8×8 systolic multiplier contains four 4×4 FP8 systolic multiplier blocks:

| Block | `a_loc` | `b_loc` |
|---|---:|---:|
| M00 | 0 | 0 |
| M01 | 1 | 0 |
| M10 | 0 | 1 |
| M11 | 1 | 1 |

For all four blocks:

- `MAT_MUL_SIZE = 4`
- `final_mat_mul_size = 8`
- The matrix base addresses are shared.
- The matrix address strides are shared.
- The validity masks are tied to their default valid values.

### Inter-Matmul Connections

A-data is propagated between neighboring blocks through:

```text
M00.a_data_out -> M01.a_data_in
M10.a_data_out -> M11.a_data_in
```

B-data is propagated through:

```text
M00.b_data_out -> M10.b_data_in
M01.b_data_out -> M11.b_data_in
```

The C result data is daisy-chained from the lower blocks to the upper blocks:

```text
M10.c_data_out -> M00.c_data_in -> C RAM 0
M11.c_data_out -> M01.c_data_in -> C RAM 1
```

The FP8 exception outputs from all four 4×4 blocks are ORed together to generate the global 8×8 exception output.

---

## Memory Organization

The 8×8 design uses six dual-port RAM blocks:

```text
Matrix A:
    A RAM 0
    A RAM 1

Matrix B:
    B RAM 0
    B RAM 1

Matrix C:
    C RAM 0
    C RAM 1
```

Each RAM data interface is **32 bits wide**, corresponding to four FP8 values per RAM word.

The first RAM port is used by the matrix multiplier, while the second port is available to the testbench/external interface for initialization and readback.

---

## Project Structure

```text
PART3/
|
|-- RTL/
|   |-- fp8_adder.sv
|   |-- fp8_multiplier.sv
|   |-- matmul.sv
|   |-- matmul_8x8.sv
|   `-- matmul_with_ram.sv
|
|-- TESTBENCH/
|   `-- matmul_with_ram_tb.sv
|
|-- sim/
|   `-- Makefile
|
|-- synth/
|   |-- Makefile
|   |-- compile_dc.tcl
|   |-- area.rep
|   |-- timing.rep
|   |-- power.rep
|   `-- other synthesis reports
|
|-- env.cshrc
`-- README.md
```

---

## RTL Files

### `fp8_adder.sv`

Implements the FP8 E3M4 floating-point adder used by each processing element.

### `fp8_multiplier.sv`

Implements the FP8 E3M4 floating-point multiplier used by each processing element.

### `matmul.sv`

Contains the Part II FP8 4×4 systolic matrix multiplier.

The original integer multiply and add operations are replaced by the FP8 multiplier and FP8 adder.

### `matmul_8x8.sv`

Implements the 8×8 systolic multiplier by instantiating and interconnecting four `matmul_4x4_systolic` blocks.

This module also:

- Connects neighboring A and B data paths.
- Chains the C output data.
- Combines FP8 exception signals.
- Provides 8×8 completion timing.
- Generates the interfaces for two A, two B, and two C memory banks.

### `matmul_with_ram.sv`

Top-level simulation wrapper containing:

- Two A RAM blocks.
- Two B RAM blocks.
- Two C RAM blocks.
- Control FSM.
- `matmul_8x8_systolic` instance.

### `matmul_with_ram_tb.sv`

Testbench used to initialize the input matrices, start the matrix multiplication, verify the output matrices, perform RAM readback, and generate the FSDB waveform file.

---

## Simulation

Simulation is performed using **Synopsys VCS**.

From the `sim/` directory:

```bash
make clean
make compile
./simv
```

The simulation generates:

```text
matmul_8x8.fsdb
```

which can be opened using Synopsys Verdi for waveform analysis.

---

## Verification

Two functional test cases are included.

### Test 1 — All Ones

```text
A = 8×8 matrix containing 1.0
B = 8×8 matrix containing 1.0
```

FP8 representation:

```text
1.0 = 8'h30
```

Therefore each 32-bit input RAM word is:

```text
32'h30303030
```

Each output element is:

```text
C[i][j] = 8 × 1.0 × 1.0 = 8.0
```

FP8 representation:

```text
8.0 = 8'h60
```

Expected output RAM word:

```text
32'h60606060
```

Both C RAM banks are checked at addresses 0 through 7.

**Result: PASS**

---

### Test 2 — 0.5 × 1.0

```text
A = 8×8 matrix containing 0.5
B = 8×8 matrix containing 1.0
```

FP8 representations:

```text
0.5 = 8'h20
1.0 = 8'h30
```

Each output element is:

```text
C[i][j] = 8 × 0.5 × 1.0 = 4.0
```

FP8 representation:

```text
4.0 = 8'h50
```

Expected output RAM word:

```text
32'h50505050
```

Both C RAM banks are checked at addresses 0 through 7.

**Result: PASS**

---

## RAM Readback Verification

After Test 1, the testbench reads addresses 0 through 7 of all six RAM banks through their external interfaces.

Expected input RAM contents:

```text
A RAM 0 = 30303030
A RAM 1 = 30303030

B RAM 0 = 30303030
B RAM 1 = 30303030
```

Expected output RAM contents:

```text
C RAM 0 = 60606060
C RAM 1 = 60606060
```

The RAM readback is also captured in the Verdi waveform for verification.

---

## Synthesis

Only the `matmul_8x8_systolic` module is synthesized for Part III. The RAM/control wrapper and testbench are not included in the synthesis top level.

The synthesis source files include:

```text
fp8_adder.sv
fp8_multiplier.sv
matmul.sv
matmul_8x8.sv
```

### Synthesis Results

| Design | Total Cell Area (µm²) | Critical Path (ns) | Approx. Fmax (MHz) |
|---|---:|---:|---:|
| FP8 4×4 Systolic Matmul | 60,604.93 | 1.99 | ≈ 502.5 |
| FP8 8×8 Systolic Matmul | 238,513.74 | ≈ 8.00 | ≈ 125.0 |

The 8×8 design occupies approximately **3.94×** the cell area of the 4×4 FP8 design. This is consistent with increasing the systolic array from 16 processing elements to 64 processing elements.

The larger interconnected architecture also results in a longer critical path and therefore a lower approximate maximum operating frequency.

---

## Performance Characteristics

### Peak Read Bandwidth

Two 32-bit RAM words can be read in parallel:

```text
2 × 32 bits = 64 bits/cycle
```

Therefore:

**Peak read bandwidth = 64 bits/cycle (8 FP8 values/cycle).**

### Peak Write Bandwidth

Two 32-bit C RAM words can be written in parallel:

```text
2 × 32 bits = 64 bits/cycle
```

Therefore:

**Peak write bandwidth = 64 bits/cycle (8 FP8 values/cycle).**

### Matrix Multiplication Latency

The complete 8×8 operation, including computation and result shift-out, requires:

**34 clock cycles.**

### Number of MAC Operations

An 8×8 matrix multiplication generates 64 output elements.

Each output element requires 8 MAC operations:

```text
64 × 8 = 512
```

Therefore:

**Total MAC operations per 8×8 matrix multiplication = 512.**

The physical 8×8 systolic array contains 64 processing elements, which collectively evaluate these 512 MAC operations over the complete matrix multiplication.

---

## Waveform Verification

The Verdi waveform was used to verify the following events:

1. Input data being read from the A/B RAMs into the systolic multiplier.
2. FP8 operand data propagating between neighboring 4×4 matmul blocks.
3. Valid C result data being written from the multiplier into the output RAM.
4. Complete input matrix contents stored in the A and B RAM banks.
5. Complete output matrix contents stored in the C RAM banks after computation.

For Test 1:

```text
Input FP8 value  = 0x30 = 1.0
Output FP8 value = 0x60 = 8.0
```

The simulation confirms the expected output matrix and completes without an FP8 exception for the normal test cases.

---

## Summary

The Part III design successfully scales the Part II FP8 4×4 systolic matrix multiplier into an **8×8 FP8 systolic matrix multiplier** using four interconnected 4×4 blocks.

The implementation:

- Uses SystemVerilog constructs.
- Preserves `MAT_MUL_SIZE = 4`.
- Uses four FP8 4×4 systolic multiplier blocks.
- Connects neighboring blocks through A, B, and C data paths.
- Uses two RAM banks per matrix.
- Propagates and combines FP8 exception flags.
- Passes two 8×8 functional simulation test cases.
- Supports RAM readback for waveform verification.
- Has been synthesized as an independent 8×8 matmul core.