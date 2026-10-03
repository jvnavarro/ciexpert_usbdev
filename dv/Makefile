# ==============================================================================
# Makefile DV - usbdev (UVM + CIP lib OpenTitan) - Synopsys VCS
# ==============================================================================
# Uso:
#   make                      -> compila e roda o smoke (usbdev_base_test + usbdev_smoke_vseq)
#   make compile              -> apenas compila
#   make sim TEST_SEQ=<vseq>  -> roda uma vseq com o binario ja compilado
#   make clean
# O teste segue o fluxo da CIP: TEST escolhe a classe de teste (+UVM_TESTNAME) e
# TEST_SEQ escolhe a sequencia virtual executada por ela (+UVM_TEST_SEQ).
# ==============================================================================

# Raiz do repositorio (os filelists usam caminhos relativos a ela)
ROOT_DIR    := $(abspath ..)
OUT_DIR     ?= $(CURDIR)/out

# Configuracoes de simulacao
TEST        ?= usbdev_base_test
TEST_SEQ    ?= usbdev_smoke_vseq
VERBOSITY   ?= UVM_LOW
SEED        ?= 1
WAVE        ?= 0
GUI         ?= 0
PLUSARGS    ?=

# Ferramentas (carregadas via 'module load vcs verdi' se nao estiverem no PATH)
VCS_MODULE  ?= vcs/W-2024.09-SP2-3
VCS         ?= vcs
VERDI       ?= verdi

# Filelists: RTL do usbdev + testbench (CIP lib, agente, env, testes, tb)
FLIST_RTL   = $(ROOT_DIR)/flist_rtl.f
FLIST_TB    = $(ROOT_DIR)/flist_tb.f

# Flags de compilacao
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

# Flags de execucao
SIM_LOG     = $(OUT_DIR)/sim_$(TEST_SEQ)_$(SEED).log
SIMV_FLAGS  = +UVM_TESTNAME=$(TEST)
SIMV_FLAGS += +UVM_TEST_SEQ=$(TEST_SEQ)
SIMV_FLAGS += +UVM_VERBOSITY=$(VERBOSITY)
SIMV_FLAGS += +ntb_random_seed=$(SEED)
SIMV_FLAGS += +UVM_NO_RELNOTES
SIMV_FLAGS += -l $(SIM_LOG)
SIMV_FLAGS += $(PLUSARGS)

ifeq ($(GUI), 1)
  SIMV_FLAGS += -gui=verdi
endif

# Carrega o modulo do VCS se o binario nao estiver no PATH
ENV_SETUP   = if ! command -v $(VCS) >/dev/null 2>&1; then \
                source /usr/share/Modules/init/bash && module load $(VCS_MODULE); \
              fi

SHELL       := /bin/bash

.PHONY: all compile sim run smoke wave clean help

all: run

run: compile sim

smoke:
	$(MAKE) run TEST=usbdev_base_test TEST_SEQ=usbdev_smoke_vseq

compile:
	@mkdir -p $(OUT_DIR)
	@$(ENV_SETUP); cd $(ROOT_DIR) && $(VCS) $(VCS_FLAGS)

sim:
	@test -x $(OUT_DIR)/simv || { echo ">>> [ERRO] $(OUT_DIR)/simv nao encontrado. Rode 'make compile'."; exit 1; }
	@$(ENV_SETUP); cd $(OUT_DIR) && ./simv $(SIMV_FLAGS)
	@grep -q "TEST PASSED CHECKS" $(SIM_LOG) && echo ">>> $(TEST_SEQ) (seed $(SEED)): PASSED" || \
	  { echo ">>> $(TEST_SEQ) (seed $(SEED)): FAILED - veja $(SIM_LOG)"; exit 1; }

wave:
	@$(ENV_SETUP); cd $(OUT_DIR) && $(VERDI) -ssf sim_waves.fsdb &

clean:
	rm -rf $(OUT_DIR)

help:
	@echo "make [run|compile|sim|smoke|wave|clean] [TEST=$(TEST)] [TEST_SEQ=$(TEST_SEQ)] [SEED=$(SEED)] [VERBOSITY=$(VERBOSITY)] [WAVE=0|1] [GUI=0|1] [PLUSARGS=...]"
