class usb20_monitor extends dv_base_monitor #(
  .ITEM_T(usb_transaction),
  .CFG_T (usb20_agent_cfg)
);

  // Sem ponto e virgula no final da macro!
  `uvm_component_utils(usb20_monitor)

  virtual usb20_if vif;

  function new(string name = "usb20_monitor", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual usb20_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal(`gfn, "Nao foi possivel obter a virtual interface 'vif' do config_db no Monitor!")
    end
  endfunction

  // Chamada pelo run_phase do dv_base_monitor
  virtual protected task collect_trans();
    forever begin
      @(posedge vif.clk_i);
      // Leitura passiva dos pinos no futuro...
    end
  endtask

endclass
