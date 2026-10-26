SHELL := /bin/bash
.SHELLFLAGS := -e -o pipefail -c

VCS ?= vcs
VERDI ?= verdi
VERILATOR ?= verilator
IVERILOG ?= iverilog
VVP ?= vvp
PYTHON ?= python3
CASE ?= all
TOP := tb_matmul_apb
RTL := $(shell cat rtl/files.f)

.PHONY: help vectors unit compile sim waves compile-vcd sim-vcd verilator regress exception clean
help:
	@echo 'Apporto: make compile; make sim CASE=all; make sim CASE=exception; make waves'
	@echo 'Portable: make unit (Icarus); make verilator; make regress'
	@echo 'FSDB requires VCS with Verdi integration configured in your shell.'

build logs:
	mkdir -p $@

vectors:
	$(PYTHON) tools/generate_vectors.py --check

unit: | build logs
	$(IVERILOG) -g2012 -I tb -s tb_apb_matmul_csr -o build/csr.vvp rtl/lab3_apb_pkg.sv rtl/apb_matmul_csr.sv tb/tb_apb_matmul_csr.sv 2>&1 | tee logs/csr_compile.log
	$(VVP) build/csr.vvp 2>&1 | tee logs/csr_run.log

# Exact delivered RTL is compiled; no rewriting of the supplied FP modules.
compile: | build logs
	$(VCS) -full64 -sverilog -timescale=1ns/1ps -top $(TOP) -debug_access+all -kdb -lca +define+FSDB +incdir+tb -f rtl/files.f tb/$(TOP).sv -Mdir=build/csrc -o build/simv 2>&1 | tee logs/vcs_compile.log

sim: | build logs
	./build/simv +case=$(CASE) 2>&1 | tee logs/vcs_$(CASE).log

waves:
	$(VERDI) -dbdir build/simv.daidir -ssf build/part4.fsdb -nologo

# Useful if FSDB integration is not available in a particular VCS setup.
compile-vcd: | build logs
	$(VCS) -full64 -sverilog -timescale=1ns/1ps -top $(TOP) -debug_access+all -kdb -lca +incdir+tb -f rtl/files.f tb/$(TOP).sv -Mdir=build/csrc -o build/simv_vcd 2>&1 | tee logs/vcs_vcd_compile.log

sim-vcd: | build logs
	./build/simv_vcd +case=$(CASE) 2>&1 | tee logs/vcs_vcd_$(CASE).log

verilator: | build logs
	$(VERILATOR) --binary --timing --trace -Wno-fatal --top-module $(TOP) --Mdir build/verilator -j 2 +incdir+tb $(RTL) tb/$(TOP).sv > logs/verilator_compile.log 2>&1 || { tail -n 80 logs/verilator_compile.log; exit 1; }

regress: | build logs
	./build/verilator/V$(TOP) +case=all 2>&1 | tee logs/verilator_all.log

exception: | build logs
	./build/verilator/V$(TOP) +case=exception +waves=build/part4_exception.vcd 2>&1 | tee logs/verilator_exception.log

clean:
	rm -rf build logs
