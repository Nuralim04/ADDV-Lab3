SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -c

# ============================================================
# Synopsys setup
# ============================================================

VCS_HOME ?= /usr/local2/synopsys/vcs_2024/vcs/W-2024.09-SP2-3
VERDI_HOME ?= /usr/local2/synopsys/verdi_2024.09/verdi_2024

LM_LICENSE_FILE ?= 27020@enlicense5.eas.asu.edu
SNPSLMD_LICENSE_FILE ?= $(LM_LICENSE_FILE)

export VCS_HOME VERDI_HOME LM_LICENSE_FILE SNPSLMD_LICENSE_FILE

VCS := $(VCS_HOME)/bin/vcs
VERDI := $(VERDI_HOME)/bin/verdi


# ============================================================
# Directories
# ============================================================

RTL_DIR := ../RTL
TB_DIR := ../TESTBENCH


# ============================================================
# Top-level module
# ============================================================

TOP_MODULE := matmul_8x8_tb


# ============================================================
# RTL source files
# ============================================================

SV_SOURCES := \
	$(RTL_DIR)/fp8_adder.sv \
	$(RTL_DIR)/fp8_multiplier.sv \
	$(RTL_DIR)/matmul.sv \
	$(RTL_DIR)/matmul_8x8.sv \
	$(RTL_DIR)/matmul_with_ram.sv \
	$(TB_DIR)/matmul_with_ram_tb.sv


# ============================================================
# Targets
# ============================================================

.PHONY: all compile run compile_verdi sim_verdi verdi waves_verdi clean

all: compile


# ============================================================
# Compile / elaborate the 8x8 design
# ============================================================

compile:
	$(VCS) -full64 -sverilog -timescale=1ns/1ps \
		-top $(TOP_MODULE) \
		$(SV_SOURCES) \
		-debug_access+all \
		-o simv \
		|& tee compile.log


# Compile and run the testbench.
run: compile
	./simv


# ============================================================
# Compile with Verdi support
# ============================================================

compile_verdi:
	$(VCS) -full64 -sverilog -timescale=1ns/1ps \
		-top $(TOP_MODULE) \
		$(SV_SOURCES) \
		-debug_access+all \
		-kdb -lca \
		-o simv \
		|& tee compile_verdi.log


# Run the Verdi-enabled simulation and refresh its waveform file.
sim_verdi: compile_verdi
	rm -f matmul_8x8.fsdb
	./simv 2>&1 | tee sim_verdi.log


# ============================================================
# Open elaborated design in Verdi
# ============================================================

verdi: compile_verdi
	$(VERDI) -dbdir ./simv.daidir -nologo


# Run the simulation, then open its FSDB waveform in Verdi.
waves_verdi: sim_verdi
	$(VERDI) -dbdir ./simv.daidir -ssf matmul_8x8.fsdb -nologo


# ============================================================
# Clean
# ============================================================

clean:
	rm -rf *.log *.h csrc DVEFiles simv.daidir simv ucli.key \
	vcdplus.vpd *.syn *.pvl *.mr *.svf command.log *.txt \
	 novas.conf novas.rc verdi_config_file verdiLog novas.fsdb matmul_8x8.fsdb \
	novas.log novas_dump.log