// ==============================================================================
// Filelist: Testbench UVM com CIP_LIB (ciexpert_usbdev)
// ==============================================================================

// Include directories
+incdir+dv/cip_infra/str_utils
+incdir+dv/cip_infra/bus_params_pkg
+incdir+dv/cip_infra/dv_utils
+incdir+dv/cip_infra/csr_utils
+incdir+dv/cip_infra/dv_base_reg
+incdir+dv/cip_infra/dv_base_agent
+incdir+dv/cip_infra/dv_lib
+incdir+dv/cip_infra/mem_model
+incdir+dv/cip_infra/sec_cm
+incdir+dv/cip_infra/mem_bkdr_util
+incdir+dv/cip_infra/tl_agent
+incdir+dv/cip_infra/tl_agent/seq_lib
+incdir+dv/cip_infra/alert_esc_agent
+incdir+dv/cip_infra/alert_esc_agent/seq_lib
+incdir+dv/cip_infra/push_pull_agent
+incdir+dv/cip_infra/push_pull_agent/seq_lib
+incdir+dv/cip_infra/cip_lib
+incdir+dv/cip_infra/cip_lib/seq_lib
+incdir+dv/cip_infra/common_ifs
+incdir+dv/cip_infra/ral
+incdir+dv/cip_infra/usbdpi
+incdir+dv/agent
+incdir+dv/env
+incdir+dv/tests

// 1. Pacotes DV Fundamentais (ordem de dependência):
dv/cip_infra/bus_params_pkg/bus_params_pkg.sv
dv/cip_infra/str_utils/str_utils_pkg.sv
dv/cip_infra/dv_utils/dv_test_status_pkg.sv
dv/cip_infra/dv_utils/dv_utils_pkg.sv
dv/cip_infra/common_ifs/common_ifs_pkg.sv
dv/cip_infra/dv_base_reg/dv_base_reg_pkg.sv
dv/cip_infra/csr_utils/csr_utils_pkg.sv
dv/cip_infra/dv_base_agent/dv_base_agent_pkg.sv
dv/cip_infra/dv_lib/dv_lib_pkg.sv
dv/cip_infra/mem_model/mem_model_pkg.sv
dv/cip_infra/sec_cm/sec_cm_pkg.sv
dv/cip_infra/mem_bkdr_util/mem_bkdr_util_pkg.sv
dv/cip_infra/tl_agent/tl_agent_pkg.sv
dv/cip_infra/alert_esc_agent/alert_esc_agent_pkg.sv
dv/cip_infra/push_pull_agent/push_pull_agent_pkg.sv
dv/cip_infra/cip_lib/cip_base_pkg.sv
dv/cip_infra/ral/usbdev_ral_pkg.sv

// 2. Pacote do Agente USB 2.0 (do projeto):
dv/agent/usb20_agent_pkg.sv

// 3. Interfaces:
dv/cip_infra/common_ifs/clk_rst_if.sv
dv/cip_infra/common_ifs/pins_if.sv
dv/cip_infra/common_ifs/rst_shadowed_if.sv
dv/cip_infra/tl_agent/tl_if.sv
dv/cip_infra/alert_esc_agent/alert_esc_if.sv
dv/cip_infra/alert_esc_agent/alert_esc_probe_if.sv
dv/cip_infra/push_pull_agent/push_pull_if.sv
dv/tb/usb20_if.sv

// 4. Testbench Top-Level:
dv/tb/tb.sv
