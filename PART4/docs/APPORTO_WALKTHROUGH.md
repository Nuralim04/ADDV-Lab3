# Team-based Part 4: Apporto setup, simulation, waveforms, and demo

## What you will do

Run the supplied APB testbench against the actual 8x8 FP8 array, keep the simulator evidence, and capture the Part 4 waveform events. The testbench programs the accelerator through APB and checks every output matrix element through the external RAM ports.

The combined package preserves the uploaded Parts 1–3 and adds `PART4`. The commands below use `~/Documents/ADDV-Lab3-main/PART4`. Keep an existing working project untouched when extracting a new copy; use a separate trial destination if that folder is already present.

Local simulator results supplied with the package are real simulation evidence from the listed local tools. They are not Apporto VCS runs or Verdi screenshots. This walkthrough creates the Apporto evidence separately. See `verification/SUMMARY.md` for the actual completed local checks.

## 1. Put the combined project in Apporto

1. Download the new combined ZIP and upload it to Apporto using your normal file-transfer method.
2. Extract it into your `Documents` folder. Its top folder is `ADDV-Lab3-main`, containing the preserved `PART1`, `PART2`, `PART3`, and new `PART4` directories.
3. If `~/Documents/ADDV-Lab3-main` already exists, extract the new ZIP into a separate trial directory instead. Do not silently mix files from two revisions. Adjust the path in the following commands if you chose a trial directory.
4. Open a terminal:

```bash
cd ~/Documents/ADDV-Lab3-main/PART4
pwd
ls
```

You should see `Makefile`, `env.sh`, `env.cshrc`, `rtl`, `tb`, `vectors`, `tools`, `docs`, and `verification`. Run Part 4 from the folder directly containing `rtl/files.f` and `vectors/manifest.json`.

For terminal extraction, you can rename the uploaded local ZIP to `ADDV_Lab3_With_Part4.zip`. If it is in Apporto's Downloads folder, inspect its layout first:

```bash
unzip -l ~/Downloads/ADDV_Lab3_With_Part4.zip
```

If entries begin with `ADDV-Lab3-main/` and that destination does not already exist, extract:

```bash
mkdir -p ~/Documents
unzip ~/Downloads/ADDV_Lab3_With_Part4.zip -d ~/Documents
cd ~/Documents/ADDV-Lab3-main/PART4
```

Part 4 builds from its own file list. Do not compile the original Part 3 RAM wrapper or all source files across Parts 1–4 together. The earlier parts contain duplicate module names, and the preserved Part 3 source intentionally remains the original uploaded version.

## 2. Load the correct shell environment

Use either Bash or C shell. Do not source the C-shell file in Bash or the Bash file in C shell. The Makefile itself launches Bash for its recipes, so `make` can be called from either shell after the environment is loaded.

### Recommended: Bash

```bash
bash
cd ~/Documents/ADDV-Lab3-main/PART4
source env.sh
command -v vcs
command -v verdi
```

Each `command -v` should print the location of the requested program. If VCS or Verdi is missing, review the actual `VCS_HOME`, `VERDI_HOME`, and PATH entries for your current Apporto machine before compiling.

### If you already use tcsh for the lab

```csh
tcsh
cd ~/Documents/ADDV-Lab3-main/PART4
source env.cshrc
which vcs
which verdi
```

The `env.cshrc` is the team's supplied environment file; `env.sh` is its Bash equivalent. Their paths/license settings came from that supplied file. They still need to match the current Apporto environment. If your lab already has a working environment loaded, keep using the correct settings for that machine.

If you get `setenv: command not found`, you sourced the C-shell file in Bash. Use `source env.sh` in Bash. If you get an error around `export`, use the C-shell file from tcsh or switch to Bash.

## 3. Compile the complete design once

The simulation reads the vector files already included in the package. Python
and its packages are not required for this VCS flow. Use the optional Python
tools only to regenerate/check vectors or regenerate the waveform reference.

```bash
make compile
```

This compiles `tb_matmul_apb` with the APB controller, the actual team's 8x8 array with two isolated integration fixes, six RAM banks, and the unchanged team FP8 tiles/arithmetic. The compilation uses SystemVerilog, debug information, and FSDB dumping. The key outputs are:

| Output | Purpose |
| --- | --- |
| `build/simv` | VCS simulation executable |
| `build/simv.daidir` | Debug database used by Verdi |
| `logs/vcs_compile.log` | Compilation output |

If compilation fails, fix the first actual error before running the simulation. A warning alone is not automatically a failure. An undefined FSDB system-task or missing FSDB integration error is addressed in the fallback section below.

The project compiles files in the order specified by `rtl/files.f`. Keep that order; the package constants must be available before modules that import them. Do not add the original Part 2 wrapper or original incomplete APB scaffold to this build, since they are not the top-level implementation being tested here and contain conflicting macro definitions.

## 4. Run all cases and preserve their waveform

```bash
mkdir -p evidence/waves
mkdir -p evidence/screenshots
make sim CASE=all
```

The all-case selection runs the following jobs without a global reset between them:

| Job | What it exercises |
| --- | --- |
| All ones | Every expected C element is FP8 8.0; also attempts ignored writes/start while BUSY |
| Identity with varied values | Nonuniform result and correct row/column packing |
| Cross-tile permutation | Values must propagate correctly through neighboring tiles |
| Dense signed values | Mixed arithmetic with the reference model's expected exception behavior |
| Infinity times zero | NaN output and asserted exception |
| Finite overflow | Exception from finite inputs |
| Underflow pulse | Sticky flag remains after the live exception deasserts |
| All ones again | Clean operation after exceptions without global reset |

The testbench is designed to end a successful all-case run with:

```text
PASS: Part 4 end-to-end, 8 runs, 512 checked matrix elements
```

The full run also explicitly reports four positive-zero/negative-zero differences from inherited padding behavior in the dense case. Those zeros are accepted as numerically equal; all nonzero result bytes and flags must match exactly. See `verification/SUMMARY.md` for the precise comparison policy.

Each job also reports its result checks, flags, output-write counts, and active clock interval. Treat any `$fatal`, timeout, mismatch, or missing final PASS as a failed run. The monitor additionally checks APB setup/access ordering, programmed output addresses/strides, all eight output words per bank, completion after those writes, and a guard word beyond the output matrix.

After a successful run, preserve the waveform and event log before running another case:

```bash
cp build/part4.fsdb evidence/waves/part4_all.fsdb
cp build/part4_events.csv evidence/waves/part4_all_events.csv
```

The simulator log is already kept separately as `logs/vcs_all.log`.

The current local team-based regression observed 35 core-active edges through sticky DONE per job. The earlier companion implementation used a different completion sequence; do not expect its shorter count. A successful Apporto run should agree with the delivered checker and its current source.

## 5. Run the focused exception case for your Part 4 report

```bash
make sim CASE=exception
cp build/part4.fsdb evidence/waves/part4_exception.fsdb
cp build/part4_events.csv evidence/waves/part4_exception_events.csv
make waves
```

`make waves` opens the latest `build/part4.fsdb` and the matching VCS debug database. Because the latest run was the focused exception case, its short waveform is easy to inspect. Its simulator log is `logs/vcs_exception.log`.

This case uses infinity `0x70` in matrix A and zero `0x00` in matrix B. Under the supplied FP8 arithmetic policy, the expected result is canonical NaN `0x78` in every C element and FLAGS=`0x0001`. A 32-bit C-bank output word therefore appears as `0x78787878`; the combined 64-bit external C word appears as `0x7878787878787878`.

The focused exception case programs:

| Register | APB offset | Written value |
| --- | --- | --- |
| ADDR_A | `0x0010` | `0x0010` (RAM word 16) |
| ADDR_B | `0x0012` | `0x0080` (RAM word 128) |
| ADDR_C | `0x0014` | `0x0280` (RAM word 640) |
| STRIDE_A | `0x0016` | `0x0002` |
| STRIDE_B | `0x0018` | `0x0003` |
| STRIDE_C | `0x001A` | `0x0004` |
| CONTROL | `0x0000` | `0x0001` (start command) |

The register offset selects a CSR. The value written to a base/stride CSR describes a RAM word address or increment. These are different address meanings even when two numbers happen to be equal.

To open a preserved FSDB later:

```bash
verdi -dbdir build/simv.daidir -ssf evidence/waves/part4_exception.fsdb -nologo
```

Preserve both the FSDB and its matching debug database if you need to reopen the same compiled hierarchy later. Avoid `make clean` until you have saved the evidence you need; that target removes `build` and `logs`.

### Optional short runs

For a clean matrix case:

```bash
make sim CASE=normal
cp build/part4.fsdb evidence/waves/part4_normal.fsdb
```

For the clearest demonstration of sticky flags:

```bash
make sim CASE=underflow
cp build/part4.fsdb evidence/waves/part4_underflow.fsdb
```

The underflow case checks that the live exception is already zero when the stored exception is read. Rerun `CASE=exception` before `make waves` if you want the required focused exception waveform to be the default again.

## 6. Add the signals in Verdi

Open the design hierarchy, expand `tb_matmul_apb`, and add signals from the scopes below to the waveform window. Choose hexadecimal radix for addresses, data, configuration values, and flags. Keep single-bit controls binary. For the counter, decimal is usually easiest to explain.

### Group A: APB transfers

Scope: `tb_matmul_apb`

```text
PCLK
PRESETn
PSEL
PENABLE
PWRITE
PADDR
PWDATA
PRDATA
PREADY
scenario_id
```

### Group B: configuration and operation control

Scope: `tb_matmul_apb.dut`

```text
address_mat_a
address_mat_b
address_mat_c
address_stride_a
address_stride_b
address_stride_c
start_accept
core_reset
core_start
busy
core_done
done_sticky
core_exception
flags_sticky
```

Optional controller-state signal: `tb_matmul_apb.dut.u_csr.launch_state`. The declared order is IDLE, PREP, RUN; the corresponding encodings are 0, 1, 2.

### Group C: array activity and output writes

Scope: `tb_matmul_apb.dut.u_core`

```text
a_addr_0
a_addr_1
b_addr_0
b_addr_1
a_data_0
a_data_1
b_data_0
b_data_1
c_valid_0
c_valid_1
c_we_0
c_we_1
c_addr_0
c_addr_1
c_data_0
c_data_1
```

For the compute counter, add:

```text
tb_matmul_apb.dut.u_core.u_array.clk_cnt_8x8
tb_matmul_apb.dut.u_core.u_array.matmul_00.clk_cnt
```

To show data moving between tiles, add selected boundary signals from `tb_matmul_apb.dut.u_core.u_array`:

```text
a_link_top
b_link_left
c_link_left
c_link_right
exception_00
exception_01
exception_10
exception_11
```

To show the write limit, optionally add `c_words_0`, `c_words_1`, `raw_c_valid_0`, `raw_c_valid_1`, `c_data_available_0`, and `c_data_available_1` from that same array scope. The word counts stop at eight and the public valid signals go low even if the inherited raw valid remains high.

To inspect the corrected bottom-right inputs, expand `tb_matmul_apb.dut.u_core.u_array.matmul_11` and add `a_data_in` and `b_data_in`. The team's instance names place `matmul_01` at mathematical rows 4–7 / columns 0–3, and `matmul_10` at rows 0–3 / columns 4–7. The old top-right/bottom-left comments are misleading. These signals provide context; keep the required Part 4 screenshots focused enough that APB values remain readable.

### Group D: result inspection

Scope: `tb_matmul_apb`

```text
bram_addr_c_ext
bram_rdata_c_ext
writes_0
writes_1
active_clocks
```

The RAM instances are under `tb_matmul_apb.dut.u_core`: `matrix_A0`, `matrix_A1`, `matrix_B0`, `matrix_B1`, `matrix_C0`, and `matrix_C1`. Each contains the array `ram`. The FSDB dump requests multidimensional arrays. If memory display is inconvenient, the external C readback signals still show the values actually read by the checker.

## 7. Capture and annotate the required waveform evidence

Use a few legible screenshots instead of squeezing every signal into one unreadable image. Keep the time scale and the relevant values visible. Place a cursor on the rising edge you are explaining, then zoom until setup/access phases or result events can be distinguished.

### Screenshot 1: APB configuration and start

Show Group A plus the six configuration registers and `start_accept`.

Annotate these points with a digital pen or hand-drawn marks:

- Bracket a **setup phase**: `PSEL=1`, `PENABLE=0`.
- Bracket its **access phase**: `PSEL=1`, `PENABLE=1`, `PWRITE=1`, `PREADY=1`.
- Mark the rising clock edge where the write completes.
- Point from `PADDR`/`PWDATA` to the register value after the write.
- Circle the CONTROL write at address `0x0000` with data `0x0001` and label it “start accepted.”

Use the exception configuration table above to identify the expected values. If all seven writes do not fit readably, split configuration and start into two images.

### Screenshot 2: matmul running and exception recorded

Show `core_reset`, `core_start`, `busy`, the tile counter, representative A/B activity, `core_exception`, and `flags_sticky`.

Annotate:

- The preparation/reset interval before the run enable rises.
- The run interval where `core_start` stays high and the array advances.
- The live arithmetic exception becoming 1.
- FLAGS bit 0 being recorded and remaining set.

The infinity-times-zero case may keep the live exception asserted because NaNs remain in the accumulation path. The separate underflow run is the stronger demonstration that a short live exception is retained after it disappears.

### Screenshot 3: final output write, done, and status reads

Show APB signals, `c_we_0`, `c_we_1`, `c_addr_0`, `c_data_0`, `core_done`, `done_sticky`, `busy`, and `flags_sticky`.

Annotate:

- The last C write, followed later by the transition to sticky DONE. The retained team completion sequence leaves a short gap; do not label these as the same edge.
- The STATUS read: `PADDR=0x0002`, `PWRITE=0`, `PSEL=1`, `PENABLE=1`; completed status is `PRDATA=0x0001`.
- The FLAGS read: `PADDR=0x0004` with the same read controls; `PRDATA=0x0001`.
- The fact that `PREADY` stays high, so each access completes without an extra wait cycle.

If a poll overlaps the completion edge, it can legitimately return the previous busy status `0x0002`. The next poll returns `0x0001`. Show a read that actually completed with DONE set.

### Optional screenshot 4: output RAM readback

Show `bram_addr_c_ext` and `bram_rdata_c_ext` after done. For the focused exception case, the expected addresses are 640, 644, 648, 652, 656, 660, 664, and 668. Every returned output word should be `0x7878787878787878`.

The later read at word 672 is a guard location and should remain `0xA5A5A5A5A5A5A5A5`; it is not part of the result matrix. The checker uses it to detect an extra output write.

### Save the annotations

Capture the actual waveform window using the available screenshot function. Save the original image, then open a copy in your usual image/PDF annotation app and draw the brackets, arrows, circles, and short labels yourself. The rubric specifically requests handwritten or digital-pen annotations. Keep text readable, avoid covering signal values, and save both original and annotated copies under `evidence/screenshots`.

Do not redraw signal transitions or replace screenshot values. The annotations explain the simulator evidence; they do not create the evidence.

## 8. If FSDB integration is unavailable

First confirm that the expected VCS and Verdi programs are on PATH and that you loaded the environment for this machine. A missing FSDB task/plugin is an environment issue; it is not by itself evidence that the RTL failed.

The Makefile supplies a VCS/VCD fallback that compiles the same RTL and checker without the FSDB calls:

```bash
make compile-vcd
make sim-vcd CASE=all
cp build/part4.vcd evidence/waves/part4_all_vcs.vcd
make sim-vcd CASE=exception
cp build/part4.vcd evidence/waves/part4_exception_vcs.vcd
```

This produces `build/simv_vcd`, `build/simv_vcd.daidir`, the VCD waveform, and separate `logs/vcs_vcd_*.log` files. The checks and expected values are unchanged.

The `make waves` target specifically opens `build/part4.fsdb`; it does not automatically import the fallback VCD. Open the fallback waveform using a waveform viewer's supported VCD import/conversion capability. To open its compiled hierarchy in Verdi:

```bash
verdi -dbdir build/simv_vcd.daidir -nologo
```

Use the VCD import/conversion option available in that installation, or restore the course's FSDB integration and rerun `make compile`/`make sim`. Keep the VCD and successful checker log even if the FSDB environment still needs attention.

## 9. Explain the design in a short demo

### Opening explanation

“My Part 4 adds an APB slave around the 8x8 FP8 matrix multiplier. The testbench acts like a CPU: it writes the matrix addresses and strides, writes a start command, polls done, and reads the exception flag. The matrix contents still use the separate RAM interface. The APB controller also prepares the core, holds its run enable, and stores completion and exception status so polling cannot miss them.”

### Questions and answers

**What is APB doing here?**

It is the control/status interface. It lets a CPU configure and observe the accelerator through addressed registers. The matrix array itself performs the arithmetic.

**How does a write work, and how does the waveform prove it?**

The master provides a setup cycle with `PSEL=1` and `PENABLE=0`, then an access cycle with `PENABLE=1`. At the rising edge with select, enable, write, and ready all high, the slave updates the selected writable register. The waveform shows that edge and the register value changing afterward.

**Why is PREADY always high?**

These are simple local registers, so the slave does not need extra wait cycles. The lab explicitly permits this. The setup and access phases still occur.

**Why are there 8-bit, 16-bit, and 64-bit values in the same design?**

One FP8 matrix element is 8 bits. One APB register transaction carries 16 bits. The external RAM data interface carries eight matrix elements at once, so it is 64 bits wide; internally that is two 32-bit RAM banks. The APB width does not change the arithmetic precision.

**Where are start, done, and flags?**

Write 1 to CONTROL at `0x0000` to request a job. Read STATUS at `0x0002`: bit 0 is DONE, bit 1 is BUSY. Read FLAGS at `0x0004`: bit 0 is the combined arithmetic exception. The six base/stride registers occupy even offsets `0x0010` through `0x001A`.

**Is start only a one-cycle pulse?**

The software write is a command. The controller then resets/prepares the core and holds the internal run enable high until completion. The supplied systolic core would reset its progress if that enable went low too soon.

**Why are done and flags sticky?**

A CPU may read later than the exact event cycle. Storing the events ensures they are still visible when it polls. They clear on reset or the next accepted start, not when read.

**How do you know the output is complete when done is read?**

The controller waits for the team's 8x8 completion signal after all eight output words have been committed per bank. The valid streams are capped at eight words so the remaining completion interval cannot produce extra writes. The testbench checks the write count, values, addresses, completion ordering, all 64 stored results, and a guard word after C.

**What does the exception case show?**

Infinity multiplied by zero produces NaN under the supplied FP8 implementation. The waveform shows the array exception, stored FLAGS bit 0, and an APB FLAGS read returning 1. Output RAM readback contains the expected `0x78` NaN encoding.

**How does this depend on Part 3?**

Part 3 supplies the actual four-tile `matmul_8x8_systolic` used here. Part 4 adds APB control and a RAM adapter around it. The copied array has two documented fixes: correct bottom-right A/B neighbors and a limit of eight C writes per bank. The supplied arithmetic and 4x4 tile remain unchanged, and the original Parts 1–3 are preserved.

**What happens if software writes configuration while it is busy?**

The APB transfer completes, but the write is ignored. The active matrix addresses and strides stay stable. A repeated start while busy is also ignored; there is no job queue.

**Do the matrices go through APB?**

No. The testbench loads the external RAM interface. APB supplies the base/stride controls and start/done/flag communication. That matches the provided lab hierarchy.

## 10. What to add to the team's report

Use `REGISTER_MAP.md` for the precise CSR table and `CONTEXT_AND_PLAN.md` for the implementation description. Add your actual annotated exception waveforms and VCS test outcome. Explain the two copied-array integration fixes and coordinate them with the Part 3 owner. Use the new team-based verification summary; do not reuse the earlier companion-array timings or signal hierarchy.

Part 4's listed rubric does not request a new synthesis comparison. Part 3 already includes original synthesis outputs, but they describe the uploaded array before these fixes; its README values also need reconciliation with the raw reports. The Part 3 owner should handle any corrected-core synthesis, diagram/dataflow updates, and remaining annotated datapath evidence separately. Do not present original Part 3 or Part 2 numbers as new Part 4 synthesis results.

Sources: `Lab #3_ Systolic Matrix Multiplier - Fall 2026.pdf`, pp. 7–10; `14_Lab3_Release.pdf`, pp. 21–28; the package's actual `Makefile`, environment files, RTL, and testbench.
