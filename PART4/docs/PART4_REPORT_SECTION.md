# Part IV - APB slave interface

## Design changes

A 16-bit APB slave was added to control and observe the team's FP8 E3M4 8x8 systolic matrix multiplier. Its top-level control/status interface exposes PCLK, PRESETn, PADDR, PWRITE, PSEL, PENABLE, PWDATA, PRDATA, and PREADY. Matrix contents use a separate RAM data interface. Two internal 32-bit banks per matrix are presented as a combined 64-bit external word for initialization and readback.

The APB controller replaces the original RAM wrapper's start FSM and direct configuration pins. It stores the three matrix base addresses and three strides, accepts a start command, and reports completion and exceptions through readable CSRs. Writes commit on rising edges satisfying `PSEL && PENABLE && PREADY && PWRITE`, while reset is released. PREADY stays asserted, so each transfer uses a setup cycle and an access cycle without additional wait states. A combinational read mux supplies PRDATA before the access-completion edge.

An accepted START clears previous completion/exception status and enters a one-cycle preparation state that resets tile control and PE accumulators. The controller then holds `start_mat_mul` high through execution because the supplied core requires a held run enable. Configuration writes and repeated START commands are ignored while BUSY. The OR of all four tile exceptions is accumulated in a sticky FLAGS register during the operation. The supplied arithmetic exposes one combined exception bit, so this interface records whether an exception occurred without claiming separate cause bits. DONE becomes sticky when the controller consumes the 8x8 completion indication, after all eight output words have been stored in each C bank. DONE and FLAGS remain readable until reset or the next accepted START.

The integrated datapath uses the team's `matmul_8x8_systolic`. The supplied FP8 adder, multiplier, and 4x4 tile are unchanged. Two corrections are isolated to Part 4's copied 8x8 array: the bottom-right tile receives A from the mathematical bottom-left neighbor and B from the top-right neighbor, and each C-bank valid stream is limited to eight output words. The latter prevents writes beyond the result matrix while the team's completion sequence finishes. The team's two-stride C-address compensation and independent 8x8 completion counter are retained. The original Parts 1–3 remain preserved alongside the new Part 4 implementation.

## APB register map

PADDR, PWDATA, and PRDATA are 16 bits. Offsets are APB byte addresses. Base and stride contents are native RAM word addresses/increments, not APB addresses.

| Offset | Register | Access | Fields | Reset |
| --- | --- | --- | --- | --- |
| `0x00` | CONTROL | Write command; read zero | Bit 0: write one to start while idle | 0 |
| `0x02` | STATUS | Read-only | Bit 0: sticky DONE; bit 1: BUSY | 0 |
| `0x04` | FLAGS | Read-only | Bit 0: sticky combined FP exception | 0 |
| `0x10` | ADDR_A | Read/write while idle | Bits 9:0: A RAM word base | 0 |
| `0x12` | ADDR_B | Read/write while idle | Bits 9:0: B RAM word base | 0 |
| `0x14` | ADDR_C | Read/write while idle | Bits 9:0: C RAM word base | 0 |
| `0x16` | STRIDE_A | Read/write while idle | Bits 7:0: A RAM word increment | 1 |
| `0x18` | STRIDE_B | Read/write while idle | Bits 7:0: B RAM word increment | 1 |
| `0x1A` | STRIDE_C | Read/write while idle | Bits 7:0: C RAM word increment | 1 |

Unused read bits return zero. Writes to read-only, odd-address, or unmapped registers do nothing. Odd-address/unmapped reads return zero. A zero write to CONTROL does not launch a job, and reads do not clear status.

## Simulation and verification

The supplied APB read/write task pattern was adapted to 16-bit transactions, explicit setup/access phases, PREADY checking, completion-edge read sampling, and bounded timeouts. The integrated testbench initializes matrix RAMs, configures all six address/stride CSRs, writes START, polls STATUS, reads FLAGS, and checks every output element through external RAM readback. It also checks each output-write address and value, the number of writes per bank, and a guard word after the result region.

Local verification of this delivered team-based integration used Verilator 5.006. Eight end-to-end jobs checked 512 unique matrix elements, covering uniform and nonuniform inputs, cross-tile propagation, dense signed arithmetic, infinity-times-zero invalid operations, finite overflow, underflow, and a clean run after exceptions without global reset. Different nonzero bases and nonunit strides exercised the programmed address controls. The checker confirmed exactly eight output writes per C bank and preserved the guard word after each result matrix. These are results for the current team-based source, not the earlier companion array.

Four dense-case outputs had expected negative-zero encodings and observed positive zero because the inherited MAC continues adding padding zero before common result capture. The checker explicitly accepted only numerical equivalence between `0x00` and `0x80`; all nonzero encodings and exception bits matched exactly. The independent golden files were unchanged.

The focused exception run separately checked all 64 outputs. A elements of `0x70` (+infinity) and B elements of `0x00` (zero) produced `0x78` (canonical NaN) in every C element, or `0x78787878` per 32-bit C-bank word. The observed APB reads were STATUS=`0x0001` and FLAGS=`0x0001`.

The current controller remained active for 35 core clock edges through sticky DONE. In the focused run, START was accepted at 525 ns, the final C write committed at 865 ns, and sticky DONE asserted at 885 ns. The monitor recorded settled DONE at 886 ns because of its deliberate 1 ns sampling delay. Thus completion was visible after all results were stored; it was not asserted on the final-write edge. See `verification/SUMMARY.md` for the full timing definitions and logs. Apporto VCS/Verdi execution is still separate from these local results.

## Required final waveform evidence

Local verification and Apporto VCS/Verdi evidence are distinct. Add actual Apporto run results and annotated screenshots before final submission; these are not claimed merely because the local regression passes.

Capture the focused exception run and annotate these views with a digital pen or handwritten marks:

1. **Configuration and start:** APB setup/access phases, writes to six address/stride registers, stored values, and accepted START.
2. **Execution and completion:** held run enable, live exception, sticky FLAGS, eight output writes per bank, and DONE after result storage.
3. **Status reads:** STATUS at `0x02` returning `0x0001` and FLAGS at `0x04` returning `0x0001`.

Use `APPORTO_WALKTHROUGH.md` for commands, hierarchy, and screenshot instructions. Preserve the VCS logs with the images. No new Part 4 synthesis result is claimed; the uploaded Part 3 reports describe its original array, not this corrected copy.

## References

- Lab 3 assignment, pp. 9–10: APB interface, CSR controls/status, simulation, and Part 4 deliverables.
- ARM IHI0024B, Chapters 2–3: setup/access transfer phases and rising-edge timing.
- Lab 3 release slides, pp. 21–28: CSR integration and APB task-based testing.
- Supplied team Part 3 RTL and Part 2 `example_tb.sv`: datapath baseline and stimulus pattern.
