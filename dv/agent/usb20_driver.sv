
class usb20_driver extends dv_base_driver #(
  .ITEM_T (usb_transaction),
  .CFG_T  (usb20_agent_cfg)
);

  `uvm_component_utils(usb20_driver)

  function new(string name = "usb20_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  virtual task run_phase(uvm_phase phase);
    super.run_phase(phase);
  endtask
// O run_phase é necessário porque é a única fase onde o tempo da simulação avança
endclass