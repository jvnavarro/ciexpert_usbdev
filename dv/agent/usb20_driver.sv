class usb20_driver extends dv_base_driver #(.ITEM_T(usb_transaction),.CFG_T (usb20_agent_cfg));
  `uvm_component_utils(usb20_driver)
  virtual usb20_if vif;

  // Estados elétricos da linha USB Full Speed
  typedef enum bit [1:0] {
    LINE_J,   // D+=1, D-=0 (repouso)
    LINE_K,   // D+=0, D-=1
    LINE_SE0  // D+=0, D-=0 (EOP / reset)
  } line_state_e;

  // Constantes de tempo (clock de 48 MHz, Full Speed = 12 Mbps)
  localparam int unsigned CYCLES_PER_BIT = 4;
  localparam int unsigned CYCLES_PER_US  = 48;

  // Estado do NRZI e do bit stuffing
  protected line_state_e cur_line = LINE_J;
  protected int unsigned ones_cnt = 0;

  function new(string name = "usb20_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual usb20_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal(`gfn, "Nao foi possivel obter a virtual interface 'vif' do config_db!")
    end
  endfunction

  // Barramento em repouso (J-State) durante o reset
  virtual task on_enter_reset();
    set_line(LINE_J);
  endtask

  // ---------------------------------------------------------
  // CAMADA FISICA: coloca um estado na linha
  // ---------------------------------------------------------
  virtual protected task set_line(line_state_e st);
    case (st)
      LINE_J: begin
        vif.cio_usb_dp_i <= 1'b1;
        vif.cio_usb_dn_i <= 1'b0;
      end
      LINE_K: begin
        vif.cio_usb_dp_i <= 1'b0;
        vif.cio_usb_dn_i <= 1'b1;
      end
      LINE_SE0: begin
        vif.cio_usb_dp_i <= 1'b0;
        vif.cio_usb_dn_i <= 1'b0;
      end
    endcase
  endtask

  // Segura o estado da linha por n_bits bit times
  virtual protected task drive_line(line_state_e st, int unsigned n_bits = 1);
    set_line(st);
    repeat (n_bits * CYCLES_PER_BIT) @(posedge vif.clk_i);
  endtask

  // ---------------------------------------------------------
  // CAMADA DE BIT: NRZI + bit stuffing
  // ---------------------------------------------------------
  // NRZI: bit '0' inverte a linha, bit '1' mantém.
  // Stuffing: após seis '1' seguidos é inserido um '0' (inversão extra).
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

  // Envia um byte, LSB primeiro
  virtual protected task send_byte(bit [7:0] data);
    for (int i = 0; i < 8; i++) begin
      send_bit(data[i]);
    end
  endtask

  // ---------------------------------------------------------
  // CRCs (functions: apenas calculam, não consomem tempo)
  // ---------------------------------------------------------
  // CRC5 dos tokens: polinômio x^5 + x^2 + 1, semente 5'h1F, resultado invertido
  virtual protected function bit [4:0] calc_crc5(bit [10:0] data);
    bit [4:0] crc = 5'h1F;
    for (int i = 0; i < 11; i++) begin
      bit fb = data[i] ^ crc[4];
      crc = {crc[3:0], 1'b0} ^ ({5{fb}} & 5'b00101);
    end
    return ~crc;
  endfunction

  // CRC16 dos dados: polinômio x^16 + x^15 + x^2 + 1, semente 16'hFFFF, resultado invertido
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
  // CAMADA DE PACOTE
  // ---------------------------------------------------------
  // SYNC = 8'h80 (LSB primeiro) -> KJKJKJKK na linha
  virtual protected task send_sync();
    cur_line = LINE_J;
    ones_cnt = 0;
    send_byte(8'h80);
  endtask

  // EOP: SE0 por 2 bit times + J por 1 bit time (fora do NRZI)
  virtual protected task send_eop();
    drive_line(LINE_SE0, 2);
    cur_line = LINE_J;
    drive_line(LINE_J, 1);
  endtask

  virtual protected task drive_packet(usb_transaction req);
    send_sync();

    // PID seguido do seu complemento
    send_byte({~req.pid, req.pid});

    if (req.is_token() || req.is_sof()) begin
      // Token: ADDR (7b) + ENDP (4b), SOF: frame number (11b), seguidos do CRC5 (MSB primeiro)
      bit [10:0] fields = req.is_sof() ? req.frame_num : {req.endp, req.addr};
      bit [4:0]  crc5   = calc_crc5(fields);
      for (int i = 0; i < 11; i++) send_bit(fields[i]);
      for (int i = 4; i >= 0; i--) send_bit(crc5[i]);
    end else if (req.is_data()) begin
      // Dados: payload byte a byte seguido do CRC16 (MSB primeiro)
      bit [15:0] crc16 = calc_crc16(req.data);
      foreach (req.data[i]) send_byte(req.data[i]);
      for (int i = 15; i >= 0; i--) send_bit(crc16[i]);
    end
    // Handshake (ACK/NAK/STALL): só o PID

    send_eop();
  endtask

  // Reset de barramento: SE0 por reset_us microssegundos, depois volta para J
  virtual protected task drive_bus_reset(int unsigned reset_us);
    set_line(LINE_SE0);
    repeat (reset_us * CYCLES_PER_US) @(posedge vif.clk_i);
    cur_line = LINE_J;
    drive_line(LINE_J, 1);
  endtask

  // ---------------------------------------------------------
  // Loop principal (chamado pelo dv_base_driver)
  // ---------------------------------------------------------
  virtual task get_and_drive();
    drive_line(LINE_J, 10); // repouso inicial

    forever begin
      seq_item_port.get_next_item(req);

      `uvm_info(`gfn, {"TRACE: Enviando no barramento:\n", req.sprint()}, UVM_LOW)

      case (req.kind)
        usb_transaction::USB_ITEM_BUS_RESET: drive_bus_reset(req.reset_us);
        usb_transaction::USB_ITEM_IDLE:      drive_line(LINE_J, req.idle_bits);
        default: begin
          drive_line(LINE_J, 2); // inter-packet gap de 2 bit times
          drive_packet(req);
        end
      endcase

      seq_item_port.item_done();
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
