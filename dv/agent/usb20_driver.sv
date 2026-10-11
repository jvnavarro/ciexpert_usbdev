class usb20_driver extends dv_base_driver #(.ITEM_T(usb_transaction),.CFG_T (usb20_agent_cfg));
  `uvm_component_utils(usb20_driver)
  virtual usb20_if vif;
  bit nrzi_state;

  function new(string name = "usb20_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual usb20_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal(`gfn, "Nao foi possivel obter a virtual interface 'vif' do config_db!")
    end
  endfunction

  // Barramento em repouso (J-State) durante/após o reset
  virtual task on_enter_reset();
    vif.cio_usb_dp_i <= 1'b1;
    vif.cio_usb_dn_i <= 1'b0;
  endtask

  //  em repouso (J-State)
  task drive_idle(int cycles);
    for (int i = 0; i < cycles; i++) begin
      @(posedge vif.clk_i);
      vif.cio_usb_dp_i <= 1'b1;
      vif.cio_usb_dn_i <= 1'b0;
    end
  endtask

  // enviar o padrão SYNC de sincronização (8'h80 = 8'b10000000)
  task drive_sync();
    bit [7:0] sync_bits = 8'b10000000;
// O pacote USB começa no estado J
nrzi_state = 1'b1;
for(int i=0; i<8; i++) begin
	repeat (4) @(posedge vif.clk_i);
// nrzi: zero inverte o estado; um mantém. 
if (sync_bits[i] == 1'b0)
	nrzi_state = ~nrzi_state;
	vif.cio_usb_dp_i <= nrzi_state;
	vif.cio_usb_dn_i <= ~nrzi_state;


    end
  endtask

  //  serializar e enviar os campos do pacote
  task drive_packet(usb_transaction req);
    bit [23:0] pkt_bits; // Guarda PID (8b) + ADDR (7b) + ENDP (4b) + CRC5 (5b)
    bit[4:0] crc5;
    bit [10:0] token_bits;
    bit feedback;
    // CRC5 USB: polinomio x⁵ + x² +1
// calculado sobre ADDR (7 bits) e ENDP (4 bits)
token_bits = {req.endp, req.addr};
crc5 = 5'b11111;
for (int j = 0; j<11; j++) begin
feedback = token_bits[j] ^ crc5[0];
if(feedback)
	crc5 = crc5 ^ 5'b10100;
end
crc5 = ~crc5;
//montagem do token com CRC5 calculado 
pkt_bits = {crc5, req.endp, req.addr, ~req.pid, req.pid};
//Estado inicial NRZI: J-State (D+ = 1, D- = 0)
    for (int i = 0; i < 24; i++) begin
      repeat (4) @(posedge vif.clk_i);
// NRZI: bit 0 inverte o estado; bit 1 mantém
      if (pkt_bits[i] == 1'b0)
		nrzi_state = ~nrzi_state;
// Aplica o estado NRZI nas linhas USB
vif.cio_usb_dp_i <= nrzi_state;
vif.cio_usb_dn_i <= ~nrzi_state;
    end
  endtask

  // sinalizar fim de pacote (EOP)
  task drive_eop();
    // SE0 por 2 bit times (2 * 4 ciclos de clock)
    repeat (8) @(posedge vif.clk_i) begin
      vif.cio_usb_dp_i <= 1'b0;
      vif.cio_usb_dn_i <= 1'b0;
    end
    // Retorno ao J-State por 1 bit time (4 ciclos)
    repeat (4) @(posedge vif.clk_i) begin
      vif.cio_usb_dp_i <= 1'b1;
      vif.cio_usb_dn_i <= 1'b0;
    end
  endtask

  // Método gerenciado pelo dv_base_driver - não mexemos no run_phase
  virtual task get_and_drive();
	`uvm_info(get_type_name(), "DEBUG: get_and_drive iniciou", UVM_NONE)
    drive_idle(10); // Inicializa o barramento em idle
	`uvm_info(get_type_name(), "DEBUG: drive_idle terminou; aguardando transacao", UVM_NONE)
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
