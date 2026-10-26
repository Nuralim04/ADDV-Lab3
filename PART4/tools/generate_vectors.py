#!/usr/bin/env python3
"""Create deterministic E3M4 matrix golden vectors using exact rational arithmetic.

This is a policy model, independent of the RTL normalization/shift algorithms.
Finite results are rounded by finding the nearest member of a representable-value
table.  Each matrix MAC performs a rounded multiply followed by a rounded add.

Run from any directory:
    python3 tools/generate_vectors.py
    python3 tools/generate_vectors.py --check

The default output is this project's vectors/ directory.  Matrix files contain
64 FP8 bytes in row-major element order.  Their layout is intentionally separate
from the DUT's RAM-word packing, which is the testbench's responsibility.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from fractions import Fraction
import hashlib
import json
from pathlib import Path
from typing import Iterable


N = 8
QNAN = 0x78
POS_INF = 0x70
NEG_INF = 0xF0
ONE = 0x30
MIN_NORMAL = Fraction(1, 4)
OVERFLOW_CANDIDATE = Fraction(16)


@dataclass(frozen=True)
class Decoded:
    kind: str
    negative: bool
    value: Fraction | None


def decode(bits: int) -> Decoded:
    """Decode all 256 encodings according to the supplied team's FP8 policy."""
    if not 0 <= bits <= 255:
        raise ValueError(f"FP8 encoding out of range: {bits}")
    negative = bool(bits & 0x80)
    exponent = (bits >> 4) & 7
    fraction = bits & 15
    if exponent == 0:
        # All denormal encodings are zero-like, with their original sign.
        return Decoded("zero", negative, Fraction(0))
    if exponent == 7:
        return Decoded("inf" if fraction == 0 else "nan", negative, None)
    scale = Fraction(2) ** (exponent - 3)
    magnitude = Fraction(16 + fraction, 16) * scale
    return Decoded("normal", negative, -magnitude if negative else magnitude)


# The virtual 16.0 candidate models a rounding carry out of the largest finite
# exponent.  It has even significand parity; 15.75 therefore overflows at a tie.
POSITIVE_CANDIDATES = tuple(
    (decode(code).value, code)
    for code in range(0x10, 0x70)
) + ((OVERFLOW_CANDIDATE, POS_INF),)


def quantize(exact: Fraction, *, negative_zero: bool = False) -> tuple[int, int]:
    """Nearest-even quantization, with underflow flushed *before* rounding.

    Return (encoded result, combined exception).  Rounding inexactness alone is
    not an exception in the supplied design.  Underflow and overflow are.
    """
    exact = Fraction(exact)
    if not exact:
        return (0x80 if negative_zero else 0), 0
    sign = 0x80 if exact < 0 else 0
    magnitude = abs(exact)
    if magnitude < MIN_NORMAL:
        return sign, 1
    if magnitude >= OVERFLOW_CANDIDATE:
        return sign | POS_INF, 1
    _, code = min(
        POSITIVE_CANDIDATES,
        # Fraction comparison is exact.  At equal distance choose even LSB.
        key=lambda item: (abs(item[0] - magnitude), item[1] & 1),
    )
    return sign | code, int(code == POS_INF)


def multiply(a: int, b: int) -> tuple[int, int]:
    left, right = decode(a), decode(b)
    sign = 0x80 if left.negative != right.negative else 0
    if "nan" in (left.kind, right.kind):
        return QNAN, 1
    if ((left.kind == "inf" and right.kind == "zero") or
            (right.kind == "inf" and left.kind == "zero")):
        return QNAN, 1
    if "inf" in (left.kind, right.kind):
        return sign | POS_INF, 1
    if "zero" in (left.kind, right.kind):
        return sign, 0
    assert left.value is not None and right.value is not None
    return quantize(left.value * right.value)


def add(a: int, b: int) -> tuple[int, int]:
    left, right = decode(a), decode(b)
    if "nan" in (left.kind, right.kind):
        return QNAN, 1
    if left.kind == right.kind == "inf" and left.negative != right.negative:
        return QNAN, 1
    if left.kind == "inf":
        return (NEG_INF if left.negative else POS_INF), 1
    if right.kind == "inf":
        return (NEG_INF if right.negative else POS_INF), 1
    assert left.value is not None and right.value is not None
    if left.kind == right.kind == "zero":
        return (0x80 if left.negative and right.negative else 0), 0
    # An exact cancellation of nonzero values is +0, matching nearest-even.
    return quantize(left.value + right.value)


def _was_rounded(a: int, b: int, result: int, *, is_add: bool) -> bool:
    da, db, dr = decode(a), decode(b), decode(result)
    if any(x.value is None for x in (da, db, dr)):
        return False
    exact = da.value + db.value if is_add else da.value * db.value
    return dr.value != exact


def matrix_product(a: list[int], b: list[int]) -> tuple[list[int], int, dict[str, int]]:
    if len(a) != N * N or len(b) != N * N:
        raise ValueError("Expected two row-major 8x8 matrices")
    c: list[int] = []
    flags = 0
    stats = {
        "multiply_operations": 0,
        "add_operations": 0,
        "multiply_exception_events": 0,
        "add_exception_events": 0,
        "finite_multiply_value_changes_from_rounding_or_flush": 0,
        "finite_add_value_changes_from_rounding_or_flush": 0,
    }
    for row in range(N):
        for col in range(N):
            accumulator = 0x00
            for inner in range(N):
                aa, bb = a[row * N + inner], b[inner * N + col]
                product, mul_flag = multiply(aa, bb)
                next_accumulator, add_flag = add(accumulator, product)
                flags |= mul_flag | add_flag
                stats["multiply_operations"] += 1
                stats["add_operations"] += 1
                stats["multiply_exception_events"] += mul_flag
                stats["add_exception_events"] += add_flag
                stats["finite_multiply_value_changes_from_rounding_or_flush"] += int(
                    _was_rounded(aa, bb, product, is_add=False)
                )
                stats["finite_add_value_changes_from_rounding_or_flush"] += int(
                    _was_rounded(accumulator, product, next_accumulator, is_add=True)
                )
                accumulator = next_accumulator
            c.append(accumulator)
    return c, flags, stats


def _varied_normal_matrix() -> list[int]:
    # 64 distinct normal values with changing exponents, fractions, and signs.
    # Multiplication by an odd stride permutes all 96 positive normal encodings.
    return [0x10 + ((index * 37 + 11) % 96) |
            (0x80 if ((index * 5 + index // 8) % 7) < 3 else 0)
            for index in range(N * N)]


def _dense_matrices() -> tuple[list[int], list[int]]:
    # Explicit integer LCG, rather than a library RNG, makes the byte sequence
    # reproducible across Python versions.  Magnitudes stay in [0.5, 1.25].
    state = 20261024
    encoded: list[int] = []
    for _ in range(2 * N * N):
        state = (1664525 * state + 1013904223) & 0xFFFFFFFF
        code = 0x20 + ((state >> 8) % 21)
        if state & 0x80000000:
            code |= 0x80
        encoded.append(code)
    return encoded[:N * N], encoded[N * N:]


def _cases() -> list[tuple[str, str, list[int], list[int]]]:
    identity = [ONE if row == col else 0 for row in range(N) for col in range(N)]
    varied = _varied_normal_matrix()
    permutation = [4, 0, 7, 3, 1, 6, 2, 5]
    perm_matrix = [ONE if col == permutation[row] else 0
                   for row in range(N) for col in range(N)]
    dense_a, dense_b = _dense_matrices()
    return [
        ("all_ones", "All A and B elements are +1; every C element is +8 (0x60).",
         [ONE] * 64, [ONE] * 64),
        ("identity_varied", "A is identity; B contains 64 distinct signed normal values; C must equal B.",
         identity, varied),
        ("cross_tile_permutation", "A permutes B rows as [4,0,7,3,1,6,2,5], crossing the 4x4 tile boundary.",
         perm_matrix, varied),
        ("dense_signed", "Deterministic dense signed normal matrices (magnitudes 0.5..1.25); exercises rounding and cancellation underflow.",
         dense_a, dense_b),
        ("invalid_inf_zero", "A is +infinity; B is +zero; every product is invalid and every C element is canonical NaN (0x78).",
         [POS_INF] * 64, [0x00] * 64),
        ("finite_overflow", "A and B are all +4; each scalar product 4 times 4 overflows FP8; every C element is +infinity (0x70).",
         [0x50] * 64, [0x50] * 64),
        ("underflow_pulse", "A and B are all 0.25 (0x10); each product underflows to zero; every C is zero, and the sticky exception must outlast the live pulse.",
         [0x10] * 64, [0x10] * 64),
    ]


def _mem_text(values: Iterable[int]) -> str:
    return "".join(f"{value:02x}\n" for value in values)


def self_check() -> None:
    """Small policy checks chosen from independently obvious numeric cases."""
    assert decode(ONE).value == 1
    assert decode(0x10).value == Fraction(1, 4)
    assert decode(0x6F).value == Fraction(31, 2)
    assert decode(0x0F).value == 0
    assert quantize(Fraction(33, 32)) == (0x30, 0)  # Tie 1.0/1.0625 -> even.
    assert quantize(Fraction(35, 32)) == (0x32, 0)  # Tie 1.0625/1.125 -> even.
    assert quantize(Fraction(255, 1024)) == (0x00, 1)  # Flush before rounding.
    assert quantize(Fraction(-1, 8)) == (0x80, 1)
    assert quantize(Fraction(63, 4)) == (POS_INF, 1)  # 15.75 ties to 16.
    assert multiply(POS_INF, 0x00) == (QNAN, 1)
    assert multiply(0x80, ONE) == (0x80, 0)
    assert add(0x80, 0x80) == (0x80, 0)
    assert add(0x80, 0x00) == (0x00, 0)
    assert add(ONE, ONE | 0x80) == (0x00, 0)
    assert add(POS_INF, NEG_INF) == (QNAN, 1)
    assert multiply(0x50, 0x50) == (POS_INF, 1)


def generate() -> dict[str, str]:
    self_check()
    outputs: dict[str, str] = {}
    tests: list[dict[str, object]] = []
    for name, description, a, b in _cases():
        c, flags, stats = matrix_product(a, b)
        if name == "all_ones":
            assert c == [0x60] * 64 and flags == 0
        elif name == "identity_varied":
            assert c == b and flags == 0
        elif name == "cross_tile_permutation":
            assert c == [b[row * 8 + col]
                         for row in [4, 0, 7, 3, 1, 6, 2, 5]
                         for col in range(8)] and flags == 0
        elif name == "dense_signed":
            assert stats["finite_multiply_value_changes_from_rounding_or_flush"] > 0
            assert stats["finite_add_value_changes_from_rounding_or_flush"] > 0
            assert all(decode(x).kind in ("normal", "zero") for x in c)
        elif name == "invalid_inf_zero":
            assert c == [QNAN] * 64 and flags == 1
        elif name == "finite_overflow":
            assert c == [POS_INF] * 64 and flags == 1
        elif name == "underflow_pulse":
            assert c == [0x00] * 64 and flags == 1
        files = {"a": f"{name}_a.mem", "b": f"{name}_b.mem", "c": f"{name}_c.mem"}
        hashes: dict[str, str] = {}
        for key, values in (("a", a), ("b", b), ("c", c)):
            text = _mem_text(values)
            outputs[files[key]] = text
            hashes[key] = hashlib.sha256(text.encode("ascii")).hexdigest()
        tests.append({
            "name": name,
            "description": description,
            "files": files,
            "expected_flags": flags,
            "expected_flags_hex": f"0x{flags:04x}",
            "sha256": hashes,
            "golden_operation_counts": stats,
        })
    manifest = {
        "schema_version": 1,
        "generator": "tools/generate_vectors.py",
        "dimensions": [N, N],
        "file_format": "64 two-digit hexadecimal bytes, one per line; row-major element order for A, B and C",
        "model": "Exact rational arithmetic (fractions.Fraction), rounded by nearest representable-value table search",
        "numeric_policy": {
            "format": "E3M4: sign[7], exponent[6:4] bias 3, fraction[3:0]",
            "normal_range": "0.25 through 15.5 in magnitude",
            "exponent_zero": "All exponent-zero inputs are treated as signed zero; no denormals",
            "underflow": "Every nonzero exact magnitude below 0.25 is flushed to signed zero before rounding, exception=1",
            "rounding": "Round nearest, ties to even; inexact rounding alone is not an exception",
            "overflow": "Round into exponent seven -> signed infinity, exception=1",
            "special_values": "Infinity and NaN operands/results assert the combined exception; canonical NaN=0x78",
            "accumulation": "For each C[row,col], start +0; for k=0..7 round A[row,k]*B[k,col], then round accumulator+product; no fused MAC",
            "flags": "Bit 0: OR of all multiply/add exception events; bits 15:1 zero; no per-cause flag distinction",
        },
        "cases": tests,
    }
    outputs["manifest.json"] = json.dumps(manifest, indent=2) + "\n"
    return outputs


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path,
                        default=Path(__file__).resolve().parents[1] / "vectors")
    parser.add_argument("--check", action="store_true",
                        help="Verify checked-in files exactly match regeneration; do not write")
    args = parser.parse_args()
    outputs = generate()
    if args.check:
        mismatches = [name for name, content in outputs.items()
                      if not (args.output_dir / name).is_file()
                      or (args.output_dir / name).read_text() != content]
        if mismatches:
            parser.exit(1, "Vector mismatch: " + ", ".join(mismatches) + "\n")
        print(f"PASS: {len(outputs)} generated vector/manifest files are reproducible")
    else:
        args.output_dir.mkdir(parents=True, exist_ok=True)
        for name, content in outputs.items():
            (args.output_dir / name).write_text(content, encoding="ascii")
        print(f"Wrote {len(outputs)} files to {args.output_dir}")
    for case in json.loads(outputs["manifest.json"])["cases"]:
        print(f"{case['name']}: expected flags={case['expected_flags_hex']}")


if __name__ == "__main__":
    main()
