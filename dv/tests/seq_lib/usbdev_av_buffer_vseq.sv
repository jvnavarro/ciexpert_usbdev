class usbdev_av_buffer_vseq extends usbdev_base_vseq;
    `uvm_object_utils(usbdev_av_buffer_vseq)

    bit [4:0] expected_out_q[$];
    bit [4:0] expected_setup_q[$];
    usb_transaction last_rsp; // ultima resposta do DUT (preenchida quando get_rsp = 1)

    function new(string name = "usbdev_av_buffer_vseq");
        super.new(name);
    endfunction

    // Abastece um buffer livre para OUT
    task supply_out_buffer(bit [4:0] buf_id);
        csr_wr(.ptr(ral.avoutbuffer.buffer), .value(buf_id));
        expected_out_q.push_back(buf_id);
        `uvm_info(get_type_name(), $sformatf("Buffer %0d abastecido em avoutbuffer", buf_id), UVM_HIGH)
    endtask

    // Abastece um buffer livre para OUT
    task supply_setup_buffer(bit [4:0] buf_id);
        csr_wr(.ptr(ral.avsetupbuffer.buffer), .value(buf_id));
        expected_setup_q.push_back(buf_id);
        `uvm_info(get_type_name(), $sformatf("Buffer %0d abastecido em avsetupbuffer", buf_id), UVM_HIGH)
    endtask

    // Envia um token ou pacote de dados no barramento USB
    // get_rsp = 1: pede ao driver a resposta do DUT (handshake) e guarda em last_rsp
    task send_usb_pkt(usb_transaction::usb_pid_e pid_val, bit [3:0] ep_val, byte unsigned data_payload[] = '{}, bit get_rsp = 1'b0);
        usb_transaction trans;
        trans = usb_transaction::type_id::create("trans");
        start_item(trans, -1, p_sequencer.usb20_sequencer_h);
        if(!trans.randomize() with {
            kind    == usb_transaction::USB_ITEM_NORMAL;
            pid     == pid_val;    
            addr    == 7'h12;   // endereco atribuido no dut_init padrao
            endp    == ep_val;  
            dir_in  == 1'b0;    // sentido Host -> Device
            data.size() == data_payload.size();
            foreach (data_payload[i]) 
                data[i] == data_payload[i]; 
        })begin
            `uvm_fatal(get_type_name(), "Falha ao randomizar transacao USB.")
        end
        trans.want_rsp = get_rsp;
        finish_item(trans);
        if (get_rsp) begin
            uvm_sequence_item rsp_item;
            get_response(rsp_item, trans.get_transaction_id());
            `DV_CHECK_FATAL($cast(last_rsp, rsp_item))
        end
    endtask

    // Despeja o estado relevante do DUT para diagnostico
    task dump_dut_status(string tag);
        uvm_reg_data_t ctrl, stat, ep_en, setup_en, cnt, intr;
        csr_rd(.ptr(ral.usbctrl),           .value(ctrl));
        csr_rd(.ptr(ral.usbstat),           .value(stat));
        csr_rd(.ptr(ral.ep_out_enable[0]),  .value(ep_en));
        csr_rd(.ptr(ral.rxenable_setup[0]), .value(setup_en));
        csr_rd(.ptr(ral.count_out),         .value(cnt));
        csr_rd(.ptr(ral.intr_state),        .value(intr));
        `uvm_info(get_type_name(), $sformatf({"[DIAG %s] dev_addr=0x%0h enable=%0b link_state=%0d ",
            "av_setup_depth=%0d av_out_depth=%0d rx_depth=%0d rx_empty=%0b ",
            "ep_out_enable=0x%03h rxenable_setup=0x%03h count_out(ign_avsetup/drop)=0x%0h intr_state=0x%05h"},
            tag,
            get_field_val(ral.usbctrl.device_address, ctrl), get_field_val(ral.usbctrl.enable, ctrl),
            get_field_val(ral.usbstat.link_state, stat),
            get_field_val(ral.usbstat.av_setup_depth, stat), get_field_val(ral.usbstat.av_out_depth, stat),
            get_field_val(ral.usbstat.rx_depth, stat), get_field_val(ral.usbstat.rx_empty, stat),
            ep_en, setup_en, cnt, intr), UVM_LOW)
    endtask
    // Executa uma transacao completa (Token + DATA0 + ACK do DUT)
    task send_and_check_transaction(bit is_setup, bit [3:0] ep_val, byte unsigned payload[]);
        uvm_reg_data_t rxfifo_val;
        bit[4:0] exp_buf;


        // Garante que o endpoint espera DATA0 limpando seu toggle
        csr_wr(.ptr(ral.out_data_toggle), .value({4'h0, (12'h1 << ep_val), 16'h0000}));
        // 1. Envia token (SETUP e OUT);
        if (is_setup) begin
            send_usb_pkt(usb_transaction::PID_SETUP, ep_val);
            exp_buf = expected_setup_q.pop_front();
        end else begin
            send_usb_pkt(usb_transaction::PID_OUT, ep_val);
            exp_buf = expected_out_q.pop_front();
        end

        // 2. Envia pacote de dados com o payload (SETUP usa sempre DATA0) e captura o handshake
        send_usb_pkt(usb_transaction::PID_DATA0, ep_val, payload, 1'b1);

        // 3. O DUT deve responder com ACK; caso contrario o pacote foi descartado e a rxfifo
        //    ficara vazia (o erro de buffer ID seria apenas consequencia)
        if (last_rsp.no_response || last_rsp.pid != usb_transaction::PID_ACK) begin
            dump_dut_status($sformatf("%s EP%0d sem ACK", (is_setup ? "SETUP" : "OUT"), ep_val));
            `uvm_error(get_type_name(), $sformatf("DUT nao deu ACK no %s para EP %0d (no_response=%0b pid=%s)",
                (is_setup ? "SETUP" : "OUT"), ep_val, last_rsp.no_response, last_rsp.pid.name()))
            return;
        end

        // aguarda 20 ciclos de clk pra processar tudo
        cfg.clk_rst_vif.wait_clks(20);

        // 4. Confere que ha algo na rxfifo e le via barramento TL-UL
        csr_rd_check(.ptr(ral.usbstat.rx_empty), .compare_value(1'b0),
                     .err_msg("rxfifo vazia apesar do ACK do DUT"));
        csr_rd(.ptr(ral.rxfifo), .value(rxfifo_val));

        // 5. Validações dos campos da rxfifo conforme especificacao:
        `DV_CHECK_EQ(get_field_val(ral.rxfifo.buffer, rxfifo_val), exp_buf, $sformatf("Buffer ID incorreto na rxfifo para EP %0d", ep_val))
        `DV_CHECK_EQ(get_field_val(ral.rxfifo.size, rxfifo_val), payload.size(), $sformatf("Tamanho do pacote incorreto na rxfifo para EP %0d", ep_val))
        `DV_CHECK_EQ(get_field_val(ral.rxfifo.setup, rxfifo_val), is_setup, $sformatf("Flag setup incorreta na rxfifo para EP %0d", ep_val))
        `DV_CHECK_EQ(get_field_val(ral.rxfifo.ep, rxfifo_val), ep_val, $sformatf("Endpoint incorreto na rxfifo"))
        `uvm_info(get_type_name(), $sformatf("[OK] %s recebido com sucesso no EP %0d | Buffer: %0d | tamanho %0d bytes", (is_setup ? "SETUP" : "OUT"), ep_val, exp_buf, payload.size()), UVM_MEDIUM)

        // 6. Validacao dos dados gravados na SRAM interna do buffer
        if(payload.size() > 0) 
        begin
            check_packet_in_memory(exp_buf, payload);
        end

    endtask

    // Le a memoria SRAM interna do usbdev e compara byte a byte com o payload enviado
    task check_packet_in_memory(bit[4:0] buf_id, byte unsigned expected_payload[]);
        int num_bytes = expected_payload.size();
        // Quantidade de palavras de 32 bits a serem lidas (arredonda pra cima)
        int num_words = (num_bytes + 3) / 4;
        int base_word = buf_id * 16; // Cada buffer de 64B ocupa 16 palavras de 4B

        for(int w = 0; w < num_words; w++) 
        begin
            uvm_reg_data_t rd_val;
            // le palavra de 32 bits da memoria via TL-UL
            mem_rd(.ptr(ral.buffer), .offset(base_word + w), .data(rd_val));

            // compara 4 bytes dentro desta palavra de 32 bits (4B)
            for(int b = 0; b < 4; b++)
            begin
                int byte_idx = (w * 4) + b;
                if(byte_idx < num_bytes)
                begin
                    byte unsigned actual_byte = (rd_val >> (b * 8)) & 8'hFF;
                    byte unsigned exp_byte = expected_payload[byte_idx];
                    `DV_CHECK_EQ(actual_byte, exp_byte, $sformatf("Mismatch de dado no Buffer %0d, byte[%0d]!", buf_id, byte_idx))
                end
            end
        end

        `uvm_info(get_type_name(), $sformatf("[SRAM OK] Payload de %0d bytes validado com sucesso no Buffer %0d!", num_bytes, buf_id), UVM_HIGH)
    endtask


    virtual task body();
        bit [11:0] all_eps = 12'hFFF;
        usb_transaction reset_trans;
        `uvm_info(get_type_name(), ">>> [TESTE] Iniciando usbdev_av_buffer_vseq...", UVM_LOW)
        // 1. Configura a PHY para Single-Ended
        csr_wr(.ptr(ral.phy_config.use_diff_rcvr), .value(1'b0));
        // 2. Garante que o DUT esta conectado
        csr_wr(.ptr(ral.usbctrl.enable), .value(1'b1));

        // 3. Emite o bus reset do host para acordar o DUT e transicionar para LinkActiveNoSOF
        `uvm_info(get_type_name(), "Enviando Bus Reset para ativar o link...", UVM_LOW)
        reset_trans = usb_transaction::type_id::create("reset_trans");
        start_item(reset_trans, -1, p_sequencer.usb20_sequencer_h);
        if(!reset_trans.randomize() with {
            kind == usb_transaction::USB_ITEM_BUS_RESET;
            reset_us inside {[10:20]};
        }) `uvm_fatal(get_type_name(), "Falha ao randomizar bus reset")
        finish_item(reset_trans);

        // 4. Aguarda o link atingir o estado ativo
        csr_spinwait(.ptr(ral.usbstat.link_state), .exp_data(LinkActiveNoSOF));
        `uvm_info(get_type_name(), "DUT entrou em LinkActiveNoSOF", UVM_LOW)

        /* 5. O Bus Reset zera o device_address, precisa reconfigurar para 7'h12.
         ATENCAO: nao usar csr_wr no campo (ral.usbctrl.device_address)! Escrita em campo faz
         read-modify-write com o valor ESPELHADO dos demais campos, e o mirror de usbctrl.enable
         nao e atualizado neste env (sem predictor) -> a escrita mandava enable=0 e desconectava
         o DUT. Escreve o registrador inteiro com enable=1 explicitamente.
        */
        csr_wr(.ptr(ral.usbctrl),
               .value((uvm_reg_data_t'(7'h12) << ral.usbctrl.device_address.get_lsb_pos()) |
                      (uvm_reg_data_t'(1'b1)  << ral.usbctrl.enable.get_lsb_pos())),
               .predict(1'b1));
        csr_rd_check(.ptr(ral.usbctrl.enable), .compare_value(1'b1),
                     .err_msg("usbctrl.enable caiu apos configurar device_address"));
        csr_rd_check(.ptr(ral.usbctrl.device_address), .compare_value(7'h12),
                     .err_msg("device_address nao foi programado"));

        // 6. Habilita tods os endpoints para recepcao OUT e SETUP
        csr_wr(.ptr(ral.ep_out_enable[0]), .value(all_eps));
        csr_wr(.ptr(ral.rxenable_out), .value(all_eps));
        csr_wr(.ptr(ral.rxenable_setup[0]), .value(all_eps));

        // 7. Habilita interrupcoes globais pra monitorar eventos
        csr_wr(.ptr(ral.intr_enable), .value(32'hFFFF_FFFF));
        dump_dut_status("apos configuracao");

        // ETAPA 1: Teste dinamico OUT e SETUP com checagem de rxfifo
        `uvm_info(get_type_name(), ">>> Etapa 1: Enviando pacotes OUT e SETUP alternados...", UVM_LOW)

        for(int iter = 0; iter < 20; iter++) 
        begin
            bit is_setup = $urandom_range(0, 1);
            bit [3:0] rand_ep = $urandom_range(0, 11);
            bit [4:0] rand_buf = $urandom_range(0, 31);
            byte unsigned payload[];

            if(is_setup) begin
                // SETUP exige exatamente 8 bytes
                payload = new[8];
                foreach (payload[i]) begin
                    payload[i] = $urandom_range(0, 255);
                end
                supply_setup_buffer(rand_buf);
            end else begin
                // OUT pode ter tamanho variável de 0 a 64 bytes
                int pkt_size = $urandom_range(0, 64);
                payload = new[pkt_size];
                foreach (payload[i]) begin
                    payload[i] = $urandom_range(0, 255);
                end
                supply_out_buffer(rand_buf);
            end
            // Dispara a transacao e valida a rxfifo
            send_and_check_transaction(is_setup, rand_ep, payload);
        end
        // ETAPA 2: CORNER CASE - Exaustão de buffers OUT (checka se recebe NAK do DUT caso nao tenha espacos vazios na sram)
        `uvm_info(get_type_name(), ">>> Etapa 2: Testando envio OUT com avoutbuffer Vazia...", UVM_LOW)

        begin
            uvm_reg_data_t intr_val;
            byte unsigned test_payload[] = '{8'hAA, 8'hBB, 8'hCC, 8'hDD};

            // 1. Envia token OUT + DATA0 sem fornecer nenhum buffer previo
            send_usb_pkt(usb_transaction::PID_OUT, 4'd2);
            send_usb_pkt(usb_transaction::PID_DATA0, 4'd2, test_payload);

            // Da 20 ciclos de clock pro DUT responder NAK e sinalizar interrupcao
            cfg.clk_rst_vif.wait_clks(20);

            // 2. Valida se o bit de interrupcao av_out_empty foi disparado no hardware
            csr_rd(.ptr(ral.intr_state), .value(intr_val));
            `DV_CHECK_EQ(get_field_val(ral.intr_state.av_out_empty, intr_val), 1'b1, "Interrupcao av_out_empty nao disparou quando a FIFO estava vazia");

            // 3. Limpa a interrupcao av_out_empty (W1C)
            csr_wr(.ptr(ral.intr_state.av_out_empty), .value(1'b1));

            `uvm_info(get_type_name(), "[OK] DUT rejeitou OUT com NAK e disparou av_out_empty.", UVM_LOW)

            // 4. Recuperacao: fornece buffer OUT e reenvia o pacote
            supply_out_buffer(5'd15);
            send_and_check_transaction(1'b0, 4'd2, test_payload);
        end

        // ETAPA 3: CORNER CASE - Exaustão de buffers SETUP
        `uvm_info(get_type_name(), ">>> Etapa 3: Testando envio SETUP com avsetupbuffer Vazia...", UVM_LOW)

        begin
            uvm_reg_data_t intr_val;
            byte unsigned setup_payload[] = '{8'h80, 8'h06, 8'h00, 8'h01, 8'h00, 8'h00, 8'h12, 8'h00};

            // 1. Envia token SETUP + DATA0 sem fornecer nenhum buffer previo
            send_usb_pkt(usb_transaction::PID_SETUP, 4'd0);
            send_usb_pkt(usb_transaction::PID_DATA0, 4'd0, setup_payload);

            // Da 20 ciclos de clock pro DUT responder NAK e sinalizar interrupcao
            cfg.clk_rst_vif.wait_clks(20);

            // 2. Valida se o bit de interrupcao av_setup_empty foi disparado
            csr_rd(.ptr(ral.intr_state), .value(intr_val));
            `DV_CHECK_EQ(get_field_val(ral.intr_state.av_setup_empty, intr_val), 1'b1, "Interrupcao av_setup_empty nao disparou quando a FIFO estava vazia");

            // 3. Limpa a interrupcao av_setup_empty (W1C)
            csr_wr(.ptr(ral.intr_state.av_setup_empty), .value(1'b1));

            `uvm_info(get_type_name(), "[OK] DUT rejeitou SETUP com NAK e disparou av_setup_empty.", UVM_LOW)

            // 4. Recuperacao: fornece buffer SETUP e reenvia o pacote
            supply_setup_buffer(5'd20);
            send_and_check_transaction(1'b1, 4'd0, setup_payload);
        end

        `uvm_info(get_type_name(), "==========================================================", UVM_LOW)
        `uvm_info(get_type_name(), ">>> [SUCESSO] usbdev_av_buffer_vseq CONCLUIDO COM EXITO.", UVM_LOW)
        `uvm_info(get_type_name(), "==========================================================", UVM_LOW)
    endtask

endclass