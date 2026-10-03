class usbdev_base_test extends cip_base_test #(
  .ENV_T(usbdev_env), 
  .CFG_T(usbdev_env_cfg),
  .VSQR_T(usbdev_virtual_sequencer)
);
  `uvm_component_utils(usbdev_base_test)

  function new(string name = "usbdev_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  // NÃO COLOQUE A RUN_PHASE AQUI.
  // A classe pai 'cip_base_test' já cuida do randomize() e start() da sequência
  // baseada na variável TEST_SEQ do seu Makefile!

endclass