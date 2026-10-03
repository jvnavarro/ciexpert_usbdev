class usbdev_base_vseq extends cip_base_vseq #(
  .CFG_T                  (usbdev_env_cfg),
  .RAL_T                  (usbdev_reg_block),
  .COV_T                  (usbdev_env_cov),
  .VIRTUAL_SEQUENCER_T    (usbdev_virtual_sequencer)
);

  `uvm_object_utils(usbdev_base_vseq)

  function new(string name = "usbdev_base_test");
    super.new(name);
  endfunction

  // Corpo principal da sequencia
  virtual task body();
    uvm_reg_data_t read_val;

    `uvm_info(`gfn, "=== [FASE 1] INICIANDO VALIDACAO TL-UL DO USBDEV ===", UVM_LOW)
    // 1. aplica o reset inicial sincronizando no DUT
    apply_reset();
    // 2. Le o registrador intr_enable (apos o reset, o valor padrao deve ser 0)
    csr_rd(.ptr(ral.intr_enable), .value(read_val));
    // gfn é o nome do macro, significa get_full_name()
    `uvm_info(`gfn, $sformatf(">> Valor lido de intr_enable pos-reset: 0x%08x", read_val), UVM_LOW)

    // 3. Escreve no registrador intr_enable via barramento TL-UL
    // (habilita as interrupcoes de pkt_received e pkt_sent: bits 0 e 1 = 0x3)
    csr_wr(.ptr(ral.intr_enable), .value(32'h0000_0003));
    `uvm_info(`gfn, ">> Escrito 0x00000003 no registrador intr_enable via TL-UL", UVM_LOW)

    // 4. Le de volta do hardware para confirmar se o RTL gravou corretamente
    csr_rd(.ptr(ral.intr_enable), .value(read_val));
    `uvm_info(`gfn, $sformatf(">> Valor lido de intr_enable apos escrita: 0x%08x", read_val), UVM_LOW)

    // 5. Verificacao de integridade
    if(read_val == 32'h0000_0003) begin
      `uvm_info(`gfn, "=============================================================", UVM_LOW)
      `uvm_info(`gfn, ">>> SUCESSO: COMUNICACAO TL-UL COM O HARDWARE FUNCIONANDO! <<<", UVM_LOW)
      `uvm_info(`gfn, "=============================================================", UVM_LOW)
    end else begin
      `uvm_error(`gfn, $sformatf("FALHA: Esperava 0x3 mas o DUT retornou 0x%08x", read_val))
    end
  endtask

   virtual task post_start();
    `uvm_info(`gfn, "=== [FASE 1] SEQUENCIA CONCLUIDA COM SUCESSO ===", UVM_LOW)
   endtask

endclass