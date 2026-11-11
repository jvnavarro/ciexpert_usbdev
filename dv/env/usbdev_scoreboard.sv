// Declared outside the class to create the write_usb20() imp type
`uvm_analysis_imp_decl(_usb20)
typedef byte unsigned usb_bytes_t[];

class usbdev_scoreboard extends cip_base_scoreboard #(
  .CFG_T          (usbdev_env_cfg),
  .RAL_T          (usbdev_reg_block),
  .COV_T          (usbdev_env_cov)
);
  `uvm_component_utils(usbdev_scoreboard)
// Set when step 10 (in_trans test) was checked successfully
bit etapa10_validada = 0;
// Enables the step 10 check (set by the in_trans test through config_db)
bit verificar_etapa10 = 0;
// Data sent in the OUT that must come back in the IN transfer
byte unsigned dados_in_esperados[];
  // Analysis imp that receives items from usb20_monitor
  uvm_analysis_imp_usb20 #(usb_transaction, usbdev_scoreboard) usb20_fifo;
  bit [17:0] intr_en_shadow = '0;

  function new(string name = "usbdev_scoreboard", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    usb20_fifo = new("usb20_fifo", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
  endfunction

  // Called for every item the monitor writes to its analysis port
  virtual function void write_usb20(usb_transaction trans);
// Check whether the step 10 check is enabled
void'(uvm_config_db#(bit)::get(
    this,
    "",
    "verificar_etapa10",
    verificar_etapa10
));
// Get the bytes the host sent in the OUT packet
void'(uvm_config_db#(usb_bytes_t)::get(
    this,
    "",
    "dados_in_esperados",
    dados_in_esperados
));
    `uvm_info(`gfn, $sformatf("SCOREBOARD: USB item received | %s | %s | PID=0x%0h ADDR=0x%0h ENDP=0x%0h DATA=%0d bytes",
                              trans.kind.name(), trans.from_device ? "DUT->host" : "host->DUT",
                              trans.pid, trans.addr, trans.endp, trans.data.size()), UVM_LOW)

    // Step 10: the DATA0 sent by the DUT must match the data sent in the OUT
if (
verificar_etapa10 &&
trans.from_device &&
 trans.kind == usb_transaction::USB_ITEM_NORMAL &&
 trans.pid == usb_transaction::PID_DATA0) begin

  if (trans.data.size() != dados_in_esperados.size()) begin
    `uvm_error(get_type_name(),
      $sformatf("STEP 10: expected %0d bytes, got %0d",
                dados_in_esperados.size(),
                trans.data.size()))
end
  else begin
  bit dados_corretos = 1;
    foreach (trans.data[i]) begin
      if (trans.data[i] !== dados_in_esperados[i]) begin
      dados_corretos = 0;
        `uvm_error(get_type_name(),
          $sformatf("STEP 10: wrong byte %0d. Expected=0x%02h Got=0x%02h",
                    i, dados_in_esperados[i], trans.data[i]))
      end
    end
      if (dados_corretos) begin
	etapa10_validada = 1;
    `uvm_info(get_type_name(),
      $sformatf("STEP 10: DATA0 packet with %0d bytes checked OK",
          dados_in_esperados.size()),
      UVM_LOW)
	end
  end
end

      // Sample functional coverage when 'cov' exists
      if (cov != null) begin
        // 1. PID sent to the DUT (host -> DUT)
        if (!trans.from_device) begin
          cov.pids_to_dut_cg.sample(trans.pid);
        end

        // 2. DUT response (DUT -> host): pids_from_dut_cg
        if (trans.from_device &&
            trans.pid inside {usb_transaction::PID_DATA0, usb_transaction::PID_DATA1,
                              usb_transaction::PID_ACK,   usb_transaction::PID_NAK,
                              usb_transaction::PID_STALL}) begin
          cov.pids_from_dut_cg.sample(trans.pid);
        end

        // 3. SOF: frame number
        if (trans.pid == usb_transaction::PID_SOF) begin
          cov.framenum_rx_cg.sample(trans.frame_num);
        end

        // 4. Tokens (SETUP, OUT, IN): address, endpoint, CRC5, EP config and FIFO levels
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

        // 6. DATA packets: payload size and CRC16
        if (trans.is_data()) begin
          cov.data_pkt_cg.sample(trans.is_in(), trans.data.size());
          cov.crc16_cg.sample(trans.is_in(), trans.crc16);
        end
      end

  endfunction
// Fail if step 10 was enabled but never checked
virtual function void check_phase(uvm_phase phase);
  super.check_phase(phase);

  if (verificar_etapa10 && !etapa10_validada) begin
    `uvm_error(get_type_name(),
      "STEP 10: no valid DATA0 packet with the expected data was received")
  end
endfunction

  // TL-UL accesses: must be overridden from cip_base_scoreboard
  virtual task process_tl_access(tl_seq_item item, tl_channels_e channel, string ral_name);
    if (cov != null && cfg.en_cov) begin
      uvm_reg_addr_t csr_addr = cfg.ral_models[ral_name].get_word_aligned_addr(item.a_addr);
      uvm_reg csr = cfg.ral_models[ral_name].get_default_map().get_reg_by_offset(csr_addr);
      if (csr != null) begin
        string csr_name = csr.get_name();
        if (channel == AddrChannel && item.is_write() && csr_name == "intr_enable") begin
          intr_en_shadow = item.a_data[17:0];
        end
        // intr_state read on channel D -> sample intr_cg and intr_pins_cg
        if (channel == DataChannel && !item.is_write() && csr_name == "intr_state") begin
          for (int unsigned i = 0; i < 18; i++) begin
            cov.intr_cg.sample(i, intr_en_shadow[i], item.d_data[i]);
            cov.intr_pins_cg.sample(i, cfg.intr_vif.pins[i]);
          end
        end
        // intr_test write on channel A -> sample intr_test_cg
        if (channel == AddrChannel && item.is_write() && csr_name == "intr_test") begin
          for (int unsigned i = 0; i < 18; i++) begin
            cov.intr_test_cg.sample(i, item.a_data[i], intr_en_shadow[i], item.a_data[i]);
          end
        end
      end
    end
  endtask

endclass
