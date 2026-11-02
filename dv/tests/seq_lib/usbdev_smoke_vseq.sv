class usbdev_smoke_vseq extends usbdev_base_vseq;
  `uvm_object_utils(usbdev_smoke_vseq)
  rand bit [3:0] ep; 
  constraint ep_c {ep inside {[0:11]};} // endpoint deve estar entre 0 a 11
  
  usb_transaction req; // objeto de transação usb
  uvm_hdl_data_t pullup_val; 
  rand bit [4:0] setup_buf, out_buf, in_buf;
  constraint buf_c { unique {setup_buf, out_buf, in_buf}; }

  function new(string name = "usbdev_smoke_vseq");
    super.new(name);
  endfunction

  virtual task body();
  // Configura CSRs do DUT e conecta
  configure_and_connect();

  // Envia e checa pacote SETUP
  send_and_check_out(1'b1); 

  // Envia e checa pacote OUT comum
  send_and_check_out(1'b0); 

  // Transmissão IN (DUT -> Host)
  send_and_check_in();

endtask

virtual task configure_and_connect();
  //  Desconecta o controlador para simular a conexão física
  csr_wr(.ptr(ral.usbctrl.enable), .value(1'b0));

  //  Configura a PHY para Single-Ended
  csr_wr(.ptr(ral.phy_config.use_diff_rcvr), .value(1'b0));

  // Habilita endpoints (o bit 'ep' no registrador correspondente)
  csr_wr(.ptr(ral.ep_out_enable[0]),  .value(1'b1 << ep));
  csr_wr(.ptr(ral.ep_in_enable[0]),   .value(1'b1 << ep));
  csr_wr(.ptr(ral.rxenable_setup[0]), .value(1'b1 << ep));
  csr_wr(.ptr(ral.rxenable_out),   .value(1'b1 << ep));

  //  Disponibiliza o buffer de SETUP
  csr_wr(.ptr(ral.avsetupbuffer), .value(setup_buf));
  csr_wr(.ptr(ral.avoutbuffer), .value(out_buf));

  //  Habilita o controlador (conecta o dispositivo)
  csr_wr(.ptr(ral.usbctrl.enable), .value(1'b1));

  // Aguarda o pull-up ser ativado no hardware
  do begin
    cfg.clk_rst_vif.wait_clks(1);
    void'(uvm_hdl_read("tb.dut.usb_dp_pullup_o", pullup_val));
  end while (pullup_val != 1);

  `uvm_info(get_type_name(), "Dispositivo detectado! Enviando Bus Reset...", UVM_LOW)

  // Envia o Bus Reset do Host
  `uvm_do_on_with(req, p_sequencer.usb20_sequencer_h, {
    kind == usb_transaction::USB_ITEM_BUS_RESET;
  })

  //  Checagens de Sanidade
  // Powered + bus reset -> LinkActiveNoSOF
  // O DUT leva alguns ciclos (sync + filtro) para ver o fim do SE0
  csr_spinwait(.ptr(ral.usbstat.link_state), .exp_data(LinkActiveNoSOF));

endtask

virtual task send_and_check_out(bit is_setup);
  usb_transaction            usb_rsp;     // resposta do DUT, já convertida
  uvm_sequence_item          rsp_base;    // resposta como o get_response entrega
  usb_transaction::usb_pid_e token_pid;   // SETUP ou OUT
  usb_transaction::usb_pid_e data_pid;    // DATA0 ou DATA1
  bit [4:0]                  exp_buf;     // armário esperado no rxfifo
  uvm_reg_data_t             rxfifo_val;  // leitura inteira do rxfifo
  bit [31:0]                 word;        // uma palavra da SRAM
  
  token_pid = is_setup ? usb_transaction::PID_SETUP : usb_transaction::PID_OUT;
  data_pid  = is_setup ? usb_transaction::PID_DATA0 : usb_transaction::PID_DATA1;
  exp_buf   = is_setup ? setup_buf : out_buf;

  //  token (SETUP ou OUT), SEM resposta
 `uvm_do_on_with(req, p_sequencer.usb20_sequencer_h, {
    kind == usb_transaction::USB_ITEM_NORMAL;
    pid  == token_pid;
    addr == 7'h00;
    endp == ep;
  })
  // DATA, COM resposta 
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

  get_response(rsp_base);
  if (!$cast(usb_rsp, rsp_base))
    `uvm_fatal(get_type_name(), $sformatf(
               "Fase %0d: resposta do %s tem tipo %s, esperado usb_transaction",
               is_setup ? 1 : 2, data_pid.name(), rsp_base.get_type_name()))
  
  // conferir o handshake que o DUT mandou
 if (usb_rsp.no_response)
    `uvm_error(get_type_name(), "DUT nao respondeu ao DATA")
  else if (usb_rsp.pid != usb_transaction::PID_ACK)
    `uvm_error(get_type_name(), $sformatf("Esperava ACK, veio %s", usb_rsp.pid.name()))
  // Conferir os CSRs
  csr_spinwait(.ptr(ral.intr_state.pkt_received), .exp_data(1'b1));
 
  // Ler o rxfifo tira a entrada da fila 
  csr_rd(.ptr(ral.rxfifo), .value(rxfifo_val));

`DV_CHECK_EQ(get_field_val(ral.rxfifo.buffer,rxfifo_val),exp_buf, "rxfifo.buffer")

`DV_CHECK_EQ(get_field_val(ral.rxfifo.setup,rxfifo_val), is_setup, "rxfifo.setup")

`DV_CHECK_EQ(get_field_val(ral.rxfifo.size, rxfifo_val),req.data.size(),"rxfifo.size")

`DV_CHECK_EQ(get_field_val(ral.rxfifo.ep, rxfifo_val),ep,"rxfifo.ep")

  // Conferir a SRAM 
    for (int i = 0; i < (req.data.size() + 3) / 4; i++) begin
    mem_rd(.ptr(ral.buffer), .offset(exp_buf*16 + i), .data(word));
    for (int j = 0; j < 4; j++) begin
      if (4*i + j < req.data.size()) begin       // a última palavra pode estar incompleta
        if (word[8*j +: 8] != req.data[4*i + j])
          `uvm_error(get_type_name(), $sformatf("SRAM byte %0d: esperado 0x%02h, lido 0x%02h", 4*i + j, req.data[4*i + j], word[8*j +: 8]))
      end
    end
  end
endtask

virtual task send_and_check_in();
 
  byte         data_in[];  // bytes que o DUT deve enviar ao host
  int unsigned num_byte;   // quantidade de bytes (1..32)
  bit [31:0]   word;       // uma palavra da SRAM
  usb_transaction            usb_rsp;
  uvm_sequence_item          rsp_base;

  // Criar os bytes e gravar no armário in_buf 
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
  // Armar o endpoint (configin)
  ral.configin[ep].buffer.set(in_buf);
  ral.configin[ep].size.set(num_byte);
  ral.configin[ep].rdy.set(1'b1);
  csr_update(ral.configin[ep]);     // uma escrita so: buffer, size e rdy juntos

  //  [HOST] Token IN, COM resposta
  req = usb_transaction::type_id::create("req");
  start_item(req, -1, p_sequencer.usb20_sequencer_h);
  if (!req.randomize() with {
        kind == usb_transaction::USB_ITEM_NORMAL;
        pid  == usb_transaction::PID_IN;
        addr == 7'h00;
        endp == ep;
      })
    `uvm_fatal(get_type_name(), $sformatf(
               "Fase 3: randomize do token IN falhou (ep=%0d): constraints em conflito",ep))
  req.want_rsp = 1'b1;
  finish_item(req);

  get_response(rsp_base);           // nao gasta tempo: a resposta ja esta na fila
  if (!$cast(usb_rsp, rsp_base))
    `uvm_fatal(get_type_name(), $sformatf(
               "Fase 3: resposta do IN tem tipo %s, esperado usb_transaction",rsp_base.get_type_name()))

  //  ACK imediato (DUT so espera ~17 bit times) ─
  `uvm_do_on_with(req, p_sequencer.usb20_sequencer_h, {
    kind == usb_transaction::USB_ITEM_NORMAL;
    pid  == usb_transaction::PID_ACK;
  })
  //  Conferir o DATA1 recebido
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
  // conferir os CSRs depois do envio
  // in_sent: o DUT liga o bit 'ep' quando recebe o ACK do host.
  // spinwait porque o DUT leva alguns ciclos para atualizar o CSR.
  csr_spinwait(.ptr(ral.in_sent[0]), .exp_data(1 << ep));     
endtask
endclass