class usb20_agent extends dv_base_agent #(
    .CFG_T(usb20_agent_cfg),
    .DRIVER_T(usb20_driver),
    .SEQUENCER_T(usb20_sequencer),
    .MONITOR_T(usb20_monitor)
);
  `uvm_component_utils(usb20_agent)

  function new(string name = "usb20_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // Build phase: creates the subcomponents (monitor, driver)
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  // Connect phase: connects the TLM ports and interfaces
  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
  endfunction

endclass
