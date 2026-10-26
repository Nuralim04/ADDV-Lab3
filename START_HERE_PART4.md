# Start here: Lab 3 Part 4 integrated with team Part 3

The uploaded PART1, PART2, and PART3 directories are preserved as received.
PART4 contains the completed APB integration using the actual team 8x8 array,
with two demonstrated array defects corrected in its local copy.

## Run the integrated design

Open a terminal in PART4 and use:

```bash
bash
source env.sh
make compile
make sim CASE=all
```

Then follow PART4/docs/APPORTO_WALKTHROUGH.md to preserve the full waveform,
run the exception case, and capture the required annotated Verdi screenshots.

## Read these files

- PART4/README.md: contents, status, and commands.
- PART4/docs/PART4_REPORT_SECTION.md: updated report text.
- PART4/docs/PART3_HANDOFF.md: the two confirmed defects and their fixes.
- PART4/verification/SUMMARY.md: current results and exact timing.

The old Part 3 files still contain the defects documented by the before/after
audit. Build from PART4 for the corrected APB design. Coordinate adoption of
PART4/rtl/matmul_8x8.sv with the Part 3 owner before final team submission;
its diagram, report, and synthesis should match whichever core is submitted.
The existing Part 3 synthesis reports were preserved, not regenerated.
