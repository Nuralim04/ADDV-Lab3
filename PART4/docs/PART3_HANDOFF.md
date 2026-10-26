# Team Part 3 to Part 4 integration handoff

## What is integrated now

Part 4 now uses the actual uploaded team `matmul_8x8_systolic` array. It no longer depends on the earlier companion 8x8 implementation. The combined deliverable preserves the original `PART1`, `PART2`, and `PART3` directories and adds `PART4`.

Part 4 copies `fp8_adder.sv`, `fp8_multiplier.sv`, and the 4x4 `matmul.sv` exactly. Only its copied `matmul_8x8.sv` receives the two integration fixes described below. Its new APB controller and RAM adapter replace the original RAM wrapper's direct-control FSM. See `SOURCE_PROVENANCE.md` for file hashes and recorded changes.

## Correct interpretation of the tile names

The uploaded comments call `matmul_01` top-right and `matmul_10` bottom-left. The actual location-control behavior determines the mathematical quadrants:

| Instance | Output rows | Output columns | `a_loc` | `b_loc` |
| --- | --- | --- | --- | --- |
| `matmul_00` | 0–3 | 0–3 | 0 | 0 |
| `matmul_01` | 4–7 | 0–3 | 1 | 0 |
| `matmul_10` | 0–3 | 4–7 | 0 | 1 |
| `matmul_11` | 4–7 | 4–7 | 1 | 1 |

A tile takes A directly from RAM when `b_loc==0`, otherwise from its A neighbor input. It takes B from RAM when `a_loc==0`, otherwise from its B neighbor input. Thus `a_loc` identifies the tile row and `b_loc` its column. Keep the team's instance names, but explain diagrams using explicit row/column ranges.

Correct useful transfers are:

| Stream | Connections |
| --- | --- |
| A, moving across columns | `matmul_00` to `matmul_10`; `matmul_01` to `matmul_11` |
| B, moving across rows | `matmul_00` to `matmul_01`; `matmul_10` to `matmul_11` |
| C, draining into bank 0 | `matmul_10` to `matmul_00` to C0 |
| C, draining into bank 1 | `matmul_11` to `matmul_01` to C1 |

Some apparently connected inputs are ignored by their tile's source mux. A diagram should show the paths the hardware actually uses, rather than simply every wire mentioned in the README.

## Two corrections isolated to Part 4's copied array

### 1. Bottom-right operand sources

In the upload, `matmul_11.a_data_in` is driven by the A stream leaving `matmul_10`, while `matmul_11.b_data_in` is driven by the B stream leaving `matmul_01`. Those are the wrong mathematical neighbors. The required sources are A from `matmul_01` and B from `matmul_10`.

The copied Part 4 array changes those two inputs to the signals `a_from_bottom_left` and `b_from_top_right`. This preserves all four existing 4x4 tiles and arithmetic. The original uniform input tests can pass despite wrong data routing because every lane carries the same value; nonuniform matrix tests are needed to expose the issue.

### 2. Bound each C stream to eight valid writes

The unchanged 4x4 tile asserts its own early done pulse and later produces an 8x8 result stream. The team's 8x8 wrapper intentionally ignores those early done outputs and supplies a separate final done counter. The tile's output-valid signal therefore stays high beyond the eight useful result words.

The copied array adds one four-bit output-word counter per C bank. Counters reset between jobs, advance with valid output words, and saturate at eight. Each public C-valid output is gated off once eight words have been accepted. This prevents a ninth or later write from corrupting memory beyond the result region. The outer RAM adapter also suppresses writes during reset and when the run enable is low.

These are integration fixes, not a redesign of the arithmetic. The original files remain preserved. Compare the generated patch and regression evidence before incorporating the same fixes into the team's Part 3 directory.

An independent nonuniform replay using the original team RAM wrapper reported 16 result mismatches, six changed guard words, and 11 writes per C bank with the original array. Replacing only the array with the corrected copy produced zero result mismatches, zero guard changes, and exactly eight writes per bank. This isolates the corrected behavior from the APB controller. The new full APB integration also passed eight jobs covering 512 unique outputs, with the precisely documented signed-zero qualification; see `verification/SUMMARY.md` and its audit evidence.

## Timing and address behavior retained from the team

The 4x4 tile still uses its original `cycles_for_matmul=14` with MAC latency 1. Part 4 does not apply the earlier companion package's size-dependent tile edit.

The team's 8x8 wrapper retains:

- `final_mat_mul_size=8` on all four tiles while `MAT_MUL_SIZE=4` stays unchanged.
- The two-stride subtraction from each raw C output address. It compensates for the early tile-done branch's address update.
- Its independent `clk_cnt_8x8` counter and done condition at counter value 33.

Software-visible APB DONE is captured from the 8x8 wrapper's completion signal. It must not be connected to an individual 4x4 tile's early done pulse. The eight-word write gates ensure that no extra C writes occur while the wrapper finishes its longer completion sequence.

Use the timing table in `verification/SUMMARY.md` for the measured final-write, raw-done, and APB-done edges of this revision. The earlier package's 33-active-edge completion claim must not be reused. Also distinguish the accepted APB START, preparation/reset edge, first core-active edge, last C write, raw 8x8 done, and sticky APB done when explaining latency.

## RAM and interface contract

| Item | Team-based Part 4 contract |
| --- | --- |
| Arithmetic | Exact supplied combinational FP8 E3M4 units and registered MAC |
| Array | Four 4x4 tiles / 64 physical PEs |
| Bases | Shared 10-bit A/B/C RAM-word addresses |
| Strides | Shared 8-bit A/B/C RAM-word increments |
| Run control | Core `start_mat_mul` stays high during execution |
| Preparation | Reset tile control and all PE accumulators before every job |
| Exception | OR of all four tile exceptions, stored by the APB controller during RUN |
| Banks | Two 32-bit banks per matrix, six banks total |
| External ports | Part 4 combines each matrix's two banks into a 64-bit view |
| Output writes | Exactly eight valid words per C bank for a complete 8x8 result |

The team's original `matrix_multiplication` wrapper has six separate 32-bit external memory ports. Part 4's adapter presents `{bank1, bank0}` on one 64-bit interface per matrix, sharing that external word address across the two banks. Each byte-write-enable bit controls its corresponding FP8 lane. This adapter is a deliberate new Part 4 integration layer; it is not claimed to be an unchanged copy of the team's RAM wrapper.

### Packing convention

| Matrix | Word address | Bank 0 bytes, least to most significant | Bank 1 bytes, least to most significant |
| --- | --- | --- | --- |
| A | `base_A+k*stride_A` | `A[0][k]`, `A[1][k]`, `A[2][k]`, `A[3][k]` | `A[4][k]`, `A[5][k]`, `A[6][k]`, `A[7][k]` |
| B | `base_B+k*stride_B` | `B[k][0]`, `B[k][1]`, `B[k][2]`, `B[k][3]` | `B[k][4]`, `B[k][5]`, `B[k][6]`, `B[k][7]` |
| C | `base_C+j*stride_C` | `C[0][j]`, `C[1][j]`, `C[2][j]`, `C[3][j]` | `C[4][j]`, `C[5][j]`, `C[6][j]`, `C[7][j]` |

Here `k` and `j` range from 0 to 7. A/C are packed by column; B is packed by row. All 64 C values, not only the first word, must be checked.

## What the uploaded Part 3 evidence establishes

The upload contains real RTL, its two-case testbench, simulation build instructions, a README, and Design Compiler reports/netlist/SDC. The two original uniform cases have been reproduced locally with Verilator using the original RTL; only waveform-dump statements were removed from that portable baseline testbench. This establishes those cases' output behavior, not the stronger Part 4 guard/nonuniform/restart checks.

No VCS run logs, FSDB/VCD, annotated screenshots, or graphical architecture diagram are present inside the uploaded Part 3 directory. The README's claims that those VCS/Verdi steps were performed remain the teammate's reported results unless the corresponding evidence is added.

## Synthesis-report reconciliation for Part 3

This is a Part 3 report follow-up, not an additional Part 4 synthesis requirement.

| Item | Evidence in the uploaded project |
| --- | --- |
| FP8 4x4 area | `PART2/SYNTHESIS/FP8/area.rep`: 60,604.931786 |
| FP8 8x8 area | `PART3/synth/area.rep`: 234,814.720706 |
| Area ratio | Approximately 3.8745 times the supplied 4x4 result |
| Library | Both area/timing report sets name `gscl45nm`, typical timing corner |
| 4x4 timing | October 23 report: 1 ns clock, 1.99 ns arrival, 0.90 ns required, -1.09 ns slack |
| 8x8 timing | October 24 report: 10 ns clock, 8.153522 ns arrival to exception, 9.90 ns required, +1.746477 ns slack |
| Original 8x8 constraints | 21,085 reported maximum-capacitance violations |
| Script/output mismatch | Generated SDC uses 0.05 pF output loads; current script specifies 0.01 pF |

The README's 238,513.74 area and approximately 125 MHz do not precisely match these raw outputs. The reports share a library, but use different timing targets; do not explain the entire frequency difference as array size alone or call both reported frequencies timing-closed achievements. Reconcile the selected source, constraints, and output set before making a fair comparison.

The October 24 synthesis outputs describe the uploaded array. They are not synthesis results for the corrected Part 4 copy. If the team adopts these fixes for Part 3, rerun its core-only synthesis before claiming area/frequency for that corrected version. Existing synthesis outputs should remain available as original evidence.

## Correct Part 3 quantitative context

The array can consume two 32-bit A words and two 32-bit B words in parallel: **128 bits/clock total peak reads**. The README's 64-bit read figure counts only two of the four input banks. Two C-bank writes provide **64 bits/clock peak writes**. These are internal datapath rates, separate from the 16-bit APB control bus.

An 8x8 matrix product evaluates **8×8×8=512 algorithmic MACs** using 64 physical PEs. State exact latency boundaries and use the measured interval for the revision being described.

## Required Part 4 next steps

1. Run the delivered Part 4 regression on Apporto, using its file list and current environment settings.
2. Run the exception case, retain its VCS/FSDB output, and capture/annotate APB configuration, execution/completion, and STATUS/FLAGS reads.
3. Add the Part 4 implementation description and register map, matching the actual integrated files and measured results.

## Team coordination for Part 3

Review the two array fixes with the Part 3 owner. If they are adopted into Part 3 itself, rerun the relevant tests, update the diagram's quadrant/dataflow labels, regenerate corrected synthesis evidence, and finish Part 3's annotated waveform/report requirements. Preserve contribution attribution and original reports. The team should submit source and evidence that agree on which array revision is final.

## Sources

- Lab 3 assignment, pp. 5–7 and 9–10: Part 3 and Part 4 construction/evidence requirements.
- Uploaded team `PART3/RTL`, `TESTBENCH`, `README.md`, and `synth`.
- Uploaded team `PART2/SYNTHESIS/FP8`.
- Delivered Part 4 source provenance, patch, and verification summary.
