class usbdev_scoreboard extends cip_base_scoreboard #( .CFG_T(usbdev_env_cfg),.BASE_REG_BLK_T(dv_base_reg_block),.COV_T(usbdev_env_cov));
  `uvm_component_utils(usbdev_scoreboard)

  function new(string name = "usbdev_scoreboard", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
  endfunction

  // Acessos TL-UL: obrigatorio sobrescrever (a classe base da CIP da fatal se chamada).
  //    Checagens dos CSRs serao implementadas no futuro.
  virtual task process_tl_access(tl_seq_item item, tl_channels_e channel, string ral_name);
  endtask

endclass