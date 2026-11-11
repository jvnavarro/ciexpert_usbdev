class usb20_driver extends dv_base_driver #(.ITEM_T(usb_transaction),.CFG_T (usb20_agent_cfg));
  `uvm_component_utils(usb20_driver)
  virtual usb20_if vif;

  // Electrical states of the USB Full Speed line
  typedef enum bit [1:0] {
    LINE_J,   // D+=1, D-=0 (idle)
    LINE_K,   // D+=0, D-=1
    LINE_SE0  // D+=0, D-=0 (EOP / reset)
  } line_state_e;

  // Timing constants (48 MHz clock, Full Speed = 12 Mbps)
  localparam int unsigned CYCLES_PER_BIT = 4;
  localparam int unsigned CYCLES_PER_US  = 48;
  // Max time the host waits for the device to start responding (turnaround: ~16-18 bit times)
  localparam int unsigned RSP_TIMEOUT_CYCLES = 18 * CYCLES_PER_BIT;

  // NRZI and bit stuffing state
  protected line_state_e cur_line = LINE_J;
  protected int unsigned ones_cnt = 0;

  function new(string name = "usb20_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual usb20_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal(`gfn, "Could not get the virtual interface 'vif' from the config_db")
    end
  endfunction

  // Bus idle (J state) during reset
  virtual task on_enter_reset();
    set_line(LINE_J);
  endtask

  // ---------------------------------------------------------
  // PHYSICAL LAYER: drives a state on the line
  // ---------------------------------------------------------
  virtual protected task set_line(line_state_e st);
    case (st)
      LINE_J: begin
        vif.cio_usb_dp_i <= ~cfg.pinflip;
        vif.cio_usb_dn_i <= cfg.pinflip;
      end
      LINE_K: begin
        vif.cio_usb_dp_i <= cfg.pinflip;
        vif.cio_usb_dn_i <= ~cfg.pinflip;
      end
      LINE_SE0: begin
        vif.cio_usb_dp_i <= 1'b0;
        vif.cio_usb_dn_i <= 1'b0;
      end
    endcase
  endtask

  // Holds the line state for n_bits bit times
  virtual protected task drive_line(line_state_e st, int unsigned n_bits = 1);
    set_line(st);
    repeat (n_bits * CYCLES_PER_BIT) @(posedge vif.clk_i);
  endtask

  // ---------------------------------------------------------
  // BIT LAYER: NRZI + bit stuffing
  // ---------------------------------------------------------
  // NRZI: bit '0' toggles the line, bit '1' keeps it.
  // Stuffing: after six '1's in a row a '0' is inserted (extra toggle).
  virtual protected task send_bit(bit b);
    if (b == 1'b0) begin
      cur_line = (cur_line == LINE_J) ? LINE_K : LINE_J;
      ones_cnt = 0;
    end else begin
      ones_cnt++;
    end
    drive_line(cur_line, 1);

    if (ones_cnt == 6) begin
      cur_line = (cur_line == LINE_J) ? LINE_K : LINE_J;
      drive_line(cur_line, 1);
      ones_cnt = 0;
    end
  endtask

  // Sends one byte, LSB first
  virtual protected task send_byte(bit [7:0] data);
    for (int i = 0; i < 8; i++) begin
      send_bit(data[i]);
    end
  endtask

  // ---------------------------------------------------------
  // CRCs (functions: compute only, no simulation time)
  // ---------------------------------------------------------
  // Token CRC5: polynomial x^5 + x^2 + 1, seed 5'h1F, inverted result
  virtual protected function bit [4:0] calc_crc5(bit [10:0] data);
    bit [4:0] crc = 5'h1F;
    for (int i = 0; i < 11; i++) begin
      bit fb = data[i] ^ crc[4];
      crc = {crc[3:0], 1'b0} ^ ({5{fb}} & 5'b00101);
    end
    return ~crc;
  endfunction

  // Data CRC16: polynomial x^16 + x^15 + x^2 + 1, seed 16'hFFFF, inverted result
  virtual protected function bit [15:0] calc_crc16(byte data[]);
    bit [15:0] crc = 16'hFFFF;
    foreach (data[i]) begin
      for (int b = 0; b < 8; b++) begin
        bit fb = data[i][b] ^ crc[15];
        crc = {crc[14:0], 1'b0} ^ ({16{fb}} & 16'h8005);
      end
    end
    return ~crc;
  endfunction

  // ---------------------------------------------------------
  // PACKET LAYER
  // ---------------------------------------------------------
  // SYNC = 8'h80 (LSB first) -> KJKJKJKK on the line
  virtual protected task send_sync();
    cur_line = LINE_J;
    ones_cnt = 0;
    send_byte(8'h80);
  endtask

  // EOP: SE0 for 2 bit times + J for 1 bit time (outside NRZI)
  virtual protected task send_eop();
    drive_line(LINE_SE0, 2);
    cur_line = LINE_J;
    drive_line(LINE_J, 1);
  endtask

  virtual protected task drive_packet(usb_transaction req);
    send_sync();

    // PID followed by its complement
    send_byte({~req.pid, req.pid});

    if (req.is_token() || req.is_sof()) begin
      // Token: ADDR (7b) + ENDP (4b), SOF: frame number (11b), followed by CRC5 (MSB first)
      bit [10:0] fields = req.is_sof() ? req.frame_num : {req.endp, req.addr};
      bit [4:0]  crc5   = calc_crc5(fields);
      for (int i = 0; i < 11; i++) send_bit(fields[i]);
      for (int i = 4; i >= 0; i--) send_bit(crc5[i]);
    end else if (req.is_data()) begin
      // Data: payload byte by byte, followed by CRC16 (MSB first)
      bit [15:0] crc16 = calc_crc16(req.data);
      foreach (req.data[i]) send_byte(req.data[i]);
      for (int i = 15; i >= 0; i--) send_bit(crc16[i]);
    end
    // Handshake (ACK/NAK/STALL): PID only

    send_eop();
  endtask

  // Bus reset: SE0 for reset_us microseconds, then back to J
  virtual protected task drive_bus_reset(int unsigned reset_us);
    set_line(LINE_SE0);
    repeat (reset_us * CYCLES_PER_US) @(posedge vif.clk_i);
    cur_line = LINE_J;
    drive_line(LINE_J, 1);
  endtask

  // ---------------------------------------------------------
  // RECEIVE: decodes what the DUT sends (_o pins), the reverse of send_*
  // ---------------------------------------------------------
  // pkt[0] = SYNC (8'h80), pkt[1] = PID, rest = payload + CRC16.
  // Returns an empty pkt if the DUT does not start sending within RSP_TIMEOUT_CYCLES.
  virtual protected task receive_from_dut(output byte pkt[$]);
    bit       prev_dp;     // previous D+ value (for NRZI)
    bit       cur_dp;
    bit       cur_dn;
    bit       b;           // decoded bit
    int       rx_ones_cnt; // consecutive 1s (for unstuffing)
    bit [7:0] cur_byte;    // byte being assembled (LSB first)
    int       bit_cnt;     // bits already in cur_byte

    pkt.delete();
    rx_ones_cnt = 0;
    bit_cnt     = 0;

    // 1. Wait for the DUT to start sending, with a timeout
    fork begin : isolation_fork
      fork
        wait (vif.cio_usb_dp_en_o == 1'b1);
        repeat (RSP_TIMEOUT_CYCLES) @(posedge vif.clk_i);
      join_any
      disable fork;
    end join
    if (vif.cio_usb_dp_en_o != 1'b1) return;

    // 2. Move to the middle of the first bit (1 bit = 4 cycles at 48 MHz)
    repeat (2) @(posedge vif.clk_i);
    prev_dp = 1'b1; // the line was in J

    // 3. One bit per iteration
    forever begin
      // Sample the signal in the middle of the current bit
      cur_dp = cfg.pinflip ? vif.cio_usb_dn_o : vif.cio_usb_dp_o;
      cur_dn = cfg.pinflip ? vif.cio_usb_dp_o : vif.cio_usb_dn_o;

      // Line in SE0 -> end of packet (EOP)
      if (cur_dp == 1'b0 && cur_dn == 1'b0) break;

      if (rx_ones_cnt == 6) begin
        // Stuffed bit: do not store it, just reset the counter
        rx_ones_cnt = 0;
      end else begin
        // NRZI: same as previous = 1, changed = 0
        if (cur_dp == prev_dp) begin
          b = 1'b1;
          rx_ones_cnt++;
        end else begin
          b = 1'b0;
          rx_ones_cnt = 0;
        end

        // Assemble the byte, LSB first
        cur_byte[bit_cnt] = b;
        bit_cnt++;
        if (bit_cnt == 8) begin
          pkt.push_back(cur_byte);
          bit_cnt = 0;
        end
      end

      prev_dp = cur_dp;
      // Wait 4 cycles to reach the middle of the next bit
      repeat (CYCLES_PER_BIT) @(posedge vif.clk_i);
    end

    if (bit_cnt != 0) begin
      `uvm_error(`gfn, $sformatf("DUT packet ended with %0d leftover bits (not a full byte)",
                                 bit_cnt))
    end

    // Wait for the DUT to release the line (end of EOP) before the host sends again
    wait (vif.cio_usb_dp_en_o == 1'b0);
  endtask

  // Receives the DUT response and fills the rsp item (pid, data, no_response)
  virtual protected task get_device_response(usb_transaction rsp);
    byte pkt[$];

    receive_from_dut(pkt);
    rsp.kind        = usb_transaction::USB_ITEM_NORMAL;
    rsp.from_device = 1'b1;

    if (pkt.size() == 0) begin
      rsp.no_response = 1'b1;
      return;
    end

    if (pkt[0] != 8'h80) begin
      `uvm_error(`gfn, $sformatf("Invalid SYNC in the DUT response: 0x%02h", pkt[0]))
    end
    if (pkt.size() < 2) begin
      `uvm_error(`gfn, "DUT response has no PID")
      return;
    end
    if (pkt[1][7:4] != ~pkt[1][3:0]) begin
      `uvm_error(`gfn, $sformatf("Invalid PID in the DUT response: 0x%02h", pkt[1]))
    end
    rsp.pid = usb_transaction::usb_pid_e'(pkt[1][3:0]);

    // DATA: payload = everything between the PID and the 2 CRC16 bytes
    if (rsp.is_data()) begin
      if (pkt.size() < 4) begin
        `uvm_error(`gfn, $sformatf("DATA packet from the DUT is too short: %0d bytes", pkt.size()))
        return;
      end
      rsp.data = new[pkt.size() - 4];
      foreach (rsp.data[i]) rsp.data[i] = pkt[i + 2];
    end
  endtask

  // ---------------------------------------------------------
  // Main loop (called by dv_base_driver)
  // ---------------------------------------------------------
  virtual task get_and_drive();
    drive_line(LINE_J, 10); // initial idle

    fork
      forever @(cfg.pinflip) set_line(cur_line);
    join_none

    forever begin
      seq_item_port.get_next_item(req);

      `uvm_info(`gfn, {"TRACE: Sending on the bus:\n", req.sprint()}, UVM_LOW)

      case (req.kind)
        usb_transaction::USB_ITEM_BUS_RESET: drive_bus_reset(req.reset_us);
        usb_transaction::USB_ITEM_IDLE:      drive_line(LINE_J, req.idle_bits);
        default: begin
          drive_line(LINE_J, 2); // inter-packet gap of 2 bit times
          drive_packet(req);
        end
      endcase

      // DATA and IN: like a real host, wait for the device to finish responding before
      // the next packet (otherwise host and DUT drive the bus at the same time). The
      // response goes back to the sequence only if it asked (want_rsp = 1), via get_response().
      if (req.kind == usb_transaction::USB_ITEM_NORMAL && req.expects_response()) begin
        usb_transaction rsp = usb_transaction::type_id::create("rsp");
        rsp.set_id_info(req);
        get_device_response(rsp);
        `uvm_info(`gfn, {"TRACE: DUT response:\n", rsp.sprint()}, UVM_LOW)
        if (req.want_rsp) seq_item_port.item_done(rsp);
        else              seq_item_port.item_done();
      end else begin
        seq_item_port.item_done();
      end
    end
  endtask

endclass

/*
Tempo ──►
  ┌──────────┬──────────┬──────────────────────────────┬──────────┐
  │ IPG (J)  │  SYNC    │ PID + campos + CRC            │   EOP    │
  │ 2 bits   │  8 bits  │ (NRZI + bit stuffing)         │ SE0,SE0,J│
  └──────────┴──────────┴──────────────────────────────┴──────────┘
*/
