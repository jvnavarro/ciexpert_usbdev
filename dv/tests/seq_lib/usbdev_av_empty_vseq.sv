class usbdev_av_empty_vseq extends usbdev_smoke_vseq;

  `uvm_object_utils(usbdev_av_empty_vseq)

  function new(string name = "usbdev_av_empty_vseq");
    super.new(name);
  endfunction

  virtual task body();
    // 1. Choose at random whether to test the AV SETUP or the AV OUT Buffer FIFO
    bit        is_setup = $urandom_range(0, 1);
    uvm_reg    av_buf   = is_setup ? ral.avsetupbuffer : ral.avoutbuffer;
    bit [31:0] mask     = 32'b1 << (is_setup ? 17 : 7);  // av_setup_empty / av_out_empty bit
    bit [31:0] intr_state_val;

    configure_and_connect();  // already provides 1 buffer to each FIFO

    // 2. Add 3 more buffers (4 in total), enable the interrupt, send 4 back-to-back packets
    for (int i = 0; i < 3; i++) csr_wr(.ptr(av_buf), .value(i));
    csr_wr(.ptr(ral.intr_enable), .value(mask));
    for (int i = 0; i < 4; i++) send_and_check(is_setup, i);

    // 4. The FIFO is now empty: intr_state and the interrupt pin must be high
    csr_rd(.ptr(ral.intr_state), .value(intr_state_val));
    `DV_CHECK_EQ(intr_state_val & mask, mask, "intr_state av_empty is low")
    `DV_CHECK_EQ(cfg.intr_vif.sample() & mask, mask, "av_empty interrupt pin is low")
  endtask

  virtual task send_and_check(bit is_setup, int pkt_idx);
    usb_transaction            usb_rsp;     // DUT response, after the cast
    uvm_sequence_item          rsp_base;    // response as returned by get_response
    usb_transaction::usb_pid_e token_pid;   // SETUP or OUT
    usb_transaction::usb_pid_e data_pid;    // DATA0 or DATA1
    uvm_reg_data_t             rxfifo_val;  // full rxfifo read value

    token_pid = is_setup ? usb_transaction::PID_SETUP : usb_transaction::PID_OUT;
    data_pid  = (is_setup || (pkt_idx % 2 == 0)) ? usb_transaction::PID_DATA0 : usb_transaction::PID_DATA1;

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

    // 3. Wait for the packet, clear pkt_received (W1C), and discard the RX FIFO entry
    csr_spinwait(.ptr(ral.intr_state.pkt_received), .exp_data(1'b1));
    csr_wr(.ptr(ral.intr_state), .value(ral.intr_state.pkt_received.get_field_mask()));
    csr_rd(.ptr(ral.rxfifo), .value(rxfifo_val));
  endtask

endclass