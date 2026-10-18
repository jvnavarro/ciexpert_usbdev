class usbdev_smoke_vseq extends usbdev_base_vseq;
  `uvm_object_utils(usbdev_smoke_vseq)
  rand bit [3:0] ep; // endpoint ( deve estar entre 0 a 11)
  constraint ep_c {ep inside {[0:11]};} // endpoint deve estar entre 0 a 11
  
  usb_transaction req; // objeto de transação usb
  usb20_basic_seq m_usb20_seq; 
  uvm_hdl_data_t pullup_val; // 'pullup' sozinho e palavra reservada do Verilog
  rand bit [4:0] setup_buf, out_buf, in_buf;
  constraint buf_c { unique {setup_buf, out_buf, in_buf}; }

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

  // 5. Nenhum erro de linha (CRC, PID, bit stuffing) durante o teste
  check_no_errors();
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
  csr_wr(.ptr(ral.avoutbuffer), .value(out_buf));

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
  // ── A. Declarações (sempre no topo da task) ──────────────
  usb_transaction            usb_rsp;     // resposta do DUT, já convertida
  uvm_sequence_item          rsp_base;    // resposta como o get_response entrega
  usb_transaction::usb_pid_e token_pid;   // SETUP ou OUT
  usb_transaction::usb_pid_e data_pid;    // DATA0 ou DATA1
  bit [4:0]                  exp_buf;     // armário esperado no rxfifo
  bit                        exp_setup;   // 1 se o pacote e SETUP
  bit [6:0]                  exp_size;    // size tem 7 bits (0..64)
  bit [3:0]                  exp_ep;      // endpoint esperado no rxfifo
  byte                       sent_data[]; // cópia dos bytes enviados
  uvm_reg_data_t             rxfifo_val;  // leitura inteira do rxfifo
  bit [31:0]                 word;        // uma palavra da SRAM
  // ── B. Escolher os valores conforme is_setup ─────────────
  token_pid = is_setup ? usb_transaction::PID_SETUP : usb_transaction::PID_OUT;
  data_pid  = is_setup ? usb_transaction::PID_DATA0 : usb_transaction::PID_DATA1;
  exp_buf   = is_setup ? setup_buf : out_buf;
  exp_setup = is_setup;
  exp_ep    = ep;

  // ── C. Pacote 1: token (SETUP ou OUT), SEM resposta ──────
 `uvm_do_on_with(req, p_sequencer.usb20_sequencer_h, {
    kind == usb_transaction::USB_ITEM_NORMAL;
    pid  == token_pid;
    addr == 7'h00;
    endp == ep;
  })
  // ── D. Pacote 2: DATA, COM resposta (o padrão da seção 2) ─
  req = usb_transaction::type_id::create("req");
  start_item(req, -1, p_sequencer.usb20_sequencer_h);
  if (!req.randomize() with {
        kind == usb_transaction::USB_ITEM_NORMAL;
        pid  == data_pid;
        is_setup -> data.size() == 8;   // "se is_setup, então 8 bytes"
      })
    `uvm_fatal(get_type_name(), $sformatf(
               "Fase %0d: randomize do %s falhou: constraints em conflito",
               is_setup ? 1 : 2, data_pid.name()))
  req.want_rsp = 1'b1;
  finish_item(req);

  sent_data = req.data;
  exp_size  = sent_data.size(); // so aqui o sent_data ja tem os bytes

  get_response(rsp_base);
  if (!$cast(usb_rsp, rsp_base))
    `uvm_fatal(get_type_name(), $sformatf(
               "Fase %0d: resposta do %s tem tipo %s, esperado usb_transaction",
               is_setup ? 1 : 2, data_pid.name(), rsp_base.get_type_name()))
  
  // ── E. Pacote 3: conferir o handshake que o DUT mandou ───
 if (usb_rsp.no_response)
    `uvm_error(get_type_name(), "DUT nao respondeu ao DATA")
  else if (usb_rsp.pid != usb_transaction::PID_ACK)
    `uvm_error(get_type_name(), $sformatf("Esperava ACK, veio %s", usb_rsp.pid.name()))
  // ── F. Conferir os CSRs ─────────────
  csr_spinwait(.ptr(ral.intr_state.pkt_received), .exp_data(1'b1));
  csr_rd_check(.ptr(ral.usbstat.rx_empty), .compare_value(1'b0),
               .err_msg("rxfifo vazio apos receber o pacote"));

  // Ler o rxfifo tira a entrada da fila (a proxima fase comeca com ele vazio)
  csr_rd(.ptr(ral.rxfifo), .value(rxfifo_val));

  if (get_field_val(ral.rxfifo.buffer, rxfifo_val) != exp_buf)
    `uvm_error(get_type_name(), $sformatf("rxfifo.buffer: esperado %0d, lido %0d",
               exp_buf, get_field_val(ral.rxfifo.buffer, rxfifo_val)))

  if (get_field_val(ral.rxfifo.setup, rxfifo_val) != exp_setup)
    `uvm_error(get_type_name(), $sformatf("rxfifo.setup: esperado %0d, lido %0d",
               exp_setup, get_field_val(ral.rxfifo.setup, rxfifo_val)))

  if (get_field_val(ral.rxfifo.size, rxfifo_val) != exp_size)
    `uvm_error(get_type_name(), $sformatf("rxfifo.size: esperado %0d, lido %0d",
               exp_size, get_field_val(ral.rxfifo.size, rxfifo_val)))

  if (get_field_val(ral.rxfifo.ep, rxfifo_val) != exp_ep)
    `uvm_error(get_type_name(), $sformatf("rxfifo.ep: esperado %0d, lido %0d",
               exp_ep, get_field_val(ral.rxfifo.ep, rxfifo_val)))

  csr_rd_check(.ptr(ral.usbstat.rx_empty), .compare_value(1'b1),
               .err_msg("rxfifo deveria estar vazio apos o pop"));

  // ── G. Conferir a SRAM ───────────────────────────────────
    for (int i = 0; i < (sent_data.size() + 3) / 4; i++) begin
    mem_rd(.ptr(ral.buffer), .offset(exp_buf*16 + i), .data(word));
    for (int j = 0; j < 4; j++) begin
      if (4*i + j < sent_data.size()) begin       // a última palavra pode estar incompleta
        if (word[8*j +: 8] != sent_data[4*i + j])
          `uvm_error(get_type_name(), $sformatf("SRAM byte %0d: esperado 0x%02h, lido 0x%02h",
                     4*i + j, sent_data[4*i + j], word[8*j +: 8]))
      end
    end
  end
endtask

virtual task send_and_check_in();
  // ── A. Declarações ───────────────────────────────────────
  byte         data_in[];  // bytes que o DUT deve enviar ao host
  int unsigned num_byte;   // quantidade de bytes (1..32)
  bit [31:0]   word;       // uma palavra da SRAM
  usb_transaction            usb_rsp;
  uvm_sequence_item          rsp_base;

  // ── B. [CPU] Criar os bytes e gravar no armário in_buf ───
  num_byte = $urandom_range(1, 32);      // IN aceita no maximo 32 bytes
  data_in  = new[num_byte];              // aloca o array com num_byte posicoes
  foreach (data_in[i]) data_in[i] = $urandom();

  for (int i = 0; i < (num_byte + 3) / 4; i++) begin
    word = '0;                           // nao herdar bytes da palavra anterior
    for (int j = 0; j < 4; j++) begin
      if (4*i + j < num_byte)            // a ultima palavra pode estar incompleta
        word[8*j +: 8] = data_in[4*i + j];
    end
    mem_wr(.ptr(ral.buffer), .offset(in_buf*16 + i), .data(word));
  end
  // ── C. [CPU] Armar o endpoint (configin) ─────────────────
  ral.configin[ep].buffer.set(in_buf);
  ral.configin[ep].size.set(num_byte);
  ral.configin[ep].rdy.set(1'b1);
  csr_update(ral.configin[ep]);     // uma escrita so: buffer, size e rdy juntos

  // ── D. [HOST] Token IN, COM resposta ─────────────────────
  req = usb_transaction::type_id::create("req");
  start_item(req, -1, p_sequencer.usb20_sequencer_h);
  if (!req.randomize() with {
        kind == usb_transaction::USB_ITEM_NORMAL;
        pid  == usb_transaction::PID_IN;
        addr == 7'h00;
        endp == ep;
      })
    `uvm_fatal(get_type_name(), $sformatf(
               "Fase 3: randomize do token IN falhou (ep=%0d): constraints em conflito",
               ep))
  req.want_rsp = 1'b1;
  finish_item(req);

  get_response(rsp_base);           // nao gasta tempo: a resposta ja esta na fila
  if (!$cast(usb_rsp, rsp_base))
    `uvm_fatal(get_type_name(), $sformatf(
               "Fase 3: resposta do IN tem tipo %s, esperado usb_transaction",
               rsp_base.get_type_name()))

  // ── E. [HOST] ACK imediato (DUT so espera ~17 bit times) ─
  `uvm_do_on_with(req, p_sequencer.usb20_sequencer_h, {
    kind == usb_transaction::USB_ITEM_NORMAL;
    pid  == usb_transaction::PID_ACK;
  })

  // ── F. [HOST] Conferir o DATA1 recebido ──────────────────
  // So depois do ACK: aqui ja pode gastar tempo conferindo
  if (usb_rsp.no_response)
    `uvm_error(get_type_name(), $sformatf(
               "Fase 3: DUT nao respondeu ao IN no ep=%0d (configin nao armado?)", ep))
  else begin
    if (usb_rsp.pid != usb_transaction::PID_DATA1)
      `uvm_error(get_type_name(), $sformatf(
                 "Fase 3: IN esperava PID_DATA1, veio %s", usb_rsp.pid.name()))
    if (usb_rsp.data != data_in)    // != em arrays compara tamanho e todos os bytes
      `uvm_error(get_type_name(), $sformatf(
                 "Fase 3: payload do IN diferente do gravado em in_buf=%0d (esperado %0d bytes, veio %0d)",
                 in_buf, data_in.size(), usb_rsp.data.size()))
  end

  // ── G. [CPU] Conferir os CSRs depois do envio ────────────
  // in_sent: o DUT liga o bit 'ep' quando recebe o ACK do host.
  // spinwait porque o DUT leva alguns ciclos para atualizar o CSR.
  csr_spinwait(.ptr(ral.in_sent[0]), .exp_data(1 << ep));
  // pkt_sent e interrupcao Status: fica em 1 enquanto algum bit de in_sent estiver em 1
  csr_rd_check(.ptr(ral.intr_state.pkt_sent), .compare_value(1'b1),
               .err_msg("Fase 3: intr_state.pkt_sent nao subiu apos o IN"));
  // O DUT desarma o endpoint sozinho depois de enviar
  csr_rd_check(.ptr(ral.configin[ep].rdy), .compare_value(1'b0),
               .err_msg($sformatf("Fase 3: configin[%0d].rdy nao zerou apos o envio", ep)));
  // in_sent e W1C (write 1 to clear): escrever 1 no bit limpa o bit
  csr_wr(.ptr(ral.in_sent[0]), .value(1 << ep));
  csr_rd_check(.ptr(ral.in_sent[0]), .compare_value(0),
               .err_msg("Fase 3: in_sent nao limpou apos o W1C"));
endtask

// Confere que o DUT nao viu nenhum erro de linha durante o teste.
// Os erros sao interrupcoes Event: ficam em 1 ate alguem limpar.
virtual task check_no_errors();
  csr_rd_check(.ptr(ral.intr_state.rx_crc_err),      .compare_value(0),
               .err_msg("Fim do teste: DUT viu erro de CRC (rx_crc_err)"));
  csr_rd_check(.ptr(ral.intr_state.rx_pid_err),      .compare_value(0),
               .err_msg("Fim do teste: DUT viu PID invalido (rx_pid_err)"));
  csr_rd_check(.ptr(ral.intr_state.rx_bitstuff_err), .compare_value(0),
               .err_msg("Fim do teste: DUT viu erro de bit stuffing (rx_bitstuff_err)"));
  csr_rd_check(.ptr(ral.intr_state.link_in_err),     .compare_value(0),
               .err_msg("Fim do teste: erro numa transacao IN (link_in_err)"));
  csr_rd_check(.ptr(ral.intr_state.link_out_err),    .compare_value(0),
               .err_msg("Fim do teste: erro numa transacao OUT (link_out_err)"));
endtask

endclass