/*Verify the functionality of rx_full signal when RX FIFO is full.

- Enable the interrupt for RX full by setting INTR_ENABLE[8] and then send back to back packets to the device.

- Don't service the packets received by popping out from rx_fifo; leave it to become full.

- Verify that this interrupt pin goes high once the received fifo is full.
*/

class usbdev_rx_full_vseq extends usbdev_smoke_vseq;
  `uvm_object_utils(usbdev_rx_full_vseq)

  localparam int RX_FIFO_DEPTH = 8;

  function new(string name = "usbdev_rx_full_vseq");
    super.new(name);
  endfunction

  virtual task body();
    bit [31:0] mask = 32'b1 << ral.intr_enable.rx_full.get_lsb_pos();
    bit [31:0] intr_state_val;

    configure_and_connect();  // already provides 1 buffer to each AV FIFO

    // 1. Provide the remaining OUT buffers and enable the rx_full interrupt
    for (int i = 0; i < RX_FIFO_DEPTH - 2; i++) csr_wr(.ptr(ral.avoutbuffer), .value(i));
    csr_wr(.ptr(ral.intr_enable), .value(mask));

    // 2. Send back to back packets, without reading the rxfifo.
    // A regular OUT cannot use the last RX FIFO entry, so 7 OUTs leave it one short of full
    for (int i = 0; i < RX_FIFO_DEPTH - 1; i++) send_no_pop(1'b0, i);
    `DV_CHECK_EQ(cfg.intr_vif.sample() & mask, 0, "rx_full pin is high before the RX FIFO is full")

    // A SETUP can use the last entry
    send_no_pop(1'b1, 0);

    // 3. The RX FIFO is now full: intr_state and the interrupt pin must be high
    csr_rd(.ptr(ral.intr_state), .value(intr_state_val));
    `DV_CHECK_EQ(intr_state_val & mask, mask, "intr_state rx_full is low")
    `DV_CHECK_EQ(cfg.intr_vif.sample() & mask, mask, "rx_full interrupt pin is low")
  endtask

  // Sends token + DATA and checks the ACK; the packet stays in the RX FIFO
  virtual task send_no_pop(bit is_setup, int pkt_idx);
    usb_transaction            usb_rsp;
    uvm_sequence_item          rsp_base;
    usb_transaction::usb_pid_e token_pid;
    usb_transaction::usb_pid_e data_pid;

    token_pid = is_setup ? usb_transaction::PID_SETUP : usb_transaction::PID_OUT;
    data_pid  = (is_setup || (pkt_idx % 2 == 0)) ? usb_transaction::PID_DATA0 : usb_transaction::PID_DATA1;

    // Token, no response expected
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
      `uvm_fatal(get_type_name(), $sformatf("Packet %0d: randomization failed", pkt_idx))
    req.want_rsp = 1'b1;
    finish_item(req);

    get_response(rsp_base);
    if (!$cast(usb_rsp, rsp_base))
      `uvm_fatal(get_type_name(), $sformatf("Packet %0d: response is not a usb_transaction", pkt_idx))

    if (usb_rsp.no_response)
      `uvm_error(get_type_name(), $sformatf("Packet %0d: DUT did not respond to DATA", pkt_idx))
    else if (usb_rsp.pid != usb_transaction::PID_ACK)
      `uvm_error(get_type_name(), $sformatf("Packet %0d: expected ACK, got %s", pkt_idx, usb_rsp.pid.name()))
  endtask

endclass
