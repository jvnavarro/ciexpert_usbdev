class usb20_monitor extends dv_base_monitor #(.ITEM_T(usb_transaction),.CFG_T (usb20_agent_cfg));
  `uvm_component_utils(usb20_monitor)
  virtual usb20_if vif;
  // Variáveis para desfazer o NRZI e o Bit Stuffing
  bit prev_dp;
  int ones_cnt;

  // Duração mínima de SE0 para ser bus reset: 2.5 us pela spec USB (48 ciclos = 1 us)
  localparam int unsigned CYCLES_PER_US   = 48;
  localparam int unsigned RESET_MIN_CYCLES = (5 * CYCLES_PER_US) / 2;

  function new(string name = "usb20_monitor", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual usb20_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal(`gfn, "Nao foi possivel obter a virtual interface 'vif' do config_db no Monitor!")
    end
  endfunction

  // Pinos do barramento. No tb as duas direções são fios separados: quando o DUT
  // transmite (cio_usb_dp_en_o = 1) a linha está nos pinos _o, senão nos _i (host).
  // Todas as leituras dos pinos passam por aqui.
  function bit dut_driving(); return (vif.cio_usb_dp_en_o == 1'b1); endfunction
  function bit line_dp();     return dut_driving() ? vif.cio_usb_dp_o : vif.cio_usb_dp_i; endfunction
  function bit line_dn();     return dut_driving() ? vif.cio_usb_dn_o : vif.cio_usb_dn_i; endfunction

  // Estados da linha
  function bit line_is_j();   return (line_dp() == 1'b1 && line_dn() == 1'b0); endfunction
  function bit line_is_k();   return (line_dp() == 1'b0 && line_dn() == 1'b1); endfunction
  function bit line_is_se0(); return (line_dp() == 1'b0 && line_dn() == 1'b0); endfunction

  // Task gerenciada pela classe pai dv_base_monitor
  virtual protected task collect_trans();
    usb_transaction trans;
    bit is_se0;
    bit valid;

    forever begin
      // 1. Aguarda a linha sair do J-State: K = início de pacote, SE0 = possível reset
      wait_for_start_of_packet(is_se0);

      // 2. Instancia o objeto para guardar os dados da transação capturada
      trans = usb_transaction::type_id::create("trans");
      trans.from_device = dut_driving(); // quem começou a transmitir

      // 3. Coleta o reset ou o pacote
      if (is_se0) collect_bus_reset(trans, valid);
      else        collect_packet(trans, valid);

      // 4. Só envia para o Scoreboard o que foi reconhecido como válido
      if (valid) begin
        `uvm_info(`gfn, {"TRACE: Item capturado pelo Monitor:\n", trans.sprint()}, UVM_LOW)
        analysis_port.write(trans);
      end
    end
  endtask

  // Task auxiliar: espera sair do J-State e diz se a linha foi para K ou SE0
  task wait_for_start_of_packet(output bit is_se0);
    @(posedge vif.clk_i);
    // Enquanto não for K nem SE0 (J ou SE1), continua aguardando
    while (!line_is_k() && !line_is_se0()) begin
      if (!line_is_j()) `uvm_warning(`gfn, "Linha em SE1 (D+=1, D-=1) enquanto aguardava inicio de pacote")
      @(posedge vif.clk_i);
    end
    is_se0 = line_is_se0();
    `uvm_info(`gfn, is_se0 ? "TRACE: SE0 detectado (possivel bus reset)"
                           : "TRACE: K detectado (inicio do pacote)", UVM_HIGH)

    // Inicializa as variáveis para desfazer o NRZI e o Bit Stuffing
    prev_dp  = 1'b1; // a linha estava em J (D+=1)
    ones_cnt = 0;
  endtask

  // Mede quanto tempo a linha fica em SE0. Só é bus reset se durar >= 2.5 us;
  // SE0 mais curto é ignorado.
  task collect_bus_reset(usb_transaction trans, output bit valid);
    int unsigned count_cycles = 0;

    // A linha já está em SE0 (wait_for_start_of_packet garantiu): conta até voltar
    while (line_is_se0()) begin
      count_cycles++;
      @(posedge vif.clk_i);
    end

    valid = (count_cycles >= RESET_MIN_CYCLES);
    if (valid) begin
      trans.kind     = usb_transaction::USB_ITEM_BUS_RESET;
      trans.reset_us = count_cycles / CYCLES_PER_US;
    end else begin
      `uvm_warning(`gfn, $sformatf("SE0 de %0d ciclos e curto demais para bus reset, ignorando",
                                   count_cycles))
    end
  endtask

  // Lê o próximo bit. eop = 1 se a linha estava em SE0 (fim de pacote): nesse caso
  // out_bit não vale nada e o NRZI/stuffing não é atualizado.
  task get_next_bit(output bit out_bit, output bit eop);
    bit current_dp;

    // 1. Espera até o meio do "bit time" (2 ciclos de 48MHz) para ler com precisão
    repeat (2) @(posedge vif.clk_i);
    eop = line_is_se0();
    if (eop) return;
    current_dp = line_dp();

    // 2. Desfaz o NRZI
    if (current_dp == prev_dp) begin
      out_bit = 1'b1; // Se a energia não mudou, o bit real era '1'
      ones_cnt++;
    end else begin
      out_bit = 1'b0; // Se a energia inverteu, o bit real era '0'
      ones_cnt = 0;
    end

    prev_dp = current_dp; // Guarda para o próximo ciclo

    // 3. Completa a segunda metade do "bit time" (mais 2 ciclos)
    repeat (2) @(posedge vif.clk_i);

    // 4. Desfaz o Bit Stuffing (Unstuffing)
    if (ones_cnt == 6) begin
      // O OpenTitan injetou um '0' falso aqui. Vamos "queimar" o tempo dele (4 ciclos)
      repeat (2) @(posedge vif.clk_i);
      prev_dp = line_dp(); // Atualiza a referência, pois o '0' falso inverteu o pino
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

    // 1. Lê o byte de SYNC
    for (int i = 0; i < 8; i++) begin
      get_next_bit(raw_bit, eop);
      sync_byte[i] = raw_bit;
    end
    // SYNC: os bits no fio são 0,0,0,0,0,0,0,1 e o bit i vai para sync_byte[i] -> 8'h80
    if (sync_byte != 8'h80) begin
      `uvm_error(`gfn, $sformatf("SYNC invalido: 0x%02h (esperado 0x80)", sync_byte))
      valid = 1'b0;
    end

    // 2. Lê o byte de PID
    for (int i = 0; i < 8; i++) begin
      get_next_bit(raw_bit, eop);
      pid_byte[i] = raw_bit;
    end
    // PID: os 4 bits de cima são o complemento dos 4 de baixo
    if (valid && pid_byte[7:4] != ~pid_byte[3:0]) begin
      `uvm_error(`gfn, $sformatf("PID invalido: 0x%02h (check bits nao batem)", pid_byte))
      valid = 1'b0;
    end

    // 3. Lê o payload dependendo do PID (só se SYNC e PID estão corretos)
    if (valid) begin
      // Pega só os 4 primeiros bits do PID (os outros 4 são a cópia invertida de segurança)
      trans.pid  = usb_transaction::usb_pid_e'(pid_byte[3:0]);
      trans.kind = usb_transaction::USB_ITEM_NORMAL;

      case (trans.pid)
        usb_transaction::PID_OUT,
        usb_transaction::PID_IN,
        usb_transaction::PID_SETUP,
        usb_transaction::PID_SOF: begin
          // Token ou SOF: exatamente 16 bits depois do PID (11 de campos + 5 de CRC5)
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
        end

        usb_transaction::PID_DATA0,
        usb_transaction::PID_DATA1: begin
          // É um pacote de Dados: lê bytes (LSB primeiro) até o EOP
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
            `uvm_error(`gfn, $sformatf("DATA terminou com %0d bits sobrando (fora de um byte)", bit_cnt))
            valid = 1'b0;
          end else if (bytes.size() < 2) begin
            `uvm_error(`gfn, $sformatf("DATA sem CRC16: so %0d bytes", bytes.size()))
            valid = 1'b0;
          end else begin
            // Os 2 últimos bytes são o CRC16: ficam fora do payload
            trans.data = new[bytes.size() - 2];
            foreach (trans.data[i]) trans.data[i] = bytes[i];
          end
        end

        usb_transaction::PID_ACK,
        usb_transaction::PID_NAK,
        usb_transaction::PID_STALL: begin
          // É Handshake! O pacote acaba no PID, não fazemos nada!
        end

        default: begin
          `uvm_error(`gfn, $sformatf("PID nao suportado pelo monitor: 0x%0h", pid_byte[3:0]))
          valid = 1'b0;
        end
      endcase
    end

    // 4. Aguarda o End of Packet (SE0), mesmo em pacote inválido, para não
    //    ressincronizar no meio do lixo
    while (!line_is_se0()) begin
      @(posedge vif.clk_i);
    end

    // Espera a linha voltar para o estado de repouso (J-State) após o EOP
    while (line_is_se0()) begin
      @(posedge vif.clk_i);
    end
  endtask
endclass
