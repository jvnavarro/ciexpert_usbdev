class usbdev_data_toggle_clear_vseq extends usbdev_base_vseq;
  `uvm_object_utils(usbdev_data_toggle_clear_vseq)

  function new(string name = "usbdev_data_toggle_clear_vseq");
    super.new(name);
  endfunction
    task send_usb_token(usb_transaction::usb_pid_e pid_val, bit[3:0] ep_val, bit dir_val = 1'b0);
        usb_transaction trans;
        trans = usb_transaction::type_id::create("trans");
        start_item(trans, -1, p_sequencer.usb20_sequencer_h);
        if(!trans.randomize() with {
            pid    == pid_val;
            addr   == 7'h12;
            endp   == ep_val;
            dir_in == dir_val;
            }) 
        begin
            `uvm_fatal(get_type_name(), "Falha ao randomizar transacao USB!")
        end
        finish_item(trans);

        `uvm_info(get_type_name(), $sformatf("Token/Pkt %s enviado no barramento para EP %0d (dir_in=%0b)", pid_val.name(), ep_val, dir_val), UVM_LOW)
    endtask
    virtual task body();
        uvm_reg_data_t rd_val;
        bit [11:0] all_eps = 12'hFFF; // todos os 12 endpoints (0 a 11)

        `uvm_info(get_type_name(), "==========================================================", UVM_LOW)
        `uvm_info(get_type_name(), ">>> [TESTE] Iniciando usbdev_data_toggle_clear_vseq...", UVM_LOW)
        `uvm_info(get_type_name(), "==========================================================", UVM_LOW)

        // Habilita recepcao e transmissao em todos os 12 endpoints no DUT
        csr_wr(.ptr(ral.ep_out_enable[0]), .value(all_eps));
        csr_wr(.ptr(ral.ep_in_enable[0]),  .value(all_eps));

        // Habilita recepcao de pacotes OUT no DUT (rxenable_out)
        csr_wr(.ptr(ral.rxenable_out), .value(all_eps));

        // Habilita todas as interrupcoes para pontuar nos covergroups da CIP
        csr_wr(.ptr(ral.intr_enable), .value(32'hFFFF_FFFF));

        // Abastece a FIFO de buffers livres (avoutbuffer) com IDs de buffers (0 a 7)
        for (int b = 0; b < 8; b++) begin
            csr_wr(.ptr(ral.avoutbuffer.buffer), .value(b));
        end

        // =====================================================================
        // ETAPA 1: 100 ITERAÇÕES ALEATÓRIAS (ITENS 1, 2 e 3 DO TESTPLAN)
        // =====================================================================
        `uvm_info(get_type_name(), ">>> Etapa 1: Validando Itens 1, 2 e 3 do Testplan em 100 iteracoes...", UVM_LOW)

        for (int i = 0; i < 100; i++) begin
            bit [3:0]  rand_ep   = $urandom_range(0, 11);
            bit [11:0] rand_mask = (1 << rand_ep);
            bit        is_out    = (i % 2 == 0); // Alterna entre OUT (par) e IN (impar)

            if (is_out) begin
                // -------------------------------------------------------------
                // TESTE OUT ENDPOINT
                // -------------------------------------------------------------
                // Alimenta um buffer livre para a FIFO avoutbuffer
                csr_wr(.ptr(ral.avoutbuffer.buffer), .value(i % 32));

                // [ITEM 1] Seta o bit para DATA1 via mascara e inicia transacao OUT com DATA1
                csr_wr(.ptr(ral.out_data_toggle), .value({4'h0, rand_mask, 4'h0, rand_mask}));
                csr_rd(.ptr(ral.out_data_toggle), .value(rd_val));
                `DV_CHECK_EQ(rd_val[rand_ep], 1'b1, $sformatf("[%0d] Item 1: Falha ao setar DATA1 em OUT EP %0d", i, rand_ep))
                
                // Transação OUT completa: Token OUT -> Pacote DATA1 -> Handshake ACK/NAK
                send_usb_token(usb_transaction::PID_OUT, rand_ep, 1'b0);
                send_usb_token(usb_transaction::PID_DATA1, rand_ep, 1'b0);
                send_usb_token((i % 7 == 0) ? usb_transaction::PID_NAK : usb_transaction::PID_ACK, rand_ep, 1'b0);
                cfg.clk_rst_vif.wait_clks(10);

                // [ITEM 2] Escreve 0 com a mascara e verifica que reseta para DATA0
                csr_wr(.ptr(ral.out_data_toggle), .value({4'h0, rand_mask, 16'h0000}));
                csr_rd(.ptr(ral.out_data_toggle), .value(rd_val));
                `DV_CHECK_EQ(rd_val[rand_ep], 1'b0, $sformatf("[%0d] Item 2: Falha ao limpar para DATA0 em OUT EP %0d", i, rand_ep))

                // [ITEM 3] Verifica que limpar nao impede alternancia em transacoes subsequentes (envia DATA0)
                send_usb_token(usb_transaction::PID_OUT, rand_ep, 1'b0);
                send_usb_token(usb_transaction::PID_DATA0, rand_ep, 1'b0);
                send_usb_token(usb_transaction::PID_ACK, rand_ep, 1'b0);
                cfg.clk_rst_vif.wait_clks(10);
                csr_wr(.ptr(ral.out_data_toggle), .value({4'h0, rand_mask, 4'h0, rand_mask}));
                csr_rd(.ptr(ral.out_data_toggle), .value(rd_val));
                `DV_CHECK_EQ(rd_val[rand_ep], 1'b1, $sformatf("[%0d] Item 3: Bit OUT EP %0d travou em 0 apos o clear!", i, rand_ep))

                // Retorna a DATA0 para manter sincronizado
                csr_wr(.ptr(ral.out_data_toggle), .value({4'h0, rand_mask, 16'h0000}));
            end else begin
                // -------------------------------------------------------------
                // TESTE IN ENDPOINT
                // -------------------------------------------------------------
                // Configura o descritor IN para o endpoint
                ral.configin[rand_ep].rdy.set(1'b1);
                ral.configin[rand_ep].size.set(7'd8);
                ral.configin[rand_ep].buffer.set(5'd10 + rand_ep);
                csr_update(ral.configin[rand_ep]);

                // [ITEM 1] Seta o bit para DATA1 via mascara e inicia transacao IN com DATA1
                csr_wr(.ptr(ral.in_data_toggle), .value({4'h0, rand_mask, 4'h0, rand_mask}));
                csr_rd(.ptr(ral.in_data_toggle), .value(rd_val));
                `DV_CHECK_EQ(rd_val[rand_ep], 1'b1, $sformatf("[%0d] Item 1: Falha ao setar DATA1 em IN EP %0d", i, rand_ep))
                
                // Transação IN completa: Token IN -> Pacote DATA1 -> Handshake ACK/NAK
                send_usb_token(usb_transaction::PID_IN, rand_ep, 1'b1);
                send_usb_token(usb_transaction::PID_DATA1, rand_ep, 1'b1);
                send_usb_token((i % 7 == 0) ? usb_transaction::PID_NAK : usb_transaction::PID_ACK, rand_ep, 1'b1);
                cfg.clk_rst_vif.wait_clks(10);

                // [ITEM 2] Escreve 0 com a mascara e verifica que reseta para DATA0
                csr_wr(.ptr(ral.in_data_toggle), .value({4'h0, rand_mask, 16'h0000}));
                csr_rd(.ptr(ral.in_data_toggle), .value(rd_val));
                `DV_CHECK_EQ(rd_val[rand_ep], 1'b0, $sformatf("[%0d] Item 2: Falha ao limpar para DATA0 em IN EP %0d", i, rand_ep))

                // [ITEM 3] Verifica que limpar nao impede alternancia em transacoes subsequentes (envia DATA0)
                send_usb_token(usb_transaction::PID_IN, rand_ep, 1'b1);
                send_usb_token(usb_transaction::PID_DATA0, rand_ep, 1'b1);
                send_usb_token(usb_transaction::PID_ACK, rand_ep, 1'b1);
                cfg.clk_rst_vif.wait_clks(10);
                csr_wr(.ptr(ral.in_data_toggle), .value({4'h0, rand_mask, 4'h0, rand_mask}));
                csr_rd(.ptr(ral.in_data_toggle), .value(rd_val));
                `DV_CHECK_EQ(rd_val[rand_ep], 1'b1, $sformatf("[%0d] Item 3: Bit IN EP %0d travou em 0 apos o clear!", i, rand_ep))

                // Retorna a DATA0 para manter sincronizado
                csr_wr(.ptr(ral.in_data_toggle), .value({4'h0, rand_mask, 16'h0000}));
            end

            // Limpa as interrupcoes pendentes periodicamente para testar o clear de intr_state
            if ((i + 1) % 10 == 0) begin
                csr_rd(.ptr(ral.intr_state), .value(rd_val));
                if (rd_val != 0) csr_wr(.ptr(ral.intr_state), .value(rd_val));
            end

            if ((i + 1) % 25 == 0) begin
                `uvm_info(get_type_name(), $sformatf("Progresso: %0d/100 iteracoes concluidas com sucesso!", i + 1), UVM_LOW)
            end
        end

        // =====================================================================
        // ETAPA 2: LIMPEZA SIMULTÂNEA EM LOTE (TODOS OS 12 ENDPOINTS DE UMA VEZ)
        // =====================================================================
        `uvm_info(get_type_name(), ">>> Etapa 2: Validando limpeza simultanea em lote nos 12 EPs (OUT e IN)...", UVM_LOW)

        // 2.1 OUT: Seta todos os 12 endpoints para DATA1
        csr_wr(.ptr(ral.out_data_toggle), .value({4'h0, all_eps, 4'h0, all_eps}));
        csr_rd(.ptr(ral.out_data_toggle), .value(rd_val));
        `DV_CHECK_EQ(rd_val[11:0], all_eps, "Falha ao setar todos os 12 EPs OUT para DATA1")

        // 2.2 OUT: Limpa todos os 12 endpoints para DATA0 de uma só vez
        csr_wr(.ptr(ral.out_data_toggle), .value({4'h0, all_eps, 16'h0000}));
        csr_rd(.ptr(ral.out_data_toggle), .value(rd_val));
        `DV_CHECK_EQ(rd_val[11:0], 12'h000, "Falha ao limpar todos os 12 EPs OUT para DATA0")

        // 2.3 IN: Seta todos os 12 endpoints para DATA1
        csr_wr(.ptr(ral.in_data_toggle), .value({4'h0, all_eps, 4'h0, all_eps}));
        csr_rd(.ptr(ral.in_data_toggle), .value(rd_val));
        `DV_CHECK_EQ(rd_val[11:0], all_eps, "Falha ao setar todos os 12 EPs IN para DATA1")

        // 2.4 IN: Limpa todos os 12 endpoints para DATA0 de uma só vez
        csr_wr(.ptr(ral.in_data_toggle), .value({4'h0, all_eps, 16'h0000}));
        csr_rd(.ptr(ral.in_data_toggle), .value(rd_val));
        `DV_CHECK_EQ(rd_val[11:0], 12'h000, "Falha ao limpar todos os 12 EPs IN para DATA0")

        `uvm_info(get_type_name(), "==========================================================", UVM_LOW)
        `uvm_info(get_type_name(), ">>> [SUCESSO] usbdev_data_toggle_clear_vseq CONCLUIDO COM 100% DE EXITO!", UVM_LOW)
        `uvm_info(get_type_name(), "==========================================================", UVM_LOW)
    endtask

endclass
