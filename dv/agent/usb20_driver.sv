class usb20_driver extends dv_base_driver #(.ITEM_T(usb_transaction),.CFG_T (usb20_agent_cfg));
  `uvm_component_utils(usb20_driver)
  virtual usb20_if vif;

  function new(string name = "usb20_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual usb20_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal(`gfn, "Nao foi possivel obter a virtual interface 'vif' do config_db!")
    end
  endfunction

  //  em repouso (J-State)
  task drive_idle(int cycles);
    for (int i = 0; i < cycles; i++) begin
      @(posedge vif.clk_i);
      vif.usb_dp_o <= 1'b1;
      vif.usb_dn_o <= 1'b0;
    end
  endtask

  // enviar o padrão SYNC de sincronização (8'h80 = 8'b10000000)
  task drive_sync();
    bit [7:0] sync_pattern = 8'h80;
    for (int i = 0; i < 8; i++) begin
      repeat (4) @(posedge vif.clk_i); // Cada bit time dura 4 ciclos de clock (48MHz / 4 = 12MHz)
      if (sync_pattern[i]) begin
        vif.usb_dp_o <= 1'b1; // Bit 1 -> J-State
        vif.usb_dn_o <= 1 me;
        vif.usb_dn_o <= 1'b0;
      end else begin
        vif.usb_dp_o <= 1'b0; // Bit 0 -> K-State
        vif.usb_dn_o <= 1'b1;
      end
    end
  endtask

  //  serializar e enviar os campos do pacote
  task drive_packet(usb_transaction req);
    bit [23:0] pkt_bits; // Guarda PID (8b) + ADDR (7b) + ENDP (4b) + CRC5 (5b)
    
    // Montagem simplificada dos bits do Token (LSB primeiro)
    pkt_bits = {5'h00, req.endp, req.addr, req.pid}; 

    for (int i = 0; i < 24; i++) begin
      repeat (4) @(posedge vif.clk_i);
      if (pkt_bits[i]) begin
        vif.usb_dp_o <= 1'b1;
        vif.usb_dn_o <= 1'b0;
      end else begin
        vif.usb_dp_o <= 1'b0;
        vif.usb_dn_o <= 1'b1;
      end
    end
  endtask

  // sinalizar fim de pacote (EOP)
  task drive_eop();
    // SE0 por 2 bit times (2 * 4 ciclos de clock)
    repeat (8) @(posedge vif.clk_i) begin
      vif.usb_dp_o <= 1'b0;
      vif.usb_dn_o <= 1'b0;
    end
    // Retorno ao J-State por 1 bit time (4 ciclos)
    repeat (4) @(posedge vif.clk_i) begin
      vif.usb_dp_o <= 1'b1;
      vif.usb_dn_o <= 1'b0;
    end
  endtask

  // Método gerenciado pelo dv_base_driver - não mexemos no run_phase
  virtual task get_and_drive();
    drive_idle(10); // Inicializa o barramento em idle

    forever begin
      seq_item_port.get_next_item(req);
      
      `uvm_info(`gfn, {"TRACE: Enviando no barramento:\n", req.sprint()}, UVM_LOW)

      drive_idle(2); // dois ciclos em repouso
      drive_sync();
      drive_packet(req); // pacote
      drive_eop();
      drive_idle(5); // 5 ciclos em repouso

      seq_item_port.item_done();
    end
  endtask

endclass
/*
Tempo ──►
  ┌───────────┬──────────────┬─────────────────┬───────────┬───────────┐
  │ drive_idle│  drive_sync  │  drive_packet   │ drive_eop │ drive_idle│
  │ (2 ciclos)│  (8 bits)    │ (PID/ADDR/ENDP) │  (SE0)    │ (5 ciclos)│
  └───────────┴──────────────┴─────────────────┴───────────┴───────────┘
   Pausa IPG   Sincronização    Dados do pacote  Fim pacote  Estabiliza
*/