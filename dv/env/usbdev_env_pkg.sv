// Pacote do ambiente usbdev (padrao CIP OpenTitan)
// Agrupa cfg, cobertura, sequenciador virtual, scoreboard, env e as vseqs.
package usbdev_env_pkg;

  import uvm_pkg::*;
  import top_pkg::*;
  import dv_utils_pkg::*;
  import dv_base_reg_pkg::*;
  import csr_utils_pkg::*;
  import tl_agent_pkg::*;
  import cip_base_pkg::*;
  import usbdev_ral_pkg::*;
  import usb20_agent_pkg::*;

  `include "uvm_macros.svh"
  `include "dv_macros.svh"

  // Parametros do DUT
  parameter string LIST_OF_ALERTS[] = {"fatal_fault"};
  parameter uint   NUM_ALERTS       = 1;

  // Ambiente
  `include "usbdev_env_cfg.sv"
  `include "usbdev_env_cov.sv"
  `include "usbdev_virtual_sequencer.sv"
  `include "usbdev_scoreboard.sv"
  `include "usbdev_env.sv"

  // Sequencias virtuais
  `include "usbdev_base_vseq.sv"
  `include "usbdev_smoke_vseq.sv"

endpackage : usbdev_env_pkg
