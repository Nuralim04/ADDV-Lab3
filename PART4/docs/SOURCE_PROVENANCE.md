# Source provenance for the actual-team integration

Input: `ADDV-Lab3-main (1).zip`, `PART3/RTL/`. The final ZIP retains the uploaded Parts 1–3 unchanged and adds PART4. Only the copied array in PART4 contains the reviewed core corrections.

The earlier companion array and its size-dependent 4x4-tile timing patch are not used. Combining that old tile patch with this team array would invalidate the retained C-address compensation.

## Source hashes

### rtl/vendor/fp8_adder.sv

- Source: `ADDV-Lab3-main/PART3/RTL/fp8_adder.sv`
- Original SHA-256: `0848aae2c9786b181f5741dc988740ef1448550413b1414306052ef4233a3a3f`
- Delivered SHA-256: `0848aae2c9786b181f5741dc988740ef1448550413b1414306052ef4233a3a3f`
- Byte-identical: True

### rtl/vendor/fp8_multiplier.sv

- Source: `ADDV-Lab3-main/PART3/RTL/fp8_multiplier.sv`
- Original SHA-256: `d5c67e0876c2b9e37a5f1f465404fa5a880c69d3e4638bc36e3625dd5490668e`
- Delivered SHA-256: `d5c67e0876c2b9e37a5f1f465404fa5a880c69d3e4638bc36e3625dd5490668e`
- Byte-identical: True

### rtl/vendor/matmul.sv

- Source: `ADDV-Lab3-main/PART3/RTL/matmul.sv`
- Original SHA-256: `5161d9a7fafca0c9218dea7ab36258a3b943eb017c60ccaf5316f59d4b09ce72`
- Delivered SHA-256: `5161d9a7fafca0c9218dea7ab36258a3b943eb017c60ccaf5316f59d4b09ce72`
- Byte-identical: True

### rtl/matmul_8x8.sv

- Source: `ADDV-Lab3-main/PART3/RTL/matmul_8x8.sv`
- Original SHA-256: `111b8eedf3cc25ae30677f4cdb465cbbb7de9b9a4323e62eea30fcd801584604`
- Delivered SHA-256: `55ce26cec02819c49020b724f200e3a8136de4d8dfca16f2e303b34d6283c62c`
- Byte-identical: False

## Changes and preserved behavior

`patches/team_part3_array.patch` documents every difference in the copied 8x8 array. It fixes the bottom-right operand sources and bounds both output-valid streams with four-bit counters. Comments identify the actual mathematical quadrants. The original tile, FP8 units, C-address compensation, and independent completion counter remain unchanged.

`rtl/apb_matmul_csr.sv` provides the APB register/lifecycle logic. The new RAM wrapper replaces the old standalone control FSM with PREP/RUN control from that APB module. It retains six banks and the same matrix packing but groups each pair into a 64-bit external view. The RAM implements individual byte write enables; the original team RAM treated any nonzero enable as a whole-word write. The matrix testbench uses full-word initialization.

The uploaded Part 3 synthesis reports and mapped netlist are archived as received. They do not prove synthesis results for the corrected array or APB integration. The current local simulation logs and VCDs are in `verification/`; original and corrected replay logs are in `verification/audit/`.

The original APB scaffold and original Part 3 RAM/control wrapper are excluded from the Part 4 build. `rtl/files.f` lists the exact source order. The independent audit separately uses the original RAM/control wrapper to establish that the one-file array patch fixes the demonstrated defects.
