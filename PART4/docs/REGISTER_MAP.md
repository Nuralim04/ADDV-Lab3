# Part 4 APB register reference

This document describes the implementation in `rtl/apb_matmul_csr.sv`, its address constants in `rtl/lab3_apb_pkg.sv`, and integration in `rtl/matmul_apb_top.sv`. It records RTL semantics; it does not claim a simulator result.

## Interface and addressing

| Property | Implemented behavior |
| --- | --- |
| Clock | `PCLK`; all transfers complete on rising edges |
| Reset | Active-low `PRESETn`; asynchronously resets CSRs/controller and asserts the core reset input |
| Address | 16-bit `PADDR`; exact decoding of the byte offsets below |
| Data | 16-bit `PWDATA` and `PRDATA` |
| Ready | `PREADY` is always 1; no inserted wait states |
| Write strobe | `PRESETn && PSEL && PENABLE && PREADY && PWRITE` |
| Read data | Combinational while `PRESETn && PSEL && !PWRITE`; otherwise zero |
| Invalid address | Read returns zero; write is ignored; transfer still completes |
| Odd address | Unimplemented, so read returns zero and write is ignored |
| Read side effects | None |
| Interrupt / error response | Neither an interrupt nor a `PSLVERR` port is implemented |

The master must generate an APB setup phase (`PSEL=1`, `PENABLE=0`), followed by an access phase (`PSEL=1`, `PENABLE=1`). Hold address, direction, and write data stable through the access-completion edge. For consecutive transfers to this slave, `PSEL` may stay high, but `PENABLE` must return low for the next setup phase.

Read data can be visible during setup; its transfer value is the value sampled at the access-completion edge. This is intentional. Registering `PRDATA` for the first time at that edge would be too late for a zero-wait slave. A testbench should sample before deasserting `PSEL` or changing `PADDR`, since the combinational read mux responds to those controls.

Keep reset asserted across at least one rising clock edge so the synchronous-reset datapath registers also reset. RAM contents are not reset. APB configuration/launch operations should begin after reset is released.

## Register table

All unlisted/reserved read bits are zero. Access types below describe behavior when a legal APB transfer completes.

| Byte offset | Name | Access | Bits | Meaning | Reset value |
| --- | --- | --- | --- | --- | --- |
| `0x0000` | CONTROL | Write command; read zero | 0 | START: write 1 while idle to accept a new job | `0x0000` |
| `0x0002` | STATUS | Read-only | 0 | DONE: sticky completed-operation indicator | `0x0000` |
| `0x0002` | STATUS | Read-only | 1 | BUSY: preparation or execution is in progress | `0x0000` |
| `0x0004` | FLAGS | Read-only | 0 | Arithmetic exception observed during the current/last job | `0x0000` |
| `0x0010` | ADDR_A | Read/write while idle | 9:0 | Matrix A base RAM word address | `0x0000` |
| `0x0012` | ADDR_B | Read/write while idle | 9:0 | Matrix B base RAM word address | `0x0000` |
| `0x0014` | ADDR_C | Read/write while idle | 9:0 | Matrix C base RAM word address | `0x0000` |
| `0x0016` | STRIDE_A | Read/write while idle | 7:0 | A RAM address increment between successive matrix words | `0x0001` |
| `0x0018` | STRIDE_B | Read/write while idle | 7:0 | B RAM address increment between successive matrix words | `0x0001` |
| `0x001A` | STRIDE_C | Read/write while idle | 7:0 | C RAM address increment between successive matrix words | `0x0001` |

`0x0006` through `0x000E`, all odd offsets, and every other unlisted 16-bit address are unimplemented. High address bits are decoded; for example, `0x1010` does not alias ADDR_A at `0x0010`.

## CONTROL: start command

Only bit 0 is meaningful. A write with bit 0 equal to 1 is accepted if BUSY was zero immediately before the write-completion edge. Other bits are ignored. A write with bit 0 equal to 0 does nothing.

An accepted start performs all of the following:

1. Clears sticky DONE and FLAGS.
2. Enters the preparation state and raises BUSY.
3. Asserts core reset during preparation, so the next rising edge clears PE accumulators and resets datapath control.
4. Enters execution and holds `core_start` high until the operation completes.

CONTROL does not store the written value and always reads as zero. `core_start` is an internal held run enable; it is not the readback of CONTROL bit 0. The waveform signals `start_accept`, `busy`, `core_reset`, and `core_start` make the command-to-run sequence visible.

There is no start queue. Additional start writes during BUSY are acknowledged by APB but ignored. A start write on the same edge as completion is also ignored, because BUSY was still one before that edge. Issue the next start after observing BUSY clear or DONE set.

## STATUS: completion and activity

Typical values are:

| Value | Interpretation |
| --- | --- |
| `0x0000` | Idle after reset, before a completed job |
| `0x0002` | Preparing or running; current DONE is clear |
| `0x0001` | Job completed; controller is idle; DONE remains sticky |

DONE stays high across reads and configuration writes. It clears only on reset or an accepted new start. BUSY covers both preparation and execution. STATUS writes have no effect.

A status read completing on the same clock edge that finishes the job samples the status before that edge's sequential update. It may return BUSY=1 and DONE=0. The next poll returns the completed status. Software should use a polling loop with a timeout, not assume a particular read is the last one.

### Completion and the final RAM write

The actual team Part 3 keeps its original 4x4 tile timing and generates a separate 8x8 completion pulse. Its C addresses compensate for the earlier tile done pulse by subtracting two output strides. The corrected array limits each public C-valid stream to eight committed words. Considering counter values immediately before each rising edge:

| Counter value | Event |
| --- | --- |
| 24 | Tiles capture their C results and present the first output column |
| 25–31 | First seven C columns commit to both C RAM banks |
| 32 | The eighth C column commits; both output-word counters reach eight and suppress further writes |
| 33 | The team's separate 8x8 completion register becomes high after this edge |
| 34 | The CSR consumes the 8x8 completion pulse and sets sticky DONE |

After the final edge, sticky DONE is high, BUSY is low, and `core_start` is low. The final valid RAM commit occurs two active edges before software-visible DONE. Counts begin at zero: these events correspond to 33 active edges through the last C write, 34 through raw 8x8 done, and 35 through sticky APB DONE. The run/reset gates and per-bank eight-word limits prevent output overruns while the controller waits for completion.

These events were also observed in the current integrated simulation; see `verification/SUMMARY.md` and `part4_exception_events.csv`. A different core must preserve the guarantee that software-visible DONE follows completion of all C writes.

## FLAGS: sticky arithmetic exception

Bit 0 records the OR of the exception signals from all four 4x4 tiles. During execution, the CSR updates as:

```text
FLAGS[0] = previous FLAGS[0] OR core_exception
```

The exception sampled on the completion edge is included. Exceptions outside execution, including a stale exception left in the previous operation's accumulator, are ignored. Preparation resets the arithmetic before execution of the new job begins.

FLAGS remains readable during and after execution. It is not cleared by reading it or writing the FLAGS register. It clears on reset or accepted start. Bits 15:1 remain zero.

The supplied FP8 units provide a single exception indication, so FLAGS does not distinguish overflow, underflow, NaN, or invalid operation. Interpret it using the supplied arithmetic policy and test input; do not describe FLAGS bit 0 as an overflow-only flag.

## Base addresses and strides

The six configuration registers are writable only while BUSY is zero. They are readable at all times. During BUSY, writes complete on APB without changing the stored values. This makes configuration stable throughout a job without requiring a second shadow-register bank.

Writing ADDR_A/B/C stores only `PWDATA[9:0]`; readback zero-extends that 10-bit field. Writing STRIDE_A/B/C stores only `PWDATA[7:0]`; readback zero-extends that 8-bit field. For example:

| Operation | Stored/read value |
| --- | --- |
| Write `0xF123` to ADDR_A | `0x0123` |
| Write `0xAB05` to STRIDE_A | `0x0005` |

The fields address **RAM words**, not APB bytes. Each external 64-bit word combines corresponding 32-bit words from the two banks. For a normal full 8x8 operation, eight useful word addresses are visited for each matrix:

```text
word_address(k) = base + k * stride, for k = 0..7
```

The actual RAM address is 10 bits, so arithmetic wraps modulo 1024. The hardware does not reject zero stride, out-of-range high bits, or an address sequence that wraps. A zero input stride repeats a RAM word; zero output stride repeatedly overwrites one result location. Use nonzero strides and a base/stride combination that holds all intended words when exercising ordinary matrix multiplication.

Changing configuration after a job completes does not clear DONE or modify existing C RAM contents. A new accepted start clears the completion/exception status for the next job.

## Memory interface ownership

Matrix data does not pass through these CSRs. Load A/B and inspect C through the top-level 64-bit external RAM ports. Each eight-bit write-enable bus controls the eight byte lanes. The synchronous RAM read returns data after the rising edge; when a port reads and writes the same word on one edge, its output receives the previous word contents.

The external RAM ports are not blocked by BUSY. The master/testbench must avoid changing A or B while the accelerator is using them and avoid writing C while the accelerator owns its output write port. Same-address writes from both RAM ports are not a supported operating case.

## Example software-style transaction sequence

The following is pseudocode, not an additional hardware interface:

```text
load_A_and_B_through_external_RAM_ports()

apb_write16(0x0010, A_base)
apb_write16(0x0012, B_base)
apb_write16(0x0014, C_base)
apb_write16(0x0016, A_stride)
apb_write16(0x0018, B_stride)
apb_write16(0x001A, C_stride)
apb_write16(0x0000, 0x0001)

repeat with a finite timeout:
    status = apb_read16(0x0002)
until (status & 0x0001) != 0

flags = apb_read16(0x0004)
read_and_check_all_64_C_elements_through_external_RAM_ports()
```

For a second job, update the idle configuration if needed and issue another start. A global reset is not required between jobs because preparation resets the PE accumulators and accepted start clears sticky status.

## Design choices versus lab requirements

The 16-bit data path, seven writable controls, done/flags readback, and zero-wait option come from `Lab #3_ Systolic Matrix Multiplier - Fall 2026.pdf`, pp. 9–10. The assignment permits choosing the register map. The offsets, BUSY bit, sticky status, write-one command, ignored writes while busy, reset stride of one, and unused-address behavior are explicit implementation choices in this package.
