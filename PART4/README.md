# Lab 3 Part 4 — APB integrated with the team’s Part 3

This version connects the 16-bit APB controller to the actual
`matmul_8x8_systolic` supplied in `ADDV-Lab3-main (1).zip`. It replaces the
earlier companion array. The FP8 adder, FP8 multiplier, and original 4x4
tile are byte-identical copies of the team’s Part 3 files.

The complete ZIP preserves the uploaded `PART1`, `PART2`, and `PART3`
directories and adds this `PART4` directory. Build and simulate from
`PART4`. Its copy of the team array includes the two verified fixes below;
the archived `PART3` source and synthesis reports remain as received.

## What changed in the actual team array

1. The bottom-right tile now receives A from the mathematical bottom-left
   tile and B from the mathematical top-right tile. The original wiring
   produced 16 incorrect outputs in a nonuniform identity-matrix test.
2. Each C output-valid stream stops after eight committed words. The
   original Part 3 RAM wrapper wrote 11 words per bank and overwrote three
   following memory locations in each bank.

Only the copied `rtl/matmul_8x8.sv` contains these core corrections. The
team’s separate completion counter and C-address compensation are retained.
Do not combine this array with the older package’s modified 4x4 tile.
See `patches/team_part3_array.patch` and `docs/PART3_HANDOFF.md`.

The Part 4 memory wrapper keeps six 32-bit RAM banks and presents each
matrix externally as one 64-bit word `{bank1, bank0}`. Its external write
enables operate per byte. The original Part 3 wrapper had six separate
32-bit external ports and whole-word write behavior. Matrix packing is
unchanged. APB carries configuration and status; the RAM ports carry data.

## Current verification

| Check | Result |
| --- | --- |
| Original team’s two uniform tests | Reproduced PASS with Verilator 5.006; only unsupported FSDB dump calls removed from a scratch testbench copy |
| Directed original-array audit | 16 wrong elements; six overwritten guard words; 11 writes per C bank |
| Same audit with corrected array only | Zero wrong elements; zero guard changes; eight writes per bank |
| Full corrected APB integration | PASS: eight jobs, 512 unique result elements, eight writes per bank |
| Focused exception case | PASS: 64 canonical NaNs, sticky DONE=1 and FLAGS=1 |
| Timing | 33 active edges through the final C write; 35 through sticky APB DONE |
| Numerical qualification | Four signed-zero differences are explicitly reported and accepted; all nonzero bytes and flags match exactly |
| Apporto VCS / Verdi | Commands prepared; not run in this environment |
| Corrected-array synthesis | Not run; original Part 3 reports describe the uploaded design |

See `verification/SUMMARY.md` for exact evidence, comparison rules, and
timing. Tests are directed verification, not an exhaustive proof.

## Run on Apporto

Extract the full ZIP into Documents, then use Bash:

```bash
bash
cd ~/Documents/ADDV-Lab3-main/PART4
source env.sh
command -v vcs
command -v verdi
make compile
make sim CASE=all
mkdir -p evidence/waves
mkdir -p evidence/screenshots
cp build/part4.fsdb evidence/waves/part4_all.fsdb
cp build/part4_events.csv evidence/waves/part4_all_events.csv
make sim CASE=exception
cp build/part4.fsdb evidence/waves/part4_exception.fsdb
cp build/part4_events.csv evidence/waves/part4_exception_events.csv
make waves
```

For tcsh, use `source env.cshrc`. The supplied environment paths must match
your Apporto machine. If a folder with the same name already exists, extract
to a separate directory and adjust `cd` rather than overwriting that work.

A successful full run ends with:

```text
PASS: Part 4 end-to-end, 8 runs, 512 checked matrix elements
Signed-zero equivalences explicitly accepted: 4
```

The focused run ends with one run, 64 checked elements, and zero signed-zero
equivalences. Preserve each FSDB before starting another run. The VCS flow
uses the included vectors directly; Python is not required.

## Files to use

| File | Purpose |
| --- | --- |
| `rtl/apb_matmul_csr.sv` | APB access, configuration, PREP/RUN control, sticky status |
| `rtl/lab3_apb_pkg.sv` | Register addresses and widths |
| `rtl/matmul_apb_top.sv` | Controller-to-core integration |
| `rtl/matmul_8x8.sv` | Corrected copy of the actual team array |
| `rtl/vendor/` | Unchanged team FP8 arithmetic and 4x4 tile |
| `rtl/matmul_8x8_with_ram.sv`, `rtl/lab3_ram.sv` | Six-bank memory system and external data ports |
| `tb/tb_matmul_apb.sv` | Complete APB-driven matrix tests and waveform generation |
| `tb/apb_tasks.svh` | APB read/write tasks |
| `tb/tb_apb_matmul_csr.sv` | Isolated controller test available through `make unit` with Icarus installed |
| `docs/PART4_REPORT_SECTION.md` | Report text matching this implementation |
| `docs/APPORTO_WALKTHROUGH.md` | Commands, signal hierarchy, screenshot guidance |
| `docs/PART3_HANDOFF.md` | Exact fixes and team/report reconciliation notes |
| `docs/REGISTER_MAP.md` | Detailed programming contract |
| `docs/SOURCE_PROVENANCE.md` | Source hashes and modifications |
| `verification/` | New run logs, traces, reference image, and before/after audit |

The reference image is generated from a real Verilator trace. Capture and
annotate actual Verdi screenshots on Apporto for the assignment.

## Portable integrated verification

With Verilator installed:

```bash
make verilator
make regress
make exception
```

`make vectors` checks that the independent Python reference reproduces the
provided vectors. `make unit` is an optional focused Icarus controller test;
the full array should use Verilator or VCS.

## Register map

| APB byte offset | Register | Meaning |
| --- | --- | --- |
| `0x00` | CONTROL | Write bit 0=1 to start while idle; reads zero |
| `0x02` | STATUS | Bit 0 sticky DONE; bit 1 BUSY |
| `0x04` | FLAGS | Bit 0 sticky combined arithmetic exception |
| `0x10`, `0x12`, `0x14` | ADDR_A/B/C | RAM word bases, low ten bits |
| `0x16`, `0x18`, `0x1A` | STRIDE_A/B/C | RAM word increments, low eight bits |

APB data is 16 bits and PREADY stays high. New accepted START clears DONE
and FLAGS; reads do not. Configuration/start writes during BUSY are ignored.
Avoid external input-memory writes and C-port write collisions during a job.
