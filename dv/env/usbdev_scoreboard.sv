class usbdev_scoreboard extends cip_base_scoreboard #(
  .CFG_T(usbdev_env_cfg),
  .BASE_REG_BLK_T(dv_base_reg_block),
  .COV_T(usbdev_env_cov)
);

  // 1. Registo na fábrica do UVM
  `uvm_component_utils(usbdev_scoreboard)

  // 2. Construtor padrão
  function new(string name = "usbdev_scoreboard", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // 3. Fase de construção
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  // 4. Fase de conexão
  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
  endfunction

endclass