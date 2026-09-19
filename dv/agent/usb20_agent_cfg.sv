class usb20_agent_cfg extends dv_base_agent_cfg; // da biblioteca CIP

  // 1. Registo na fábrica do UVM (UVM Factory) como uvm_object
  `uvm_object_utils(usb20_agent_cfg)

  // 2. Construtor padrão
  function new(string name = "usb20_agent_cfg");
    super.new(name);
  endfunction

endclass