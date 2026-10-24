# Synopsys Design Compiler targets for the Part 1 asynchronous FIFO.
# Source ../env.cshrc from Part1_Async_FIFO before invoking make.
SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -c

.PHONY: all synth clean clean_synth

# Keep the generated netlist, constraints, reports, and log after synthesis.
all: synth

# Run the Tcl flow; pipefail makes make report a dc_shell failure through tee.
synth:
	dc_shell-t -f compile_dc.tcl |& tee synth.log

# Remove generated Design Compiler products and reports, preserving sources.
clean_synth:
	rm -rf WORK *.syn *.pvl *.mr *.svf command.log default.svf

clean: clean_synth
	rm -f *.rep synth.log fifo_wrapper.v fifo_wrapper.sdc
