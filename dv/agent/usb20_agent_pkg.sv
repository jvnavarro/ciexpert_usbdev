package usb20_agent_pkg;

  // 1. Import global dependencies
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  import dv_utils_pkg::*;
  import dv_base_reg_pkg::*;
  import dv_base_agent_pkg::*;

  // 2. Include the agent files (order matters)
  `include "usb_transaction.sv"
  `include "usb20_agent_cfg.sv"
  `include "usb20_sequencer.sv"
  `include "usb20_seq_list.sv"
  `include "usb20_driver.sv"
  `include "usb20_monitor.sv"
  `include "usb20_agent.sv"

endpackage : usb20_agent_pkg