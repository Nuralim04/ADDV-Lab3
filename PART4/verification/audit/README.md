# Original and corrected team Part 3 audit

These logs document the actual team-source comparison that led to the two
array corrections. `team_directed_audit.sv` uses A=identity and 64 distinct
positive B elements, initializes guard locations to `deadbeef`, counts every
C write, and reports all output and guard mismatches.

`directed_run.log` is the deliberately defective original baseline:
16 numerical mismatches, six modified guard words, 11 writes per bank.
`corrected_run.log` is the same harness and original RAM/control wrapper,
with only the corrected array substituted: zero mismatches, zero guard
changes, eight writes per bank.

The directed audit prints a summary for both variants; check that summary,
not merely the process exit code. The production Part 4 regression uses
fatal assertions and independent golden vectors instead.

`original_run.log` replays the team’s own two uniform tests, both of which
pass even with the original defects. Its scratch testbench changed only two
unsupported FSDB dump calls for the local Verilator run.

`unmodified_team_array_integration.log` records the Part 4 monitor stopping
the uncorrected array at the first ninth C-bank write. Original uploaded
files are preserved in the ZIP’s PART3 directory.
