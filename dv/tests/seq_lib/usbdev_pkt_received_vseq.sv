class usbdev_pkt_received_vseq extends usbdev_smoke_vseq;
  `uvm_object_utils(usbdev_pkt_received_vseq)

  function new(string name = "usbdev_pkt_received_vseq");
    super.new(name);
  endfunction

  virtual task body();
    // 1. Configure CSRs, supply setup_buf/out_buf, connect device and send Bus Reset
    configure_and_connect();

    // 2. Enable INTR_ENABLE[0] (pkt_received)
    csr_wr(.ptr(ral.intr_enable.pkt_received), .value(1'b1));

    // 3. Verify pkt_received interrupt on SETUP packet reception (DATA0)
    send_and_verify_pkt_received(.is_setup(1'b1));

    // 4. Verify pkt_received interrupt on OUT packet reception (DATA1)
    send_and_verify_pkt_received(.is_setup(1'b0));
  endtask

  virtual task send_and_verify_pkt_received(bit is_setup);
    uvm_sequence_item          rsp_base;
    usb_transaction            usb_rsp;
    usb_transaction::usb_pid_e token_pid;
    usb_transaction::usb_pid_e data_pid;
    bit [4:0]                  exp_buf;
    uvm_reg_data_t             rxfifo_val;
    bit [31:0]                 word;

    token_pid = is_setup ? usb_transaction::PID_SETUP : usb_transaction::PID_OUT;
    data_pid  = is_setup ? usb_transaction::PID_DATA0 : usb_transaction::PID_DATA1;
    exp_buf   = is_setup ? setup_buf : out_buf;

    // Confirm interrupt pin[0] and CSR are initially low before packet reception
    `DV_CHECK_EQ(cfg.intr_vif.pins[IntrPktReceived], 1'b0,
                 "intr_pkt_received_o pin[0] must be low before packet reception")
    csr_rd_check(.ptr(ral.intr_state.pkt_received), .compare_value(1'b0));

    // 1. Send SETUP or OUT token packet to the enabled endpoint
    `uvm_do_on_with(req, p_sequencer.usb20_sequencer_h, {
      kind == usb_transaction::USB_ITEM_NORMAL;
      pid  == token_pid;
      addr == 7'h00;
      endp == ep;
    })

    // 2. Send following DATA packet and wait for ACK handshake
    req = usb_transaction::type_id::create("req");
    start_item(req, -1, p_sequencer.usb20_sequencer_h);
    `DV_CHECK_RANDOMIZE_WITH_FATAL(req,                                                                                                                                                                                                                                                                                                                                                                                                  
      kind == usb_transaction::USB_ITEM_NORMAL;
      pid  == data_pid;
      is_setup -> data.size() == 8;
    )
    req.want_rsp = 1'b1;
    finish_item(req);

    get_response(rsp_base);
    `DV_CHECK_FATAL($cast(usb_rsp, rsp_base), "Failed to cast USB response")
    `DV_CHECK_EQ(usb_rsp.pid, usb_transaction::PID_ACK,
                 $sformatf("Expected ACK handshake for %s packet", token_pid.name()))

    // 3. Verify that intr_state.pkt_received CSR and physical interrupt pin[0] go high
    csr_spinwait(.ptr(ral.intr_state.pkt_received), .exp_data(1'b1));
    `DV_CHECK_EQ(cfg.intr_vif.pins[IntrPktReceived], 1'b1,
                 $sformatf("intr_pkt_received_o pin[0] did not go high after %s reception",
                           token_pid.name()))

    // 4. Pop rxfifo to verify packet reception metadata (and clear the Status interrupt condition)
    csr_rd(.ptr(ral.rxfifo), .value(rxfifo_val));
    `DV_CHECK_EQ(get_field_val(ral.rxfifo.buffer, rxfifo_val), exp_buf,          "rxfifo.buffer")
    `DV_CHECK_EQ(get_field_val(ral.rxfifo.ep,     rxfifo_val), ep,               "rxfifo.ep")
    `DV_CHECK_EQ(get_field_val(ral.rxfifo.setup,  rxfifo_val), is_setup,         "rxfifo.setup")
    `DV_CHECK_EQ(get_field_val(ral.rxfifo.size,   rxfifo_val), req.data.size(),  "rxfifo.size")

    // 5. Verify the received payload bytes in the 2 kB SRAM buffer
    for (int i = 0; i < (req.data.size() + 3) / 4; i++) begin
      mem_rd(.ptr(ral.buffer), .offset(exp_buf * 16 + i), .data(word));
      for (int b = 0; b < 4; b++) begin
        if (i * 4 + b < req.data.size()) begin
          `DV_CHECK_EQ(word[b*8 +: 8], req.data[i*4 + b],
                       $sformatf("SRAM mismatch at byte %0d", i*4 + b))
        end
      end
    end

    // 6. Because pkt_received is a Status-type (RO) interrupt, emptying rxfifo
    //    automatically clears intr_state.pkt_received and deasserts the interrupt pin
    csr_rd_check(.ptr(ral.intr_state.pkt_received), .compare_value(1'b0));
    `DV_CHECK_EQ(cfg.intr_vif.pins[IntrPktReceived], 1'b0,
                 "intr_pkt_received_o pin[0] should automatically deassert after rxfifo is emptied")
  endtask

endclass : usbdev_pkt_received_vseq
