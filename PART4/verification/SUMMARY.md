# Verification of Part 4 using the actual team Part 3

Updated October 25, 2026 (America/Phoenix).

## Verified outcome

The APB controller now drives the team’s `matmul_8x8_systolic`, with two
corrections confined to the copied array wrapper. The FP8 units and 4x4 tile
are unchanged. The full eight-job regression passes, checking 512 unique
matrix elements, all output addresses/strides, exactly eight C writes per
bank, protected guard memory, and software-visible status.

All current HDL runs below used Verilator 5.006. VCS, Verdi, and Design
Compiler were not run here. The original uploaded synthesis reports are
preserved separately and do not describe the corrected array.

## Before-and-after evidence

| Run | Observed result | Evidence |
| --- | --- | --- |
| Original team’s two uniform cases | Both PASS | `audit/original_run.log` |
| Original team RTL with identity A and 64 distinct positive B elements | 16 incorrect outputs, six overwritten guard words, 11 C writes per bank | `audit/directed_run.log` |
| Same directed test, replacing only the array with the corrected copy | Zero incorrect outputs, zero guard changes, eight C writes per bank | `audit/corrected_run.log` |
| APB integration using the unmodified array | Stops at first unexpected ninth C0 write | `audit/unmodified_team_array_integration.log` |
| Corrected complete APB integration | Eight jobs, 512 checked outputs PASS | `full_regression.log`, `part4_all.vcd` |
| Focused invalid operation | 64 checked outputs PASS; DONE=1, FLAGS=1 | `exception_run.log`, `part4_exception.vcd` |

The original team’s testbench has unconditional FSDB calls. Its local replay
used a scratch copy with only the two unsupported dump statements commented
out; all RTL, stimulus, and result checks remained unchanged. The separate
directed audit used all five original RTL files first, then substituted only
the corrected array. Its summary reports mismatch counts; it intentionally
supports running the defective baseline and must not be judged by process
exit status alone. The Part 4 regression instead stops on any mismatch or
timeout with `$fatal`.

## Confirmed defects and corrections

The original bottom-right tile used A from the upper row group and B from
the left column group. A nonuniform identity test made the bottom-right
quadrant repeat the top-left: for example, C[4,4] was 0x20 instead of 0x44.
The corrected array connects A from `matmul_01` (mathematical bottom-left)
and B from `matmul_10` (mathematical top-right).

The unchanged tile’s raw output-valid stays high after useful data drains.
The original team wrapper consequently wrote three extra zero words beyond
each C bank’s result matrix. Two saturating four-bit word counters now bound
the public C-valid outputs to eight committed words, also qualified by run
and reset. The original C-address compensation and separate done counter
remain intact.

## Complete APB test cases

| Job | Case | FLAGS | Result |
| --- | --- | --- | --- |
| 1 | All ones; also attempts config writes and another START while BUSY | `0000` | Every C element `60` (+8); pass |
| 2 | Identity with varied signed values | `0000` | C equals B exactly; pass |
| 3 | Cross-tile permutation | `0000` | Expected row permutation exactly; pass |
| 4 | Dense signed arithmetic | `0001` | Numerical match with four documented signed-zero differences |
| 5 | Infinity times zero | `0001` | Every C element `78` (canonical NaN); exact pass |
| 6 | Finite-input overflow | `0001` | Every C element `70` (+infinity); exact pass |
| 7 | Underflow pulse | `0001` | Every C element `00`; live exception clears before the stored flag is read |
| 8 | Normal all-ones job after exceptions, without global reset | `0000` | Every C element `60`; old flags and accumulators cleared |

Each case uses APB for all six configuration writes, START, polling STATUS,
and reading FLAGS. Matrix contents use external RAM ports. Bases and strides
vary between cases. Results are checked on their internal write edge and
again by external readback; the 512 count does not double-count these checks.
The APB monitor checks SETUP/ACCESS ordering and stable address, direction,
and write data. DONE/FLAGS also survive delayed and repeated reads.

## Signed-zero qualification

The independent reference executes eight separately rounded FP8 multiply/add
terms per output. The inherited PEs continue to add padding +0 until common
capture. In the dense case this changes four underflow results from negative
zero (`80`) to positive zero (`00`):

```text
C[0][6], C[4][6], C[5][6], C[7][5]
```

The checker accepts only the exact `00`/`80` zero equivalence and reports each
occurrence. Every nonzero byte, NaN/infinity encoding, and FLAGS value is
compared exactly. No other exponent-zero encoding or X/Z value is accepted.
The golden files were not altered to match the DUT. This is directed
matrix-level numerical verification with the stated qualification, not
exhaustive FP8 bit-pattern conformance.

## Measured timing for this version

The clock period is 10 ns. The inherited tile’s early done is ignored as
overall completion; the team’s independent counter supplies the 8x8 pulse.

| Interval | Observed count |
| --- | --- |
| Active edges through final useful C write | 33 |
| Active edges through raw 8x8 done assertion | 34 |
| Active edges through sticky APB DONE | 35 |
| Accepted APB START to final C write | 34 clock periods |
| Accepted APB START to sticky APB DONE | 36 clock periods, including preparation |

Focused exception trace:

| Event | Time |
| --- | --- |
| START accepted | 525 ns |
| Preparation reset edge; RUN enabled afterward | 535 ns |
| First active core edge | 545 ns |
| First C write | 795 ns |
| Eighth and final C write | 865 ns |
| Raw team 8x8 done assertion | 875 ns |
| Sticky APB DONE assertion | 885 ns |
| Event monitor’s deliberately delayed settled sample | 886 ns |
| First successful STATUS read (`0001`) | 915 ns |
| FLAGS read (`0001`) | 945 ns |

The STATUS transfer at 885 ns samples the pre-edge value `0002`; the
controller’s sequential DONE update follows that same edge. The next poll
returns `0001`. This is expected zero-wait APB behavior. The monitor’s `#1`
sample at 886 ns is not an extra hardware cycle. APB configuration and
polling traffic are separate from the active core intervals above.

## Practical limits and remaining evidence

- Width warnings from inherited code and testbench expressions are retained
  in `verilator_compile.log`; the passing build has no compilation errors.
- The combined live exception is a single bit. FLAGS does not identify
  separate overflow, underflow, or invalid-operation causes.
- External RAM ports are not blocked while BUSY; callers must not overwrite
  active A/B or collide with C writes.
- Run the included VCS flow on Apporto and capture annotated Verdi screenshots
  for the assignment. The generated PNG/SVG is a Verilator study reference.
- Share the one-file array correction with the Part 3 owner. If the team
  adopts it for Part 3 submission, regenerate that part’s synthesis and
  update its diagram/report to match. No new synthesis result is claimed.
