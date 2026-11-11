
import uvm_pkg::*;
`include "uvm_macros.svh"

import cip_base_pkg::*;

// Extends cip_base_env_cfg, which provides the base OpenTitan/CIP configuration
class usbdev_env_cfg extends cip_base_env_cfg #(.RAL_T(usbdev_reg_block));

  `uvm_object_utils(usbdev_env_cfg)

  usb20_agent_cfg m_usb20_agent_cfg;

  // USB Full Speed: usbdev clock fixed at 48 MHz (overrides the random constraint from dv_base)
  constraint clk_freq_mhz_c {
    clk_freq_mhz == 48;
  }

  function new(string name = "usbdev_env_cfg");
    super.new(name);
  endfunction

  // Initialization: alerts, interrupts and RAL
  virtual function void initialize(bit inherit_ral_models = 1'b0);
    list_of_alerts = usbdev_env_pkg::LIST_OF_ALERTS;
    super.initialize(inherit_ral_models);
    en_cov = 1'b1;
    m_usb20_agent_cfg = usb20_agent_cfg::type_id::create("m_usb20_agent_cfg");

    // The DUT supports only one outstanding request at a time
    m_tl_agent_cfgs[RAL_T::type_name].max_outstanding_req = 1;

    num_interrupts = ral.intr_state.get_n_used_bits();
  endfunction

endclass
