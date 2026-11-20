class usbdev_av_empty_vseq extends usbdev_smoke_vseq;

  `uvm_object_utils(usbdev_av_empty_vseq)

  function new(string name = "usbdev_av_empty_vseq");
    super.new(name);
  endfunction

  virtual task body();
    // Choose at random whether to test the AV OUT Buffer FIFO or the AV SETUP Buffer FIFO.
    bit            is_setup = $urandom_range(0, 1);
    uvm_reg_data_t intr_en_val, intr_state_val;

    // Connect device and configure endpoint before enabling interrupts
    configure_and_connect();

    // Push buffers, enable the corresponding interrupt, and send back-to-back packets
    if (is_setup == 1) begin
      for (int i = 0; i < 3; i++) csr_wr(.ptr(ral.avsetupbuffer), .value((setup_buf + 1 + i) % 32));
      intr_en_val = ral.intr_enable.av_setup_empty.get_field_mask();
      csr_wr(.ptr(ral.intr_enable), .value(intr_en_val));
      for (int i = 0; i < 4; i++) send_and_check(is_setup, i);
      // 4
      csr_rd(.ptr(ral.intr_state), .value(intr_state_val));
      `DV_CHECK_EQ(get_field_val(ral.intr_state.av_setup_empty, intr_state_val),1'b1, "intr_state.av_setup_empty")
      `DV_CHECK_EQ(cfg.intr_vif.pins[17], 1'b1, "av_setup_empty interrupt pin")

    end else begin
      for (int i = 0; i < 3; i++) csr_wr(.ptr(ral.avoutbuffer), .value((out_buf + 1 + i) % 32));
      intr_en_val = ral.intr_enable.av_out_empty.get_field_mask();
      csr_wr(.ptr(ral.intr_enable), .value(intr_en_val));
      for (int i = 0; i < 4; i++) send_and_check(is_setup, i);
      // 4.
      csr_rd(.ptr(ral.intr_state), .value(intr_state_val));
      `DV_CHECK_EQ(get_field_val(ral.intr_state.av_out_empty, intr_state_val),1'b1, "intr_state.av_out_empty")
      `DV_CHECK_EQ(cfg.intr_vif.pins[7], 1'b1, "av_out_empty interrupt pin")
      
    end

   // 4. Verify that this interrupt pin goes high once the Av OUT/SETUP Buffer FIFO is empty.
   // DV_CHECK... pino de interrupçao e intr_state - setup ou out
   

  endtask

  virtual task send_and_check(bit is_setup, int pkt_idx);
    usb_transaction            usb_rsp;     // DUT response, after the cast
    uvm_sequence_item          rsp_base;    // response as returned by get_response
    usb_transaction::usb_pid_e token_pid;   // SETUP or OUT
    usb_transaction::usb_pid_e data_pid;    // DATA0 or DATA1
    uvm_reg_data_t             rxfifo_val;  // full rxfifo read value

    token_pid = is_setup ? usb_transaction::PID_SETUP : usb_transaction::PID_OUT;
    data_pid  = (is_setup || (pkt_idx % 2 == 0)) ? usb_transaction::PID_DATA0
                                                 : usb_transaction::PID_DATA1;

    // Token (SETUP or OUT), no response expected
    `uvm_do_on_with(req, p_sequencer.usb20_sequencer_h, {
      kind == usb_transaction::USB_ITEM_NORMAL;
      pid  == token_pid;
      addr == 7'h00;
      endp == ep;
    })

    // DATA, waits for the handshake
    req = usb_transaction::type_id::create("req");
    start_item(req, -1, p_sequencer.usb20_sequencer_h);
    if (!req.randomize() with {
          kind == usb_transaction::USB_ITEM_NORMAL;
          pid  == data_pid;
          is_setup -> data.size() == 8;   // SETUP data is always 8 bytes
        })
      `uvm_fatal(get_type_name(), $sformatf(
                 "Packet %0d: %s randomization failed: conflicting constraints",
                 pkt_idx, data_pid.name()))
    req.want_rsp = 1'b1;
    finish_item(req);

    get_response(rsp_base);
    if (!$cast(usb_rsp, rsp_base))
      `uvm_fatal(get_type_name(), $sformatf(
                 "Packet %0d: %s response has type %s, expected usb_transaction",
                 pkt_idx, data_pid.name(), rsp_base.get_type_name()))

    // Check the handshake sent by the DUT
    if (usb_rsp.no_response)
      `uvm_error(get_type_name(), "DUT did not respond to DATA")
    else if (usb_rsp.pid != usb_transaction::PID_ACK)
      `uvm_error(get_type_name(), $sformatf("Expected ACK, got %s", usb_rsp.pid.name()))

    // Check the CSRs, clear pkt_received (W1C), and discard the RX FIFO entry
    csr_spinwait(.ptr(ral.intr_state.pkt_received), .exp_data(1'b1));
    csr_wr(.ptr(ral.intr_state), .value(ral.intr_state.pkt_received.get_field_mask()));
    csr_rd(.ptr(ral.rxfifo), .value(rxfifo_val));
  endtask

endclass