# ==============================================================================
# Makefile para Verificacao UVM do Modulo USB 2.0 (OpenTitan usbdev)
# Simulador padrao: Synopsys VCS
# ==============================================================================

# Diretorio para artefatos de compilacao e simulacao
OUT_DIR     ?= out

# Configuracoes de simulacao
TEST        ?= usbdev_base_test
TEST_SEQ    ?= usbdev_base_vseq
VERBOSITY   ?= UVM_LOW
SEED        ?= 1
GUI         ?= 0
WAVE        ?= 1
PLUSARGS    ?=

# Binarios e ferramentas Synopsys
VCS         = vcs
VERDI       = verdi

# Filelists (RTL e Testbench separados)
FLIST_RTL   = flist_rtl.f
FLIST_TB    = flist_tb.f

# Flags do compilador VCS
VCS_FLAGS   = -sverilog -full64 -timescale=1ns/1ps
VCS_FLAGS  += -ntb_opts uvm-1.2
VCS_FLAGS  += +define+UVM
VCS_FLAGS  += +define+INC_ASSERT
VCS_FLAGS  += -debug_access+all -kdb -lca
VCS_FLAGS  += +vcs+lic+wait
VCS_FLAGS  += -top tb
VCS_FLAGS  += -f $(FLIST_RTL) -f $(FLIST_TB)
VCS_FLAGS  += -o $(OUT_DIR)/simv
VCS_FLAGS  += -Mdir=$(OUT_DIR)/csrc
VCS_FLAGS  += -l $(OUT_DIR)/compile.log

# Dumps de onda (FSDB para Verdi por padrao quando WAVE=1)
ifeq ($(WAVE), 1)
  VCS_FLAGS += +define+DUMP_FSDB
endif

# Flags de execucao do simv (executado a partir do OUT_DIR)
SIMV_FLAGS  = +UVM_TESTNAME=$(TEST)
SIMV_FLAGS += +UVM_TEST_SEQ=$(TEST_SEQ)
SIMV_FLAGS += +UVM_VERBOSITY=$(VERBOSITY)
SIMV_FLAGS += +ntb_random_seed=$(SEED)
SIMV_FLAGS += +UVM_REGEX_NO_DPI
SIMV_FLAGS += -l sim_$(TEST)_$(TEST_SEQ)_$(SEED).log
SIMV_FLAGS += $(PLUSARGS)

ifeq ($(GUI), 1)
  SIMV_FLAGS += -gui=verdi
endif

.PHONY: all help compile sim run wave verdi clean

# Alvo padrao: compila e roda a simulacao
all: compile sim

help:
	@echo "=================================================================="
	@echo " Makefile - Verificacao USB 2.0 (usbdev)"
	@echo "=================================================================="
	@echo " make compile               : Compila o RTL e o TB UVM com o VCS gerando em $(OUT_DIR)/"
	@echo " make sim [TEST=...]        : Executa a simulacao com o teste indicado"
	@echo " make run [TEST=...]        : Compila e roda em seguida"
	@echo " make run GUI=1             : Compila e roda abrindo a GUI do Verdi"
	@echo " make verdi / make wave     : Abre o Verdi com o dump FSDB gerado"
	@echo " make clean                 : Limpa pasta de build/out e logs"
	@echo "=================================================================="
	@echo " Variaveis configuraveis:"
	@echo "   OUT_DIR   (padrao: $(OUT_DIR)) [diretorio para binarios e logs]"
	@echo "   TEST      (padrao: $(TEST))"
	@echo "   TEST_SEQ  (padrao: $(TEST_SEQ))"
	@echo "   VERBOSITY (padrao: $(VERBOSITY)) [UVM_NONE, UVM_LOW, UVM_HIGH, UVM_DEBUG]"
	@echo "   SEED      (padrao: $(SEED))"
	@echo "   WAVE      (padrao: $(WAVE)) [1 para habilitar FSDB, 0 para desabilitar]"
	@echo "   PLUSARGS  (padrao: vazio) [ex: PLUSARGS=\"+foo=1\"]"
	@echo "=================================================================="

# Compilacao com VCS direcionada para OUT_DIR
compile:
	@echo ">>> [VCS] Criando diretorio de saida: $(OUT_DIR)..."
	@mkdir -p $(OUT_DIR)
	@echo ">>> [VCS] Compilando RTL e Testbench UVM..."
	$(VCS) $(VCS_FLAGS)

# Execucao do executavel gerado pelo VCS (simv) dentro de OUT_DIR
sim:
	@if [ ! -f $(OUT_DIR)/simv ]; then \
		echo ">>> [ERRO] Binario $(OUT_DIR)/simv nao encontrado. Execute 'make compile' primeiro."; \
		exit 1; \
	fi
	@echo ">>> [SIMV] Executando simulacao em $(OUT_DIR): TEST=$(TEST) SEED=$(SEED)..."
	cd $(OUT_DIR) && ./simv $(SIMV_FLAGS)

run: compile sim

# Abre o visualizador Verdi
wave: verdi

verdi:
	@if [ -f $(OUT_DIR)/sim_waves.fsdb ]; then \
		echo ">>> [VERDI] Abrindo simulacao no Verdi..."; \
		$(VERDI) -ssf $(OUT_DIR)/sim_waves.fsdb & \
	elif [ -f sim_waves.fsdb ]; then \
		echo ">>> [VERDI] Abrindo simulacao no Verdi..."; \
		$(VERDI) -ssf sim_waves.fsdb & \
	else \
		echo ">>> [VERDI] Arquivo sim_waves.fsdb nao encontrado em $(OUT_DIR)/. Execute com WAVE=1 antes."; \
	fi

# Limpeza de diretorio
clean:
	@echo ">>> Limpando arquivos de compilacao e simulacao..."
	rm -rf $(OUT_DIR)
	rm -rf simv simv.daidir simv.vdb csrc *.log *.key *.fsdb *.vcd ucli.key vc_hdrs.h DVEfiles verdi* novas* *.conf
