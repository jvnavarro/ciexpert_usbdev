
import uvm_pkg::*;
`include "uvm_macros.svh"

import cip_base_pkg::*;

// Herda de cip_base_env_cfg, que traz as configurações base do OpenTitan/CIP
class usbdev_env_cfg extends cip_base_env_cfg #(.RAL_T(usbdev_reg_block));

  `uvm_object_utils(usbdev_env_cfg)

  usb20_agent_cfg m_usb20_agent_cfg;

  function new(string name = "usbdev_env_cfg");
    super.new(name);
  endfunction

  //  Inicialização: alertas, interrupções e RAL
  virtual function void initialize(bit inherit_ral_models = 1'b0);
    list_of_alerts = usbdev_env_pkg::LIST_OF_ALERTS;
    super.initialize(inherit_ral_models);

    m_usb20_agent_cfg = usb20_agent_cfg::type_id::create("m_usb20_agent_cfg");

    num_interrupts = ral.intr_state.get_n_used_bits();
  endfunction

endclass
