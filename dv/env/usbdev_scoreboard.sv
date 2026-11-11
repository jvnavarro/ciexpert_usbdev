// 1. Declaração da macro fora da classe (para evitar conflitos de nomes no UVM)
`uvm_analysis_imp_decl(_usb20)
typedef byte unsigned usb_bytes_t[];

class usbdev_scoreboard extends cip_base_scoreboard #(
  .CFG_T          (usbdev_env_cfg),
  .RAL_T          (usbdev_reg_block),
  .COV_T          (usbdev_env_cov)
);
  `uvm_component_utils(usbdev_scoreboard)
// Indica se a Etapa 10 foi validada com sucesso
bit etapa10_validada = 0;
// Habilita a verificacao especifica da etapa 10
bit verificar_etapa10 = 0;
// Dados recebidos no OUT que devem retornar na transmissao IN
byte unsigned dados_in_esperados[];
  // 2. Declaração da porta de análise para receber dados do usb20_monitor
  uvm_analysis_imp_usb20 #(usb_transaction, usbdev_scoreboard) usb20_fifo;
  bit [17:0] intr_en_shadow = '0;

  function new(string name = "usbdev_scoreboard", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // Instancia a porta de análise no build_phase
    usb20_fifo = new("usb20_fifo", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
  endfunction

  // 3. Função obrigatória chamada automaticamente quando o monitor faz analysis_port.write()
  virtual function void write_usb20(usb_transaction trans);
// Consultar se a verificacao da Etapa 10 foi habilitada
void'(uvm_config_db#(bit)::get(
    this,
    "",
    "verificar_etapa10",
    verificar_etapa10
));
// Recuperar os bytes enviados pelo host no pacote OUT
void'(uvm_config_db#(usb_bytes_t)::get(
    this,
    "",
    "dados_in_esperados",
    dados_in_esperados
));
    `uvm_info(`gfn, $sformatf("SCOREBOARD: Item USB recebido | %s | %s | PID=0x%0h ADDR=0x%0h ENDP=0x%0h DATA=%0d bytes",
                              trans.kind.name(), trans.from_device ? "DUT->host" : "host->DUT",
                              trans.pid, trans.addr, trans.endp, trans.data.size()), UVM_LOW)

    // Aqui os membros da equipe poderão implementar a validação dos pacotes USB
    // Etapa 10: verificar os 8 bytes transmitidos pelo DUT
if (
verificar_etapa10 &&
trans.from_device &&
 trans.kind == usb_transaction::USB_ITEM_NORMAL &&
 trans.pid == usb_transaction::PID_DATA0) begin

  if (trans.data.size() != dados_in_esperados.size()) begin
    `uvm_error(get_type_name(),
      $sformatf("ETAPA 10: esperado %0d bytes, recebido %0d",
                dados_in_esperados.size(),
                trans.data.size()))
end
  else begin
  bit dados_corretos = 1;
    foreach (trans.data[i]) begin
      if (trans.data[i] !== dados_in_esperados[i]) begin
      dados_corretos = 0;
        `uvm_error(get_type_name(),
          $sformatf("ETAPA 10: byte %0d incorreto. Esperado=0x%02h Recebido=0x%02h",
                    i, dados_in_esperados[i], trans.data[i]))
      end
    end
      if (dados_corretos) begin
	etapa10_validada = 1;
    `uvm_info(get_type_name(),
      $sformatf("ETAPA 10: pacote DATA0 de %0d bytes verificado corretamente",
          dados_in_esperados.size()),
      UVM_LOW)
	end
  end
end

      // Aqui os membros da equipe poderão implementar a validação dos pacotes USB

      // Dispara a amostragem da cobertura funcional se 'cov' estiver instanciado
      if (cov != null) begin
        // 1. Amostra PID recebido (Host -> DUT)
        if (!trans.from_device) begin
          cov.pids_to_dut_cg.sample(trans.pid);
        end

        // 2. Se for resposta do DUT (DUT -> Host), pontua em pids_from_dut_cg
        if (trans.from_device &&
            trans.pid inside {usb_transaction::PID_DATA0, usb_transaction::PID_DATA1,
                              usb_transaction::PID_ACK,   usb_transaction::PID_NAK,
                              usb_transaction::PID_STALL}) begin
          cov.pids_from_dut_cg.sample(trans.pid);
        end

        // 3. SOF: amostra número do frame
        if (trans.pid == usb_transaction::PID_SOF) begin
          cov.framenum_rx_cg.sample(trans.frame_num);
        end

        // 4. Tokens (SETUP, OUT, IN): endereço, endpoint, CRC5, config de EP e nível de FIFOs
        if (trans.is_token()) begin
          bit dir_in = (trans.pid == usb_transaction::PID_IN);
          bit [3:0] ep = trans.endp;
          cov.address_cg.sample(trans.addr, ep);
          cov.crc5_cg.sample(dir_in, trans.crc5);
          cov.pid_type_endp_cg.sample(trans.pid, ep);

          if (ep < 12) begin
            uvm_hdl_data_t ep_in_en, ep_out_en, rxen_setup, rxen_out;
            uvm_hdl_data_t nak_out, in_st, out_st, in_is, out_is;
            if (dir_in) begin
              void'(uvm_hdl_read("tb.dut.ep_in_enable", ep_in_en));
              void'(uvm_hdl_read("tb.dut.in_ep_stall",  in_st));
              void'(uvm_hdl_read("tb.dut.ep_in_iso",    in_is));
              cov.ep_in_cfg_cg.sample(trans.pid, ep_in_en[ep], in_st[ep], in_is[ep]);
            end else begin
              void'(uvm_hdl_read("tb.dut.ep_out_enable",     ep_out_en));
              void'(uvm_hdl_read("tb.dut.enable_setup",      rxen_setup));
              void'(uvm_hdl_read("tb.dut.enable_out",        rxen_out));
              void'(uvm_hdl_read("tb.dut.ep_set_nak_on_out", nak_out));
              void'(uvm_hdl_read("tb.dut.out_ep_stall",      out_st));
              void'(uvm_hdl_read("tb.dut.ep_out_iso",        out_is));
              cov.ep_out_cfg_cg.sample(trans.pid, ep_out_en[ep], rxen_setup[ep],
                                       rxen_out[ep], nak_out[ep], out_st[ep], out_is[ep]);
            end
          end

          if (trans.pid inside {usb_transaction::PID_SETUP, usb_transaction::PID_OUT}) begin
            uvm_hdl_data_t avsetup_d, avout_d, rx_d;
            void'(uvm_hdl_read("tb.dut.usbdev_avsetupfifo.depth_o", avsetup_d));
            void'(uvm_hdl_read("tb.dut.usbdev_avoutfifo.depth_o",   avout_d));
            void'(uvm_hdl_read("tb.dut.rx_depth",                   rx_d));
            cov.fifo_lvl_cg.sample(trans.pid, avsetup_d[2:0], avout_d[3:0], rx_d[3:0]);
          end
        end

        // 5. Data Toggle (DATA0, DATA1, ACK, NAK)
        if (trans.pid inside {usb_transaction::PID_DATA0, usb_transaction::PID_DATA1,
                              usb_transaction::PID_ACK,   usb_transaction::PID_NAK}) begin
          cov.data_tog_endp_cg.sample(trans.pid, trans.is_in(), trans.endp);
        end

        // 6. Pacotes DATA: tamanho do payload e CRC16
        if (trans.is_data()) begin
          cov.data_pkt_cg.sample(trans.is_in(), trans.data.size());
          cov.crc16_cg.sample(trans.is_in(), trans.crc16);
        end
      end

  endfunction
// Verificar se a Etapa 10 foi concluída
virtual function void check_phase(uvm_phase phase);
  super.check_phase(phase);

  if (verificar_etapa10 && !etapa10_validada) begin
    `uvm_error(get_type_name(),
      "ETAPA 10: nenhum pacote DATA0 valido com os dados esperados foi recebido")
  end
endfunction

  // Acessos TL-UL: obrigatório sobrescrever na cip_base_scoreboard
  virtual task process_tl_access(tl_seq_item item, tl_channels_e channel, string ral_name);
    if (cov != null && cfg.en_cov) begin
      uvm_reg_addr_t csr_addr = cfg.ral_models[ral_name].get_word_aligned_addr(item.a_addr);
      uvm_reg csr = cfg.ral_models[ral_name].get_default_map().get_reg_by_offset(csr_addr);
      if (csr != null) begin
        string csr_name = csr.get_name();
        if (channel == AddrChannel && item.is_write() && csr_name == "intr_enable") begin
          intr_en_shadow = item.a_data[17:0];
        end
        // Leitura de intr_state no canal D -> amostra intr_cg e intr_pins_cg
        if (channel == DataChannel && !item.is_write() && csr_name == "intr_state") begin
          for (int unsigned i = 0; i < 18; i++) begin
            cov.intr_cg.sample(i, intr_en_shadow[i], item.d_data[i]);
            cov.intr_pins_cg.sample(i, cfg.intr_vif.pins[i]);
          end
        end
        // Escrita em intr_test no canal A -> amostra intr_test_cg
        if (channel == AddrChannel && item.is_write() && csr_name == "intr_test") begin
          for (int unsigned i = 0; i < 18; i++) begin
            cov.intr_test_cg.sample(i, item.a_data[i], intr_en_shadow[i], item.a_data[i]);
          end
        end
      end
    end
  endtask

endclass
