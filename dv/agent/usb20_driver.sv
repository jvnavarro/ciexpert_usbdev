class usb20_driver extends dv_base_driver #(
  .ITEM_T(usb_transaction),
  .CFG_T (usb20_agent_cfg)
);

  `uvm_component_utils(usb20_driver)

  virtual usb20_if vif;

  function new(string name = "usb20_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual usb20_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal(`gfn, "Nao foi possivel obter a virtual interface 'vif' do config_db!")
    end
  endfunction

  virtual task run_phase(uvm_phase phase);
    super.run_phase(phase);
    
    forever begin
      seq_item_port.get_next_item(req);
      
      // Log TRACE corrigido sem erro de sintaxe
      `uvm_info(`gfn, {"TRACE: Transacao recebida:\n", req.sprint()}, UVM_HIGH)
      
      // Logica de manipulacao dos pinos na vif...
      
      seq_item_port.item_done();
    end
  endtask

endclass
