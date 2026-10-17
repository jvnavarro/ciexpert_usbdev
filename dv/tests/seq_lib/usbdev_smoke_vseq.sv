class usbdev_smoke_vseq extends usbdev_base_vseq;
  `uvm_object_utils(usbdev_smoke_vseq)
  rand bit [3:0] ep; // endpoint ( deve estar entre 0 a 11)
  constraint ep_c {ep inside {[0:11]};} // endpoint deve estar entre 0 a 11
  bit [4:0] setup_buf, out_buf, in_buf; // 32 buffers da sram
  usb_transaction req; // objeto de transação usb
  usb20_basic_seq m_usb20_seq; 
  uvm_hdl_data_t pullup_val; // 'pullup' sozinho e palavra reservada do Verilog

  function new(string name = "usbdev_smoke_vseq");
    super.new(name);
  endfunction

  virtual task body();
  // 1. Fase 0: Configura CSRs do DUT e conecta
  configure_and_connect();

  // 2. Fase 1: Envia e checa pacote SETUP
  send_and_check_out(1'b1); 

  // 3. Fase 2: Envia e checa pacote OUT comum
  send_and_check_out(1'b0); 

  // 4. Fase 3: Transmissão IN (DUT -> Host)
  send_and_check_in();
endtask

virtual task configure_and_connect();
  // 1. Desconecta o controlador para simular a conexão física
  csr_wr(.ptr(ral.usbctrl.enable), .value(1'b0));

  // 2. Configura a PHY para Single-Ended
  csr_wr(.ptr(ral.phy_config.use_diff_rcvr), .value(1'b0));

  // 3. Habilita endpoints (o bit 'ep' no registrador correspondente)
  csr_wr(.ptr(ral.ep_out_enable[0]),  .value(1'b1 << ep));
  csr_wr(.ptr(ral.ep_in_enable[0]),   .value(1'b1 << ep));
  csr_wr(.ptr(ral.rxenable_setup[0]), .value(1'b1 << ep));
  csr_wr(.ptr(ral.rxenable_out),   .value(1'b1 << ep));

  // 4. Disponibiliza o buffer de SETUP
  csr_wr(.ptr(ral.avsetupbuffer), .value(setup_buf));

  // 5. Habilita o controlador (conecta o dispositivo)
  csr_wr(.ptr(ral.usbctrl.enable), .value(1'b1));

  // 6. Aguarda o pull-up ser ativado no hardware
  do begin
    cfg.clk_rst_vif.wait_clks(1);
    void'(uvm_hdl_read("tb.dut.usb_dp_pullup_o", pullup_val));
  end while (pullup_val != 1);

  `uvm_info(get_type_name(), "Dispositivo detectado! Enviando Bus Reset...", UVM_LOW)

  // 7. Envia o Bus Reset do Host
  `uvm_do_on_with(req, p_sequencer.usb20_sequencer_h, {
    kind == usb_transaction::USB_ITEM_BUS_RESET;
  })

  // 8. Checagens de Sanidade
  // Powered + bus reset -> LinkActiveNoSOF
  // O DUT leva alguns ciclos (sync + filtro) para ver o fim do SE0
  csr_spinwait(.ptr(ral.usbstat.link_state), .exp_data(LinkActiveNoSOF));

  csr_rd_check(.ptr(ral.usbctrl.device_address), .compare_value(7'h00),
               .err_msg("Erro: device_address nao zerou apos o reset!"));

  csr_rd_check(.ptr(ral.intr_state.link_reset), .compare_value(1'b1),
               .err_msg("Erro: Interrupcao link_reset nao disparou!"));
endtask

virtual task send_and_check_out(bit is_setup);
endtask;

virtual task send_and_check_in();
endtask;

endclass