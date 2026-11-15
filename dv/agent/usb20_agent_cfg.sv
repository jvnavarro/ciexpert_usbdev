class usb20_agent_cfg extends dv_base_agent_cfg;  // from the CIP library

  `uvm_object_utils(usb20_agent_cfg)
  bit pinflip = 1'b0;  // 1: swap the D+ and D- pins on the bus

  function new(string name = "usb20_agent_cfg");
    super.new(name);
  endfunction

endclass
