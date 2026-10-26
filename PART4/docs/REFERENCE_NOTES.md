# Reference and golden-model notes

## Source precedence

1. **Lab #3: Systolic Matrix Multiplier - Fall 2026**, pages 9-10, defines Part 4: a 16-bit APB control/status interface, configuration of matrix addresses and strides, start, polling done, and reading exception status. `PREADY` may stay high. The matrix data path remains separate from APB.
2. **ARM IHI0024B, AMBA 3 APB Protocol Specification**, sections 2.1-2.3, 3.1, and 4.1, defines transfer timing. A write commits on a rising clock edge with `PSEL && PENABLE && PREADY && PWRITE`. A read completes at an equivalent access edge with `PWRITE=0`, with read data valid before that edge. Every transfer has a setup phase, including consecutive transfers to the same slave.
3. **The supplied Part 1/2 `fp8_adder.sv` and `fp8_multiplier.sv`** define the implemented numerical policy used by the golden model. This is a particular E3M4 policy; it is not a claim that all formats called FP8 behave the same way.
4. **11_Matrix Multiplier Accelerator Design**, page 31, gives the systolic-array formulas discussed below. **12_SoC Architecture and Interfaces**, pages 22-26 and 41-42, explains why low-bandwidth control transactions and high-bandwidth matrix data use different interfaces.

## FP8 numerical policy

The representation is one sign bit, a three-bit exponent with bias 3, and four fraction bits. For a normal value:

`value = (-1)^sign * (1 + fraction/16) * 2^(exponent-3)`

The exponent field 0 is treated as signed zero, including encodings that would otherwise represent denormals. Exponent 7 with fraction 0 is infinity; exponent 7 with a nonzero fraction is NaN. The canonical NaN output is `0x78`. Normal magnitudes range from 0.25 to 15.5.

Every nonzero exact result below 0.25 is flushed to signed zero **before** rounding and raises the combined exception. Normal results round to nearest with ties to an even significand. A rounding carry into exponent 7 produces infinity and raises the exception. Inexact rounding alone does not raise the exception. Infinity and NaN arithmetic also raises the combined exception.

The supplied arithmetic units each export **one combined exception bit**. It does not distinguish invalid operation, overflow, underflow, or inexactness. The matrix and CSR checks use the OR of the multiplier and adder exception events. A waveform showing this bit does not identify a particular cause without reference to the input test case.

Some useful encodings are:

| Value | Encoding |
|---|---|
| +0 | `0x00` |
| -0 | `0x80` |
| 0.25 | `0x10` |
| 0.5 | `0x20` |
| 1 | `0x30` |
| 2 | `0x40` |
| 4 | `0x50` |
| 8 | `0x60` |
| 15.5 | `0x6F` |
| +infinity | `0x70` |
| Canonical NaN | `0x78` |

## Independent reference calculations

`tools/generate_vectors.py` uses Python `Fraction` for exact arithmetic. It quantizes by searching a table of representable values, not by copying the RTL's integer shifts and normalization loops. A virtual 16.0 candidate models overflow caused by rounding at the top of the finite range. Exact ties choose the candidate with an even least-significant significand bit.

For every output element, the reference begins with +0 and visits `k=0..7` in order:

1. Compute and round `A[row,k] * B[k,column]` to FP8.
2. Add that rounded product to the FP8 accumulator and round again.

This is a multiply followed by an add. It is not a fused multiply-add, and it is not an exact real-number dot product rounded only once at the end.

All `.mem` files contain **64 bytes in row-major element order**, one hexadecimal byte per line. The testbench separately converts this logical ordering to the DUT's RAM bank and word layout. In particular, the B RAM stream does not change the logical matrix convention of these files.

`vectors/manifest.json` contains the exact expected flag, descriptions, operation counts, and SHA-256 hashes for each matrix file. The golden operation counts describe the 512 mathematically required MAC evaluations, not idle or padding cycles in the RTL.

| Case | Expected result | Combined flag |
|---|---|---:|
| `all_ones` | Every element is 8 (`0x60`) | 0 |
| `identity_varied` | Output equals the varied signed-normal B matrix | 0 |
| `cross_tile_permutation` | B rows reordered as `[4,0,7,3,1,6,2,5]` | 0 |
| `dense_signed` | Golden sequential rounded matrix product | 1 |
| `invalid_inf_zero` | Every element is canonical NaN (`0x78`) | 1 |
| `finite_overflow` | Every element is positive infinity (`0x70`) | 1 |
| `underflow_pulse` | Every element is zero; each 0.25 times 0.25 product underflows | 1 |

The dense test uses signed values with magnitudes from 0.5 through 1.25. None of its multiplications overflows or underflows, but cancellation produces 60 underflow events in the sequence of additions. It also exercises 405 non-exact finite multiplications and 206 additions changed by rounding or flushing. All 64 final output encodings are finite or zero.

The underflow-pulse case tests sticky exception capture particularly well: after input products have passed through the array, live exception indications can clear while the zero results are still being drained. The CSR must preserve the earlier exception for later software reads.

Regenerate or verify reproducibility from the project directory:

```bash
python3 tools/generate_vectors.py
python3 tools/generate_vectors.py --check
```

## Systolic-array metrics

For matrix size N, the lecture gives N squared processing elements, N cubed MAC evaluations, peak reads of 2N elements per clock, peak writes of N elements per clock, and 3N squared matrix-element memory accesses.

For an 8x8 FP8 array these become:

- 64 processing elements.
- 512 MAC evaluations.
- Peak read bandwidth of 16 FP8 elements, or 16 bytes, per cycle.
- Peak write bandwidth of 8 FP8 elements, or 8 bytes, per cycle.
- 192 matrix-element accesses: 64 A reads, 64 B reads, and 64 C writes.

The lecture's compute-and-shift scheduling formula is `4*N - 2 + MAC_latency`, yielding 31 when N=8 and MAC latency=1. State the measurement interval when reporting an observed cycle count. Start acceptance, counter edge conventions, RAM latency, and final result-write timing can change the number of clock edges counted by a particular testbench. APB configuration and polling overhead are separate from core execution.

The original supplied Part 2 `matmul.sv` hardcodes the 4x4 scheduling quantity to 14. That literal is not an 8x8 completion bound. The Part 3 integration must use the full matrix size and must verify that done occurs after every output write is committed.

## Reference-example cautions

- `APB-Slave-master` lacks `PENABLE` and uses falling-edge slave state updates. It is not a protocol-conforming drop-in APB implementation.
- The provided `apb_slave.sv` is an incomplete template and declares a five-bit data width while assigning a 16-bit done value. Part 4 requires a complete 16-bit implementation.
- The provided read/write tasks illustrate convenient task calls and falling-edge stimulus. They need correct read sampling, handshake checks, and bounded polling in a complete testbench.
- The LogicMadness PDF incorrectly says the slave asserts `PENABLE`; the APB master does. Its example has incomplete combinational assignments and a testbench that changes the read address during the setup-to-access transition.
- The ElectroBinary PDF is useful for register decoding and packing, but its particular state machine and sticky error handling should not be copied without review.
- DSP48E1-FP is a pipelined/iterative single-precision FPGA reference. Its widths, timing, FPGA primitives, and quoted clock frequency do not establish the behavior or synthesis results of this E3M4 lab design.
