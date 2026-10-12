class usb20_monitor extends dv_base_monitor #(.ITEM_T(usb_transaction),.CFG_T (usb20_agent_cfg));
  `uvm_component_utils(usb20_monitor)
  virtual usb20_if vif;
  // Variáveis para desfazer o NRZI e o Bit Stuffing
  bit prev_dp;
  int ones_cnt;

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
  virtual protected task collect_trans();
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
    while (vif.cio_usb_dp_i == 1'b1 && vif.cio_usb_dn_i == 1'b0) begin
      @(posedge vif.clk_i);
    end
    prev_dp = 1'b1; 
    ones_cnt = 0;
  endtask
task get_next_bit(output bit out_bit);
    bit current_dp;
    
    // 1. Espera até o meio do "bit time" (2 ciclos de 48MHz) para ler com precisão
    repeat (2) @(posedge vif.clk_i);
    current_dp = vif.cio_usb_dp_i;
    
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
      prev_dp = vif.cio_usb_dp_i; // Atualiza a referência, pois o '0' falso inverteu o pino
      repeat (2) @(posedge vif.clk_i);
      ones_cnt = 0;
    end
  endtask
task collect_packet(ref usb_transaction trans);
    bit [7:0]  sync_byte;
    bit [7:0]  pid_byte;
    bit [15:0] token_payload;
    bit        raw_bit;

    // 1. Lê o byte de SYNC (Lê 8 bits limpos através do nosso operário)
    for (int i = 0; i < 8; i++) begin
      get_next_bit(raw_bit);
      sync_byte[i] = raw_bit; 
    end

    // 2. Lê o byte de PID
    for (int i = 0; i < 8; i++) begin
      get_next_bit(raw_bit);
      pid_byte[i] = raw_bit;
    end
    // Pega só os 4 primeiros bits do PID (os outros 4 são a cópia invertida de segurança)
    trans.pid = usb_transaction::usb_pid_e'(pid_byte[3:0]); 

    // 3. Lê o payload dependendo de quem é o PID!
    case (trans.pid)
      usb_transaction::PID_OUT, 
      usb_transaction::PID_IN, 
      usb_transaction::PID_SETUP: begin
        // É um Token! Sabemos que tem exatamente 16 bits depois do PID
        trans.kind = usb_transaction::USB_ITEM_NORMAL;
        for (int i = 0; i < 16; i++) begin
          get_next_bit(raw_bit);
          token_payload[i] = raw_bit;
        end
        trans.addr = token_payload[6:0];
        trans.endp = token_payload[10:7];
      end

      usb_transaction::PID_DATA0, 
      usb_transaction::PID_DATA1: begin
        // É um pacote de Dados! 
        trans.kind = usb_transaction::USB_ITEM_NORMAL;
        // (Nota: Em um monitor avançado, faríamos um 'while' lendo bytes 
        // até achar o EOP. Por enquanto, o esqueleto do DATA fica aqui).
      end

      usb_transaction::PID_ACK, 
      usb_transaction::PID_NAK, 
      usb_transaction::PID_STALL: begin
        // É Handshake! O pacote acaba no PID, não fazemos nada!
        trans.kind = usb_transaction::USB_ITEM_NORMAL;
      end
    endcase

    // 4. Aguarda a detecção do End of Packet real nos pinos (SE0: D+=0 e D-=0)
    while (!(vif.cio_usb_dp_i == 1'b0 && vif.cio_usb_dn_i == 1'b0)) begin
      @(posedge vif.clk_i);
    end
    
    // Espera a linha voltar para o estado de repouso (J-State) após o EOP
    while (vif.cio_usb_dp_i == 1'b0 && vif.cio_usb_dn_i == 1'b0) begin
      @(posedge vif.clk_i);
    end
  endtask
endclass