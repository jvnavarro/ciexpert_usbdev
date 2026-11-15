class usbdev_pkt_buffer_vseq extends usbdev_smoke_vseq; // reuses the smoke connect/config tasks

`uvm_object_utils(usbdev_pkt_buffer_vseq)

function new(string name = "usbdev_pkt_buffer_vseq");
    super.new(name);
endfunction
typedef struct {
  bit [3:0] ep;
  bit [4:0] buffer;
  byte      data[];
} rxfifo_entry_t;

rxfifo_entry_t expected_q[$];

virtual task body();
  int num = 4; // number of OUT packets in the burst
  
  // 1. Configure the CSRs and connect the device
  configure_and_connect();

  // 2. Send a burst of OUT packets, filling the RX FIFO
  send_packet_burst(num);

  // 3. Drain the RX FIFO and check the packet buffer (SRAM)
  check_rxfifo_and_sram(num);

endtask

virtual task send_packet_burst(int num_pkts);
  rxfifo_entry_t entry;
  bit [4:0]      current_buf;
  usb_transaction::usb_pid_e data_pid;
  usb_transaction            usb_rsp;   
  uvm_sequence_item          rsp_base;

  bit [4:0]      used_bufs[$];  // buffers already in use (smoke connect + burst)

  used_bufs.push_back(setup_buf);
  used_bufs.push_back(out_buf);
  used_bufs.push_back(in_buf);

  for (int i = 0; i < num_pkts; i++) begin

    if (i == 0) begin
      current_buf = out_buf;
    end else begin
      // pick a buffer that is not in use yet
      do begin
        current_buf = $urandom_range(0, 31);
      end while (current_buf inside {used_bufs});
      used_bufs.push_back(current_buf);
      // hand it to the DUT
      csr_wr(.ptr(ral.avoutbuffer), .value(current_buf)); 
    end

    // OUT token
  `uvm_do_on_with(req, p_sequencer.usb20_sequencer_h, {
      req.kind == usb_transaction::USB_ITEM_NORMAL;
      req.pid  == usb_transaction::PID_OUT;
      req.addr == 7'h00;
      req.endp == ep;
  })
    // DATA packet, alternating the data toggle (DATA0/DATA1)
    data_pid = (i % 2 == 0) ? usb_transaction::PID_DATA0 : usb_transaction::PID_DATA1;

    req = usb_transaction::type_id::create("req");
    start_item(req, -1, p_sequencer.usb20_sequencer_h);
    `DV_CHECK_RANDOMIZE_WITH_FATAL(req,
      req.kind == usb_transaction::USB_ITEM_NORMAL;
      req.pid  == data_pid;
    )
    req.want_rsp = 1'b1; // wait for the handshake (ACK)
    finish_item(req);
    // check the handshake
    get_response(rsp_base);
    `DV_CHECK_FATAL($cast(usb_rsp, rsp_base), "Failed to cast the USB response")
    `DV_CHECK_EQ(usb_rsp.pid, usb_transaction::PID_ACK, $sformatf("Expected ACK on burst packet %0d, got 0x%0h", i, usb_rsp.pid))
    // save the expected RX FIFO entry
    entry.ep     = ep;
    entry.buffer = current_buf;
    entry.data   = req.data; 
    expected_q.push_back(entry);
    
  end
endtask

// Drains the RX FIFO: for each packet, checks the rxfifo entry against the
// expected one and checks the data written to the packet buffer (SRAM).
virtual task check_rxfifo_and_sram(int num_pkts);
  rxfifo_entry_t  pkt_exp;      // expected packet for this iteration
  uvm_reg_data_t  val_rxfifo;   // rxfifo entry read for this iteration

  // Wait for all packets (reading rx_depth does not pop the FIFO)
  csr_spinwait(.ptr(ral.usbstat.rx_depth), .exp_data(num_pkts));

  for (int i = 0; i < num_pkts; i++) begin
    pkt_exp = expected_q.pop_front();               // expected (same order as sent)
    csr_rd(.ptr(ral.rxfifo), .value(val_rxfifo));   // actual (pops the RX FIFO)

    // rxfifo entry, field by field
    `DV_CHECK_EQ(get_field_val(ral.rxfifo.buffer, val_rxfifo), pkt_exp.buffer, $sformatf("buffer, packet %0d", i))
    `DV_CHECK_EQ(get_field_val(ral.rxfifo.ep, val_rxfifo), pkt_exp.ep, $sformatf("ep, packet %0d", i))
    `DV_CHECK_EQ(get_field_val(ral.rxfifo.size, val_rxfifo), pkt_exp.data.size(), $sformatf("size, packet %0d", i))
    `DV_CHECK_EQ(get_field_val(ral.rxfifo.setup, val_rxfifo), 0, $sformatf("setup, packet %0d", i))

    // SRAM data: use the buffer and size READ from rxfifo (where the DUT says it wrote)
    check_sram(get_field_val(ral.rxfifo.buffer, val_rxfifo),
               get_field_val(ral.rxfifo.size, val_rxfifo),
               pkt_exp.data);
  end

  // All entries were read: the RX FIFO must be empty
  csr_spinwait(.ptr(ral.usbstat.rx_empty), .exp_data(1));
endtask

// Reads a packet buffer from the SRAM word by word and checks each byte.
//   word i of buffer N    = offset N*16 + i       (16 words of 4 bytes per buffer)
//   byte j of the word    = data_read[8*j +: 8]   (little-endian: byte 0 at the bottom)
//   byte of the packet    = data_exp[4*i + j]
virtual task check_sram(uvm_reg_data_t buffer, uvm_reg_data_t size, byte data_exp[]);
  bit [31:0] data_read;

  for (int i = 0; i < (size + 3) / 4; i++) begin
    mem_rd(.ptr(ral.buffer), .offset(buffer*16 + i), .data(data_read));
    for (int j = 0; j < 4; j++) begin
      if (4*i + j < size) begin   // the last word may be partially filled
        `DV_CHECK_EQ(data_read[8*j +: 8], data_exp[4*i + j], $sformatf("SRAM buffer %0d, byte %0d", buffer, 4*i + j))
      end
    end
  end
endtask

endclass
