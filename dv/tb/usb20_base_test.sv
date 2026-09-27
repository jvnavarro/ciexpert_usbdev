class usb20_base_test extends uvm_test;
  `uvm_component_utils(usb20_base_test)

  function new(string name = "usb20_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    `uvm_info("DUMMY_TEST", "--- TESTE BASICO DO AGENTE USB 2.0 EXECUTADO COM SUCESSO ---", UVM_LOW)
    #100ns;
    phase.drop_objection(this);
  endtask
endclass
