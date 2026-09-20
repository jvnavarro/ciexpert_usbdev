// Sequenciador do agente USB 2.0
// Herda da classe base de sequenciadores do OpenTitan (dv_base_sequencer)
class usb20_sequencer extends dv_base_sequencer #(
  .ITEM_T (usb_transaction),
  .CFG_T  (usb20_agent_cfg)
);

  `uvm_component_utils(usb20_sequencer)

  function new(string name = "usb20_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction

endclass