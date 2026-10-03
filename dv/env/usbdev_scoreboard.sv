class usbdev_scoreboard extends cip_base_scoreboard #(
  .CFG_T(usbdev_env_cfg),
  .RAL_T(usbdev_reg_block),
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

  // 5. Processamento de acessos TL-UL para predição dos registradores
  virtual task process_tl_access(tl_seq_item item, tl_channels_e channel, string ral_name);
    uvm_reg csr;
    bit     write = item.is_write();
    uvm_reg_addr_t csr_addr = cfg.ral_models[ral_name].get_word_aligned_addr(item.a_addr);

    bit addr_phase_write = (write && channel == AddrChannel);
    bit data_phase_read  = (!write && channel == DataChannel);

    csr = cfg.ral_models[ral_name].get_default_map().get_reg_by_offset(csr_addr);
    if (csr == null) return;

    // Se for escrita, atualiza a predicao do registrador imediatamente no RAL
    if (addr_phase_write) begin
      void'(csr.predict(.value(item.a_data), .kind(UVM_PREDICT_WRITE), .be(item.a_mask)));
    end

    // Se for leitura, sincroniza a leitura
    if (data_phase_read) begin
      void'(csr.predict(.value(item.d_data), .kind(UVM_PREDICT_READ)));
    end
  endtask

endclass
