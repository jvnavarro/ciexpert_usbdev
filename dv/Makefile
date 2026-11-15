# ==============================================================================
# Makefile DV - usbdev (UVM + CIP lib OpenTitan) - Synopsys VCS
# ==============================================================================
# Usage:
#   make TEST_SEQ=<vseq>      -> compile and run one vseq (default: usbdev_base_vseq, only reset + DUT init)
#   make compile              -> compile only
#   make sim TEST_SEQ=<vseq>  -> run one vseq with the binary already compiled
#   make clean
# The test follows the CIP flow: TEST selects the test class (+UVM_TESTNAME) and
# TEST_SEQ selects the virtual sequence it runs (+UVM_TEST_SEQ).
# ==============================================================================

# Repository root (the filelists use paths relative to it)
ROOT_DIR    := $(abspath ..)
OUT_DIR     ?= $(CURDIR)/out

# Simulation settings
TEST        ?= usbdev_base_test
TEST_SEQ    ?= usbdev_base_vseq
VERBOSITY   ?= UVM_LOW
SEED        ?= 1
WAVE        ?= 0
GUI         ?= 0
PLUSARGS    ?=
COV         ?= 1

# Tools (loaded with 'module load vcs verdi' if they are not in the PATH)
VCS_MODULE  ?= vcs/W-2024.09-SP2-3
VCS         ?= vcs
VERDI       ?= verdi

# Filelists: usbdev RTL + testbench (CIP lib, agent, env, tests, tb)
FLIST_RTL   = $(ROOT_DIR)/flist_rtl.f
FLIST_TB    = $(ROOT_DIR)/flist_tb.f

# Compile flags
VCS_FLAGS   = -sverilog -full64 -timescale=1ns/1ps
VCS_FLAGS  += -ntb_opts uvm-1.2
VCS_FLAGS  += +define+UVM +define+INC_ASSERT
VCS_FLAGS  += +lint=TFIPC-L -assert svaext
VCS_FLAGS  += -debug_access+all -kdb -lca
VCS_FLAGS  += +vcs+lic+wait
VCS_FLAGS  += -top tb
VCS_FLAGS  += -f $(FLIST_RTL) -f $(FLIST_TB)
VCS_FLAGS  += -o $(OUT_DIR)/simv
VCS_FLAGS  += -Mdir=$(OUT_DIR)/csrc
VCS_FLAGS  += -l $(OUT_DIR)/compile.log

ifeq ($(WAVE), 1)
  VCS_FLAGS += +define+DUMP_FSDB
endif

# Code coverage (line/cond/fsm/tgl/branch/assert) limited to the DUT (cov_hier.cfg)
COV_METRICS = line+cond+fsm+tgl+branch+assert
COV_DB      = $(OUT_DIR)/simv.vdb
COV_REPORT  = $(OUT_DIR)/urg_report
URG_FLAGS   ?= -lca -full64 +urg+lic+wait -show tests -grade index testfile -group ratio -group lrm_bin_name -group instcov_for_score
ifeq ($(COV), 1)
  VCS_FLAGS += -cm $(COV_METRICS) -cm_hier $(CURDIR)/cov_hier.cfg -cm_dir $(COV_DB)
endif

# Run flags
SIM_LOG     = $(OUT_DIR)/sim_$(TEST_SEQ)_$(SEED).log
SIMV_FLAGS  = +UVM_TESTNAME=$(TEST)
SIMV_FLAGS += +UVM_TEST_SEQ=$(TEST_SEQ)
SIMV_FLAGS += +UVM_VERBOSITY=$(VERBOSITY)
SIMV_FLAGS += +ntb_random_seed=$(SEED)
SIMV_FLAGS += +UVM_NO_RELNOTES
SIMV_FLAGS += -l $(SIM_LOG)
SIMV_FLAGS += $(PLUSARGS)

# Each run becomes a separate test in simv.vdb (urg merges them all)
ifeq ($(COV), 1)
  SIMV_FLAGS += -cm $(COV_METRICS) -cm_dir $(COV_DB) -cm_name $(TEST_SEQ)_$(SEED)
endif

ifeq ($(GUI), 1)
  SIMV_FLAGS += -gui=verdi
endif

# Load the VCS module if the binary is not in the PATH
ENV_SETUP   = if ! command -v $(VCS) >/dev/null 2>&1; then \
                source /usr/share/Modules/init/bash && module load $(VCS_MODULE); \
              fi

SHELL       := /bin/bash

.PHONY: all compile sim run cov cov_gui wave clean help

all: run

run: compile sim

compile:
	@mkdir -p $(OUT_DIR)
	@$(ENV_SETUP); cd $(ROOT_DIR) && $(VCS) $(VCS_FLAGS)

sim:
	@test -x $(OUT_DIR)/simv || { echo ">>> [ERROR] $(OUT_DIR)/simv not found. Run 'make compile'."; exit 1; }
	@$(ENV_SETUP); cd $(OUT_DIR) && ./simv $(SIMV_FLAGS)
	@grep -q "TEST PASSED CHECKS" $(SIM_LOG) && echo ">>> $(TEST_SEQ) (seed $(SEED)): PASSED" || \
	  { echo ">>> $(TEST_SEQ) (seed $(SEED)): FAILED - see $(SIM_LOG)"; exit 1; }

# Coverage report (HTML + text) merging all the runs in simv.vdb
cov:
	@test -d $(COV_DB) || { echo ">>> [ERROR] $(COV_DB) not found. Run with COV=1."; exit 1; }
	@$(ENV_SETUP); cd $(OUT_DIR) && urg $(URG_FLAGS) -dir $(COV_DB) -report $(COV_REPORT) -format both -log $(OUT_DIR)/urg.log
	@echo ">>> Report saved in $(COV_REPORT) (open dashboard.html in a browser or see dashboard.txt)"
	@cat $(COV_REPORT)/dashboard.txt

cov_gui:
	@$(ENV_SETUP); $(VERDI) -cov -covdir $(COV_DB) &

wave:
	@$(ENV_SETUP); cd $(OUT_DIR) && $(VERDI) -ssf sim_waves.fsdb &

clean:
	rm -rf $(OUT_DIR)

help:
	@echo "make [run|compile|sim|cov|cov_gui|wave|clean] [TEST=$(TEST)] [TEST_SEQ=$(TEST_SEQ)] [SEED=$(SEED)] [VERBOSITY=$(VERBOSITY)] [WAVE=0|1] [GUI=0|1] [COV=0|1] [PLUSARGS=...]"
