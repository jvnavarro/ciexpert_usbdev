class usb20_monitor extends dv_base_monitor #(.ITEM_T(usb_transaction),.CFG_T (usb20_agent_cfg));
  `uvm_component_utils(usb20_monitor)
  virtual usb20_if vif;
  // Variables used to undo NRZI and bit stuffing
  bit prev_dp;
  int ones_cnt;

  // Min SE0 duration for a bus reset: 2.5 us per the USB spec (48 cycles = 1 us)
  localparam int unsigned CYCLES_PER_US   = 48;
  localparam int unsigned RESET_MIN_CYCLES = (5 * CYCLES_PER_US) / 2;

  function new(string name = "usb20_monitor", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual usb20_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal(`gfn, "Monitor could not get the virtual interface 'vif' from the config_db")
    end
  endfunction

  // Bus pins. In the tb each direction has its own wires: when the DUT is
  // sending (cio_usb_dp_en_o = 1) the line is on the _o pins, otherwise on _i (host).
  // All pin reads go through here.
  function bit dut_driving(); return (vif.cio_usb_dp_en_o == 1'b1); endfunction
  function bit raw_dp();      return dut_driving() ? vif.cio_usb_dp_o : vif.cio_usb_dp_i; endfunction
  function bit raw_dn();      return dut_driving() ? vif.cio_usb_dn_o : vif.cio_usb_dn_i; endfunction
  function bit line_dp();     return cfg.pinflip ? raw_dn() : raw_dp(); endfunction
  function bit line_dn();     return cfg.pinflip ? raw_dp() : raw_dn(); endfunction

  // Line states
  function bit line_is_j();   return (line_dp() == 1'b1 && line_dn() == 1'b0); endfunction
  function bit line_is_k();   return (line_dp() == 1'b0 && line_dn() == 1'b1); endfunction
  function bit line_is_se0(); return (line_dp() == 1'b0 && line_dn() == 1'b0); endfunction

  // Task called by the parent class dv_base_monitor
  virtual protected task collect_trans();
    usb_transaction trans;
    bit is_se0;
    bit valid;
    bit current_dir_in = 1'b0;
    bit [3:0] current_endp = 4'h0;

    forever begin
      if (cfg != null && !cfg.en_monitor) begin
        @(posedge vif.clk_i);
        continue;
      end

      // 1. Wait for the line to leave J: K = start of packet, SE0 = possible reset
      wait_for_start_of_packet(is_se0);

      if (cfg != null && !cfg.en_monitor) begin
        continue;
      end

      // 2. Create the item that stores the captured transaction
      trans = usb_transaction::type_id::create("trans");
      trans.from_device = dut_driving(); // who started sending

      // 3. Collect the reset or the packet
      if (is_se0) begin
        collect_bus_reset(trans, valid);
        current_dir_in = 1'b0;
        current_endp   = 4'h0;
      end else begin
        collect_packet(trans, valid);

        // In USB, DATA and handshake packets take the direction and EP of the previous token
        if (trans.pid == usb_transaction::PID_IN) begin
          current_dir_in = 1'b1;
          current_endp   = trans.endp;
          trans.dir_in   = 1'b1;
        end else if (trans.pid inside {usb_transaction::PID_OUT, usb_transaction::PID_SETUP}) begin
          current_dir_in = 1'b0;
          current_endp   = trans.endp;
          trans.dir_in   = 1'b0;
        end else begin
          trans.dir_in   = current_dir_in;
          trans.endp     = current_endp;
        end
      end

      // 4. Only valid items are sent to the scoreboard
      if (valid) begin
        `uvm_info(`gfn, {"TRACE: Item captured by the monitor:\n", trans.sprint()}, UVM_LOW)
        analysis_port.write(trans);
      end
    end
  endtask

  // Helper task: waits for the line to leave J and reports whether it went to K or SE0
  task wait_for_start_of_packet(output bit is_se0);
    @(posedge vif.clk_i);
    // While the monitor is disabled or the line is idle (J or SE1)
    while ((cfg != null && !cfg.en_monitor) || (!line_is_k() && !line_is_se0())) begin
      if ((cfg == null || cfg.en_monitor) && !line_is_j()) begin
        `uvm_warning(`gfn, "Line in SE1 (D+=1, D-=1) while waiting for start of packet")
      end
      @(posedge vif.clk_i);
    end
    is_se0 = line_is_se0();
    `uvm_info(`gfn, is_se0 ? "TRACE: SE0 detected (possible bus reset)"
                           : "TRACE: K detected (start of packet)", UVM_HIGH)

    // Initialize the NRZI and bit stuffing variables
    prev_dp  = 1'b1; // the line was in J (D+=1)
    ones_cnt = 0;
  endtask

  // Measures how long the line stays in SE0. It is a bus reset only if it lasts >= 2.5 us;
  // a shorter SE0 is ignored.
  task collect_bus_reset(usb_transaction trans, output bit valid);
    int unsigned count_cycles = 0;

    // The line is already in SE0 (ensured by wait_for_start_of_packet): count until it leaves
    while (line_is_se0()) begin
      count_cycles++;
      @(posedge vif.clk_i);
    end

    valid = (count_cycles >= RESET_MIN_CYCLES);
    if (valid) begin
      trans.kind     = usb_transaction::USB_ITEM_BUS_RESET;
      trans.reset_us = count_cycles / CYCLES_PER_US;
    end else begin
      `uvm_warning(`gfn, $sformatf("SE0 of %0d cycles is too short for a bus reset, ignoring",
                                   count_cycles))
    end
  endtask

  // Reads the next bit. eop = 1 if the line was in SE0 (end of packet): in that case
  // out_bit is not valid and the NRZI/stuffing state is not updated.
  task get_next_bit(output bit out_bit, output bit eop);
    bit current_dp;

    // 1. Wait until the middle of the bit time (2 cycles at 48 MHz) to sample reliably
    repeat (2) @(posedge vif.clk_i);
    eop = line_is_se0();
    if (eop) return;
    current_dp = line_dp();

    // 2. Undo NRZI
    if (current_dp == prev_dp) begin
      out_bit = 1'b1; // line did not change: the bit is '1'
      ones_cnt++;
    end else begin
      out_bit = 1'b0; // line toggled: the bit is '0'
      ones_cnt = 0;
    end

    prev_dp = current_dp; // keep it for the next bit

    // 3. Finish the second half of the bit time (2 more cycles)
    repeat (2) @(posedge vif.clk_i);

    // 4. Undo bit stuffing (unstuffing)
    if (ones_cnt == 6) begin
      // The sender inserted a stuffed '0' here: skip its bit time (4 cycles)
      repeat (2) @(posedge vif.clk_i);
      prev_dp = line_dp(); // update the reference, since the stuffed '0' toggled the pin
      repeat (2) @(posedge vif.clk_i);
      ones_cnt = 0;
    end
  endtask

  task collect_packet(usb_transaction trans, output bit valid);
    bit [7:0]  sync_byte;
    bit [7:0]  pid_byte;
    bit [15:0] token_payload;
    bit        raw_bit;
    bit        eop;
    bit [7:0]  cur_byte;
    int        bit_cnt;
    byte       bytes[$];

    valid = 1'b1;

    // 1. Read the SYNC byte
    for (int i = 0; i < 8; i++) begin
      get_next_bit(raw_bit, eop);
      sync_byte[i] = raw_bit;
    end
    // SYNC: the bits on the wire are 0,0,0,0,0,0,0,1 and bit i goes to sync_byte[i] -> 8'h80
    if (sync_byte != 8'h80) begin
      `uvm_error(`gfn, $sformatf("Invalid SYNC: 0x%02h (expected 0x80)", sync_byte))
      valid = 1'b0;
    end

    // 2. Read the PID byte
    for (int i = 0; i < 8; i++) begin
      get_next_bit(raw_bit, eop);
      pid_byte[i] = raw_bit;
    end
    // PID: the upper 4 bits are the complement of the lower 4
    if (valid && pid_byte[7:4] != ~pid_byte[3:0]) begin
      `uvm_error(`gfn, $sformatf("Invalid PID: 0x%02h (check bits do not match)", pid_byte))
      valid = 1'b0;
    end

    // 3. Read the payload based on the PID (only if SYNC and PID are valid)
    if (valid) begin
      // Use only the lower 4 PID bits (the other 4 are the inverted check copy)
      trans.pid  = usb_transaction::usb_pid_e'(pid_byte[3:0]);
      trans.kind = usb_transaction::USB_ITEM_NORMAL;

      case (trans.pid)
        usb_transaction::PID_OUT,
        usb_transaction::PID_IN,
        usb_transaction::PID_SETUP,
        usb_transaction::PID_SOF: begin
          // Token or SOF: exactly 16 bits after the PID (11 field bits + 5 CRC5 bits)
          for (int i = 0; i < 16; i++) begin
            get_next_bit(raw_bit, eop);
            token_payload[i] = raw_bit;
          end
          if (trans.pid == usb_transaction::PID_SOF) begin
            trans.frame_num = token_payload[10:0];
          end else begin
            trans.addr = token_payload[6:0];
            trans.endp = token_payload[10:7];
          end
          trans.crc5 = {<<{token_payload[15:11]}};
        end

        usb_transaction::PID_DATA0,
        usb_transaction::PID_DATA1: begin
          // DATA packet: read bytes (LSB first) until the EOP
          bit_cnt = 0;
          forever begin
            get_next_bit(raw_bit, eop);
            if (eop) break;
            cur_byte[bit_cnt] = raw_bit;
            bit_cnt++;
            if (bit_cnt == 8) begin
              bytes.push_back(cur_byte);
              bit_cnt = 0;
            end
          end
          if (bit_cnt != 0) begin
            `uvm_error(`gfn, $sformatf("DATA ended with %0d leftover bits (not a full byte)", bit_cnt))
            valid = 1'b0;
          end else if (bytes.size() < 2) begin
            `uvm_error(`gfn, $sformatf("DATA without CRC16: only %0d bytes", bytes.size()))
            valid = 1'b0;
          end else begin
            // The last 2 bytes are the CRC16: keep them out of the payload
            trans.data = new[bytes.size() - 2];
            foreach (trans.data[i]) trans.data[i] = bytes[i];
            trans.crc16 = {<<{bytes[bytes.size() - 2], bytes[bytes.size() - 1]}};
          end
        end

        usb_transaction::PID_ACK,
        usb_transaction::PID_NAK,
        usb_transaction::PID_STALL: begin
          // Handshake: the packet ends after the PID, nothing else to read
        end

        default: begin
          `uvm_error(`gfn, $sformatf("PID not supported by the monitor: 0x%0h", pid_byte[3:0]))
          valid = 1'b0;
        end
      endcase
    end

    // 4. Wait for the End of Packet (SE0), even for an invalid packet, so we
    //    do not resync in the middle of garbage
    while (!line_is_se0()) begin
      @(posedge vif.clk_i);
    end

    // Wait for the line to return to idle (J) after the EOP
    while (line_is_se0()) begin
      @(posedge vif.clk_i);
    end
  endtask
endclass
