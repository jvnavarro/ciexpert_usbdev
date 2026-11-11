class usbdev_smoke_vseq extends usbdev_base_vseq;
  `uvm_object_utils(usbdev_smoke_vseq)
  rand bit [3:0] ep; 
  constraint ep_c {ep inside {[0:11]};} // endpoint must be between 0 and 11
  
  usb_transaction req; // USB transaction item
  uvm_hdl_data_t pullup_val; 
  rand bit [4:0] setup_buf, out_buf, in_buf;
  constraint buf_c { unique {setup_buf, out_buf, in_buf}; } // SETUP, OUT and IN use different buffers

  function new(string name = "usbdev_smoke_vseq");
    super.new(name);
  endfunction

  virtual task body();
 
  configure_and_connect();

  //  SETUP
  send_and_check_out(1'b1); 

  // Regular OUT
  send_and_check_out(1'b0); 

  send_and_check_in();

endtask

virtual task configure_and_connect();
  // Disconnect the controller to emulate a physical plug-in
  csr_wr(.ptr(ral.usbctrl.enable), .value(1'b0));

  // Configure the PHY for single-ended reception
  csr_wr(.ptr(ral.phy_config.use_diff_rcvr), .value(1'b0));

  // Enable the endpoint (bit 'ep' of each register)
  csr_wr(.ptr(ral.ep_out_enable[0]),  .value(1'b1 << ep));
  csr_wr(.ptr(ral.ep_in_enable[0]),   .value(1'b1 << ep));
  csr_wr(.ptr(ral.rxenable_setup[0]), .value(1'b1 << ep));
  csr_wr(.ptr(ral.rxenable_out),   .value(1'b1 << ep));

  // Provide the SETUP and OUT buffers
  csr_wr(.ptr(ral.avsetupbuffer), .value(setup_buf));
  csr_wr(.ptr(ral.avoutbuffer), .value(out_buf));

  // Enable the controller (connects the device)
  csr_wr(.ptr(ral.usbctrl.enable), .value(1'b1));

  // Wait for the DUT to drive the pull-up
  do begin
    cfg.clk_rst_vif.wait_clks(1);
    void'(uvm_hdl_read("tb.dut.usb_dp_pullup_o", pullup_val));
  end while (pullup_val != 1);

  `uvm_info(get_type_name(), "Device detected, sending bus reset", UVM_LOW)

  // Host bus reset
  `uvm_do_on_with(req, p_sequencer.usb20_sequencer_h, {
    kind == usb_transaction::USB_ITEM_BUS_RESET;
  })
  // Sanity check: Powered + bus reset -> LinkActiveNoSOF
  // (the DUT needs a few cycles of sync + filtering to see the end of SE0)
  csr_spinwait(.ptr(ral.usbstat.link_state), .exp_data(LinkActiveNoSOF));

endtask

virtual task send_and_check_out(bit is_setup);
  usb_transaction            usb_rsp;     // DUT response, after the cast
  uvm_sequence_item          rsp_base;    // response as returned by get_response
  usb_transaction::usb_pid_e token_pid;   // SETUP or OUT
  usb_transaction::usb_pid_e data_pid;    // DATA0 or DATA1
  bit [4:0]                  exp_buf;     // expected buffer in the rxfifo entry
  uvm_reg_data_t             rxfifo_val;  // full rxfifo read value
  bit [31:0]                 word;        // one SRAM word
  
  token_pid = is_setup ? usb_transaction::PID_SETUP : usb_transaction::PID_OUT;
  data_pid  = is_setup ? usb_transaction::PID_DATA0 : usb_transaction::PID_DATA1;
  exp_buf   = is_setup ? setup_buf : out_buf;

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
               "Phase %0d: %s randomization failed: conflicting constraints",
               is_setup ? 1 : 2, data_pid.name()))
  req.want_rsp = 1'b1;
  finish_item(req);

  get_response(rsp_base);
  if (!$cast(usb_rsp, rsp_base))
    `uvm_fatal(get_type_name(), $sformatf(
               "Phase %0d: %s response has type %s, expected usb_transaction",
               is_setup ? 1 : 2, data_pid.name(), rsp_base.get_type_name()))
  
  // Check the handshake sent by the DUT
 if (usb_rsp.no_response)
    `uvm_error(get_type_name(), "DUT did not respond to DATA")
  else if (usb_rsp.pid != usb_transaction::PID_ACK)
    `uvm_error(get_type_name(), $sformatf("Expected ACK, got %s", usb_rsp.pid.name()))
  // Check the CSRs
  csr_spinwait(.ptr(ral.intr_state.pkt_received), .exp_data(1'b1));
 
  // Reading rxfifo pops the entry
  csr_rd(.ptr(ral.rxfifo), .value(rxfifo_val));

`DV_CHECK_EQ(get_field_val(ral.rxfifo.buffer,rxfifo_val),exp_buf, "rxfifo.buffer")

`DV_CHECK_EQ(get_field_val(ral.rxfifo.setup,rxfifo_val), is_setup, "rxfifo.setup")

`DV_CHECK_EQ(get_field_val(ral.rxfifo.size, rxfifo_val),req.data.size(),"rxfifo.size")

`DV_CHECK_EQ(get_field_val(ral.rxfifo.ep, rxfifo_val),ep,"rxfifo.ep")

  // Check the SRAM
    for (int i = 0; i < (req.data.size() + 3) / 4; i++) begin
    mem_rd(.ptr(ral.buffer), .offset(exp_buf*16 + i), .data(word));
    for (int j = 0; j < 4; j++) begin
      if (4*i + j < req.data.size()) begin       // the last word may be partially filled
        if (word[8*j +: 8] != req.data[4*i + j])
          `uvm_error(get_type_name(), $sformatf("SRAM byte %0d: expected 0x%02h, got 0x%02h", 4*i + j, req.data[4*i + j], word[8*j +: 8]))
      end
    end
  end
endtask

virtual task send_and_check_in();
 
  byte         data_in[];  // bytes the DUT must send to the host
  int unsigned num_byte;   // number of bytes (1..32)
  bit [31:0]   word;       // one SRAM word
  usb_transaction            usb_rsp;
  uvm_sequence_item          rsp_base;

  // Generate the bytes and write them to in_buf
  num_byte = $urandom_range(1, 32);      // IN is limited to 32 bytes here
  data_in  = new[num_byte];              // allocate num_byte entries
  foreach (data_in[i]) data_in[i] = $urandom();

  for (int i = 0; i < (num_byte + 3) / 4; i++) begin
    word = '0;                           // do not keep bytes from the previous word
    for (int j = 0; j < 4; j++) begin
      if (4*i + j < num_byte)            // the last word may be partially filled
        word[8*j +: 8] = data_in[4*i + j];
    end
    mem_wr(.ptr(ral.buffer), .offset(in_buf*16 + i), .data(word));
  end
  // Arm the IN endpoint (configin)
  ral.configin[ep].buffer.set(in_buf);
  ral.configin[ep].size.set(num_byte);
  ral.configin[ep].rdy.set(1'b1);
  csr_update(ral.configin[ep]);     // single write: buffer, size and rdy together

  // [HOST] IN token, waits for the DATA response
  req = usb_transaction::type_id::create("req");
  start_item(req, -1, p_sequencer.usb20_sequencer_h);
  if (!req.randomize() with {
        kind == usb_transaction::USB_ITEM_NORMAL;
        pid  == usb_transaction::PID_IN;
        addr == 7'h00;
        endp == ep;
      })
    `uvm_fatal(get_type_name(), $sformatf(
               "Phase 3: IN token randomization failed (ep=%0d): conflicting constraints",ep))
  req.want_rsp = 1'b1;
  finish_item(req);

  get_response(rsp_base);           // no delay: the response is already queued
  if (!$cast(usb_rsp, rsp_base))
    `uvm_fatal(get_type_name(), $sformatf(
               "Phase 3: IN response has type %s, expected usb_transaction",rsp_base.get_type_name()))

  // Immediate ACK (the DUT only waits ~17 bit times)
  `uvm_do_on_with(req, p_sequencer.usb20_sequencer_h, {
    kind == usb_transaction::USB_ITEM_NORMAL;
    pid  == usb_transaction::PID_ACK;
  })
  // Check the received DATA1
  // Only after the ACK: from here on, checks can take time
  if (usb_rsp.no_response)
    `uvm_error(get_type_name(), $sformatf(
               "Phase 3: DUT did not respond to IN on ep=%0d (configin not armed?)", ep))
  else begin
    if (usb_rsp.pid != usb_transaction::PID_DATA1)
      `uvm_error(get_type_name(), $sformatf(
                 "Phase 3: IN expected PID_DATA1, got %s", usb_rsp.pid.name()))
    if (usb_rsp.data != data_in)    // != on arrays compares size and every byte
      `uvm_error(get_type_name(), $sformatf(
                 "Phase 3: IN payload differs from the data written to in_buf=%0d (expected %0d bytes, got %0d)",
                 in_buf, data_in.size(), usb_rsp.data.size()))
  end
  // Check the CSRs after the transfer
  // in_sent: the DUT sets bit 'ep' when it receives the host ACK.
  // spinwait because the DUT takes a few cycles to update the CSR.
  csr_spinwait(.ptr(ral.in_sent[0]), .exp_data(1 << ep));     
endtask
endclass