# ==============================================================================
# Makefile VCS - Cadmicro Environment
# ==============================================================================

TEST ?= usb20_base_test

VCS       = vcs
VCS_FLAGS = -sverilog -full64 -ntb_opts uvm-1.2 -debug_access+all -timescale=1ns/1ps

INC_DIRS  = +incdir+agent \
            +incdir+tb \
            +incdir+cip_infra/str_utils \
            +incdir+cip_infra/bus_params_pkg \
            +incdir+cip_infra/dv_utils \
            +incdir+cip_infra/csr_utils \
            +incdir+cip_infra/dv_base_reg \
            +incdir+cip_infra/dv_base_agent \
            +incdir+cip_infra/dv_lib \
            +incdir+cip_infra/common_ifs

FILES = \
  tb/top_pkg.sv \
  cip_infra/common_ifs/pins_if.sv \
  tb/usb20_if.sv \
  cip_infra/str_utils/str_utils_pkg.sv \
  cip_infra/bus_params_pkg/bus_params_pkg.sv \
  cip_infra/dv_utils/dv_utils_pkg.sv \
  cip_infra/dv_base_reg/dv_base_reg_pkg.sv \
  cip_infra/csr_utils/csr_utils_pkg.sv \
  cip_infra/dv_base_agent/dv_base_agent_pkg.sv \
  agent/usb20_agent_pkg.sv \
  tb/tb.sv

all: compile run

compile:
	$(VCS) $(VCS_FLAGS) $(INC_DIRS) $(FILES) -o simv

run:
	./simv +UVM_TESTNAME=$(TEST) +UVM_VERBOSITY=UVM_MEDIUM -l simv.log

clean:
	rm -rf simv simv.daidir csrc ucli.key vc_hdrs.h simv.log *.vpd *.fsdb DVEfiles
