class usb20_monitor extends dv_base_monitor #(.ITEM_T(usb_transaction),.CFG_T (usb20_agent_cfg));
  `uvm_component_utils(usb20_monitor)
  virtual usb20_if vif;

  function new(string name = "usb20_monitor", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual usb20_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal(`gfn, "Nao foi possivel obter a virtual interface 'vif' do config_db no Monitor!")
    end
  endfunction

  // Task gerenciada pela classe pai dv_base_monitor
  virtual protected task collect_trans(uvm_phase phase);
    usb_transaction trans;

    forever begin
      // 1. Aguarda a linha sair do J-State (D+=1, D-=0) para detectar o início do pacote
      wait_for_start_of_packet();

      // 2. Instancia o objeto para guardar os dados da transação capturada
      trans = usb_transaction::type_id::create("trans");

      // 3. Coleta os bytes do barramento (PID, ADDR, ENDP)
      collect_packet(trans);

      // 4. Imprime no log e envia para o Scoreboard
      `uvm_info(`gfn, {"TRACE: Pacote capturado pelo Monitor:\n", trans.sprint()}, UVM_LOW)
      analysis_port.write(trans);
    end
  endtask

  // Task auxiliar: Espera a saída do estado de repouso (J-State)
  task wait_for_start_of_packet();
    @(posedge vif.clk_i);
    // Enquanto estiver em J-State (D+=1, D-=0), continua aguardando
    while (vif.usb_dp_i == 1'b1 && vif.usb_dn_i == 1'b0) begin
      @(posedge vif.clk_i);
    end
  endtask

  // Task auxiliar: Amostra os bits do barramento na taxa de 12 MHz (a cada 4 ciclos de 48 MHz)
  task collect_packet(ref usb_transaction trans);
    bit [7:0]  sync_byte;
    bit [7:0]  pid_byte;
    bit [15:0] token_payload;

    // 1. Amostra o byte de SYNC (8 bits, amostrando no meio de cada bit time: 2º ciclo do clock de 48MHz)
    for (int i = 0; i < 8; i++) begin
      repeat (2) @(posedge vif.clk_i);
      sync_byte[i] = vif.usb_dp_i; // Lê o bit no pino D+
      repeat (2) @(posedge vif.clk_i);
    end

    // 2. Amostra o byte de PID (8 bits)
    for (int i = 0; i < 8; i++) begin
      repeat (2) @(posedge vif.clk_i);
      pid_byte[i] = vif.usb_dp_i;
      repeat (2) @(posedge vif.clk_i);
    end
    trans.pid = pid_byte[3:0]; // Extrai os 4 bits reais do PID (os 4 MSB são invertidos para check)

    // 3. Amostra os campos de ADDR (7b) + ENDP (4b) + CRC5 (5b) = 16 bits
    for (int i = 0; i < 16; i++) begin
      repeat (2) @(posedge vif.clk_i);
      token_payload[i] = vif.usb_dp_i;
      repeat (2) @(posedge vif.clk_i);
    end
    trans.addr = token_payload[6:0];
    trans.endp = token_payload[10:7];

    // 4. Aguarda a detecção do End of Packet (SE0: D+=0 e D-=0)
    while (!(vif.usb_dp_i == 1'b0 && vif.usb_dn_i == 1'b0)) begin
      @(posedge vif.clk_i);
    end
  endtask

endclass