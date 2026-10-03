class usbdev_base_test extends cip_base_test #(
  .CFG_T        (usbdev_env_cfg),
  .ENV_T        (usbdev_env)
  ); 

  `uvm_component_utils(usbdev_base_test)

  function new(string name = "usbdev_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
     // Define a sequência padrão caso ninguém passe +UVM_TEST_SEQ na linha de comando
    test_seq_s = "usbdev_base_vseq";

  endfunction

endclass