# Lab 3 Part 4: context and implementation plan using the team's Part 3

## Current scope

Isaak's assignment is **Part 4: the APB slave interface**. The team has now supplied its actual Part 3 source. This revision integrates that `matmul_8x8_systolic` implementation into Part 4; it replaces the earlier companion-array approach.

The combined project preserves the uploaded `PART1`, `PART2`, and `PART3` directories and adds a separate `PART4` directory. Compile Part 4 using its own file list. Do not compile every `.sv` file across all parts together, because the earlier parts intentionally contain duplicate module names.

Part 4 uses exact copies of the team's `fp8_adder.sv`, `fp8_multiplier.sv`, and 4x4 `matmul.sv`. Two integration fixes are isolated to its copied `matmul_8x8.sv`: correcting the two operand inputs of the bottom-right tile and limiting each C-bank output-valid stream to eight words. The team's two-stride C-address compensation and independent 8x8 completion counter are retained. The original Part 3 source and synthesis outputs remain available for comparison.

## How the parts fit together

| Part | Responsibility | Current supplied status | Relationship to Part 4 |
| --- | --- | --- | --- |
| 1 | FP8 E3M4 arithmetic | Adder, multiplier, and arithmetic testbench supplied | Defines arithmetic results and combined exception behavior |
| 2 | 4x4 FP8 systolic tile | RTL, testbench, report, and synthesis reports supplied | The tile and arithmetic are reused unchanged |
| 3 | Four tiles forming an 8x8 array | Actual team RTL, RAM wrapper, two-case testbench, README, and synthesis outputs supplied | Its 8x8 array is the basis for this integration |
| 4 | APB control/status and integrated verification | Implemented in the new PART4 directory | Isaak's assigned work |

The delivered team-based integration has passed eight local Verilator 5.006 jobs covering 512 unique outputs, and a separate focused 64-output exception run. Four dense-case signed-zero encodings are accepted only as the documented `0x00`/`0x80` numerical equivalence; all other result encodings and flags match exactly. Its observed interval is 35 core-active edges through sticky DONE. Use `verification/SUMMARY.md` for the complete evidence and boundaries. The old companion-array timing/results are not substituted for this revision, and Apporto VCS/Verdi evidence remains separate.

## What the assignment requires for Part 4

The primary rubric is `Lab #3_ Systolic Matrix Multiplier - Fall 2026.pdf`, pages 7–10:

1. Add APB control to the FP8 **8x8** matrix multiplier.
2. Expose `PCLK`, `PRESETn`, `PADDR`, `PWRITE`, `PSEL`, `PENABLE`, `PWDATA`, `PRDATA`, and `PREADY`.
3. Use 16-bit APB data and CSRs. Address-bus width and register mapping are design choices.
4. Provide writable start and A/B/C base/stride controls, plus readable done and flags.
5. Test by initializing matrices, programming the six address/stride registers, writing start, polling done through APB, and checking results.
6. Adapt the supplied APB read/write tasks and test several matrix contents, including an exception case.
7. Include visible SystemVerilog syntax. A specific interface or enum construct is not mandatory.

Always-high `PREADY` is explicitly allowed. The rubric does not require an interrupt, an APB matrix-data window, or new Part 4 synthesis results. Matrix data continues to use external RAM ports, as in the lecture hierarchy (`14_Lab3_Release.pdf`, pages 21–27).

### Report and waveform deliverables

| Required item | Evidence |
| --- | --- |
| Description of changes | APB slave, CSRs, launch/preparation control, completion/exception storage, integration with the real array |
| Register map | Address, access type, meaningful bits, and reset value |
| Configuration writes | APB setup/access phases and completed writes |
| Configured controls | Stored base addresses/strides and the accepted start/run sequence |
| Running multiplier | Held run enable, array activity, and output writes |
| Done and exception | Completion after result storage and asserted exception status |
| Status reads | Separate APB reads of done and flags in the exception case |

Capture actual simulator waveforms and annotate them by hand or digital pen. A passing bus-only test is useful evidence of the controller, but does not replace an integrated matrix run or the requested waveform screenshots.

## Architecture of this revision

`apb_matmul_csr` implements the software-visible control/status interface. `matmul_apb_top` connects it to `matmul_8x8_with_ram`. That RAM adapter instantiates the team's `matmul_8x8_systolic`, with the two documented fixes, and six byte-enabled 32-bit RAM banks.

The team's original RAM wrapper exposes six separate 32-bit external interfaces. Part 4 presents a 64-bit view per matrix by combining corresponding bank words as `{bank1, bank0}`. This is an adapter choice for loading and checking matrices; it does not change the internal bank organization or the 16-bit APB interface.

The earlier wrapper's start FSM is replaced by the APB controller's job lifecycle. An accepted software START enters a preparation cycle that resets the PEs/control, then RUN holds the core enable high. The controller records the team's completion indication after the result write window has finished. Two per-bank counters suppress writes after eight valid output words. DONE and FLAGS remain readable until reset or another accepted START.

## Register contract

All offsets are **APB byte addresses**. Base/stride contents are **RAM word addresses/increments**.

| Offset | Register | Access | Fields | Reset |
| --- | --- | --- | --- | --- |
| `0x00` | CONTROL | Write command; read zero | Bit 0: write one to start when idle | 0 |
| `0x02` | STATUS | Read-only | Bit 0: sticky DONE; bit 1: BUSY | 0 |
| `0x04` | FLAGS | Read-only | Bit 0: sticky combined arithmetic exception | 0 |
| `0x10` | ADDR_A | Read/write while idle | Bits 9:0: A RAM base | 0 |
| `0x12` | ADDR_B | Read/write while idle | Bits 9:0: B RAM base | 0 |
| `0x14` | ADDR_C | Read/write while idle | Bits 9:0: C RAM base | 0 |
| `0x16` | STRIDE_A | Read/write while idle | Bits 7:0: A word increment | 1 |
| `0x18` | STRIDE_B | Read/write while idle | Bits 7:0: B word increment | 1 |
| `0x1A` | STRIDE_C | Read/write while idle | Bits 7:0: C word increment | 1 |

Reserved read bits are zero. Unmapped/odd reads return zero; writes to those addresses or read-only registers do nothing. Configuration and repeated START writes while BUSY complete on APB but are ignored. Reads have no side effects.

A write changes a CSR only at a rising edge with `PSEL && PENABLE && PREADY && PWRITE` while reset is released. Setup alone does not write. Read data is combinational so it is valid before the zero-wait access completes.

The arithmetic interface contains one combined exception bit. FLAGS reports whether any exception occurred; it does not separately identify overflow, underflow, or invalid operation.

## Why two small array fixes are included

### Bottom-right operands

The source's location controls make `matmul_01` the mathematical bottom-left tile and `matmul_10` the top-right tile. The uploaded bottom-right instance instead received A from the top-right and B from the bottom-left. Uniform matrices can hide that error. The copied Part 4 array connects its A input to the bottom-left tile's A output and its B input to the top-right tile's B output.

### Output-write window

The inherited tile's output-valid signal can stay high beyond eight useful words because the team generates its final completion separately. Part 4 limits each C-bank stream to eight valid writes, preserving memory after the result matrix. The integrated testbench checks both the output words and a guard word immediately afterward.

These fixes do not alter the FP8 arithmetic or the 4x4 tile. They are recorded separately from the original source so the team can review them. See `PART3_HANDOFF.md` and `SOURCE_PROVENANCE.md` for the exact boundary and provenance.

## Implementation and verification phases

### 1. Use the actual team array

Keep the supplied arithmetic and 4x4 tile unchanged, map the real `matmul_8x8_systolic` ports, retain its timing/address convention, and isolate the two array corrections. Keep the original parts alongside Part 4 for comparison.

### 2. Preserve the APB controller contract

Check reset defaults, readback, setup/access handling, protected configuration, write-one start, preparation reset, held run, sticky done, and operation-gated exception storage. The controller can be checked independently with controlled done/exception inputs; those unit checks are distinct from arithmetic verification.

### 3. Run the integrated team-based regression

Program every job through APB and check all 64 outputs. Include nonuniform identity/permutation cases, dense signed arithmetic, invalid-operation/overflow/underflow cases, different bases and strides, and a clean job after exceptions without global reset. Check exactly eight C writes per bank, address sequence, status clearing, and guard-word preservation. Record the measured timing of this revision rather than reusing earlier companion-array timings.

### 4. Finish required Part 4 evidence on Apporto

Run `make compile`, `make sim CASE=all`, and `make sim CASE=exception` from `ADDV-Lab3-main/PART4`. Preserve the simulator output and FSDB, open Verdi, and annotate the required configuration/run/status-read views. Follow `APPORTO_WALKTHROUGH.md` for the exact commands and hierarchy.

### 5. Coordinate optional Part 3 follow-up separately

The corrected copied array can be reviewed with the Part 3 owner and, if adopted there, verified and synthesized as that new Part 3 revision. Existing Part 3 synthesis reports describe the uploaded array, not this corrected copy. This source/reports reconciliation is a team follow-up; it must not be confused with an extra Part 4 synthesis requirement.

## Evidence and report cautions

The actual uploaded Part 3 contains source, a two-case testbench, README, mapped netlist/SDC, and synthesis reports. Its directory does not include the claimed VCS run logs, FSDB, or annotated screenshots. The original two uniform cases have been reproduced locally with Verilator using the original RTL; their passing outputs do not establish nonuniform correctness or absence of extra output writes.

The README's area and bandwidth values need reconciliation with the raw reports. The 4x4 and 8x8 reports use the same `gscl45nm` library but different timing targets. The 8x8 SDC's output loads differ from the current synthesis script, and its reports contain capacitance violations. These are facts to resolve for the Part 3 comparison; do not copy them into Part 4 as new synthesis results.

## Sources

- Lab 3 assignment, pp. 5–7: Part 3 structure and evidence; pp. 7–10: Part 4 APB requirements and rubric.
- Lab 3 release slides, pp. 14–17 and 21–28: FP8, exception aggregation, CSR integration, and task-based APB testing.
- Uploaded team `PART3/RTL`, `TESTBENCH`, `README.md`, and `synth`: actual integration baseline and original claims/reports.
- Uploaded team `PART2/SYNTHESIS/FP8`: original 4x4 area/timing evidence.
- `IHI0024b.pdf`: APB transfer phases and clock-edge timing.
