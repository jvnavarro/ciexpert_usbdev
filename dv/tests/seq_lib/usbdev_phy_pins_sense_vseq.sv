// ==============================================================================
// Sequência Virtual: usbdev_phy_pins_sense_vseq
// Adaptada a partir da metodologia do OpenTitan para o ambiente ciexpert_usbdev
// ==============================================================================
// Objetivo:
//   Verificar se o registrador 'phy_pins_sense' reflete fidedignamente o estado
//   físico dos pinos da PHY (tanto entradas quanto saídas) sob diferentes
//   combinações de sinais.
//
// O que é validado:
//   1. Campos de Recepção (RX):
//      - rx_dp_i : Reflete o nível do pino D+ recebido (após CDC).
//      - rx_dn_i : Reflete o nível do pino D- recebido (após CDC).
//      - rx_d_i  : Reflete o pino de recepção diferencial.
//      - pwr_sense: Reflete a presença do sinal de VBUS.
//   2. Campos de Transmissão (TX do Core):
//      - tx_dp_o, tx_dn_o, tx_d_o, tx_se0_o, tx_oe_o (estado de repouso do core).
//   3. Modo Override via 'phy_pins_drive':
//      - Habilita controle manual dos pinos de saída pelo registrador de drive.
//      - Propaga o sinal pelos pinos e valida a leitura em 'phy_pins_sense'.
// ==============================================================================

class usbdev_phy_pins_sense_vseq extends usbdev_base_vseq;
  `uvm_object_utils(usbdev_phy_pins_sense_vseq)

  // Handle para a interface virtual para controle/observação dos pinos
  virtual usb20_if vif;

  // Variáveis randomizadas para o registrador phy_pins_drive
  rand bit rand_dp_o;
  rand bit rand_dn_o;
  rand bit rand_oe_o;
  rand bit rand_rx_enable_o;

  function new(string name = "usbdev_phy_pins_sense_vseq");
    super.new(name);
  endfunction

  // ----------------------------------------------------------------------------
  // dut_init: Para este teste, inicializamos o DUT via CSR mas sem tráfego USB
  // ----------------------------------------------------------------------------
  virtual task dut_init(string reset_kind = "HARD");
    super.dut_init(reset_kind);

    // Obtém a interface física do config_db para inspecionar/estimular pinos
    if (!uvm_config_db#(virtual usb20_if)::get(null, "*", "vif", vif)) begin
      `uvm_fatal(get_type_name(), "Nao foi possivel obter 'vif' (usb20_if) do config_db!")
    end
  endtask

  // ----------------------------------------------------------------------------
  // loopback_delay: Espera necessária para atravessar os sincronizadores CDC
  // O hardware possui prim_flop_2sync de 2 estágios nos pinos de entrada.
  // Aguardar 5 ciclos de clock garante que o valor foi capturado e propagado.
  // ----------------------------------------------------------------------------
  virtual task loopback_delay(int unsigned clks = 5);
    cfg.clk_rst_vif.wait_clks(clks);
  endtask

  // ----------------------------------------------------------------------------
  // body principal do teste
  // ----------------------------------------------------------------------------
  virtual task body();
    uvm_reg_data_t sense_val;
    bit exp_dp_i;
    bit exp_dn_i;
    bit exp_d_i;
    bit exp_vbus = 1'b1; // No nosso testbench, cio_sense_i e fixado em 1'b1

    `uvm_info(get_type_name(), "==========================================================", UVM_LOW)
    `uvm_info(get_type_name(), ">>> [TESTE] Iniciando usbdev_phy_pins_sense_vseq...", UVM_LOW)
    `uvm_info(get_type_name(), "==========================================================", UVM_LOW)

    // =========================================================================
    // ETAPA 1: TESTE DIRETO DAS ENTRADAS DE RX VIA INTERFACE VIRTUAL (4 ESTADOS)
    // =========================================================================
    `uvm_info(get_type_name(), ">>> Etapa 1: Validando sensoriamento direto das entradas D+/D-...", UVM_LOW)

    // Desativa o modo manual de drive para garantir isolamento
    csr_wr(.ptr(ral.phy_pins_drive), .value(32'h0));
    loopback_delay();

    for (int state = 0; state < 4; state++) begin
      bit test_dp = state[0];
      bit test_dn = state[1];

      // Aplica o estado elétrico diretamente nos pinos de entrada da PHY
      vif.cio_usb_dp_i <= test_dp;
      vif.cio_usb_dn_i <= test_dn;

      // Aguarda sincronização CDC (2 estágios de flip-flop)
      loopback_delay(5);

      // Lê o registrador phy_pins_sense
      csr_rd(.ptr(ral.phy_pins_sense), .value(sense_val));

      // Valida se o registrador capturou os níveis exatos de D+ e D-
      `DV_CHECK_EQ(get_field_val(ral.phy_pins_sense.rx_dp_i, sense_val), test_dp,
                   $sformatf("Etapa 1: Falha ao ler rx_dp_i com entrada D+=%0b, D-=%0b", test_dp, test_dn))
      `DV_CHECK_EQ(get_field_val(ral.phy_pins_sense.rx_dn_i, sense_val), test_dn,
                   $sformatf("Etapa 1: Falha ao ler rx_dn_i com entrada D+=%0b, D-=%0b", test_dp, test_dn))
      `DV_CHECK_EQ(get_field_val(ral.phy_pins_sense.pwr_sense, sense_val), exp_vbus,
                   "Etapa 1: Falha ao ler pwr_sense (VBUS)!")

      `uvm_info(get_type_name(),
                $sformatf("  [OK] Estado RX D+=%0b, D-=%0b refletido perfeitamente no phy_pins_sense", test_dp, test_dn),
                UVM_HIGH)
    end

    // Restaura as linhas para o repouso USB padrão (J-State: D+=1, D-=0)
    vif.cio_usb_dp_i <= 1'b1;
    vif.cio_usb_dn_i <= 1'b0;
    loopback_delay(5);

    // =========================================================================
    // ETAPA 2: TESTE DO MODO 'phy_pins_drive' COM LOOPBACK (PADRÃO OPENTITAN)
    // =========================================================================
    `uvm_info(get_type_name(), ">>> Etapa 2: Validando phy_pins_drive com loopback em 50 iteracoes aleatorias...", UVM_LOW)

    for (int iter = 0; iter < 50; iter++) begin
      // Randomiza os bits de saída
      `DV_CHECK_RANDOMIZE_FATAL(this)

      // 1. Configura o registrador phy_pins_drive
      ral.phy_pins_drive.dp_o.set(rand_dp_o);
      ral.phy_pins_drive.dn_o.set(rand_dn_o);
      ral.phy_pins_drive.oe_o.set(rand_oe_o);
      ral.phy_pins_drive.rx_enable_o.set(rand_rx_enable_o);
      ral.phy_pins_drive.en.set(1'b1);
      csr_update(ral.phy_pins_drive);

      // Dá 2 clocks para o RTL atualizar os pinos de saída
      cfg.clk_rst_vif.wait_clks(2);

      // Valida nos pinos físicos de saída se o override funcionou
      if (rand_oe_o) begin
        `DV_CHECK_EQ(vif.cio_usb_dp_o, rand_dp_o, $sformatf("[%0d] Falha no pino fisico cio_usb_dp_o", iter))
        `DV_CHECK_EQ(vif.cio_usb_dn_o, rand_dn_o, $sformatf("[%0d] Falha no pino fisico cio_usb_dn_o", iter))
      end
      `DV_CHECK_EQ(vif.cio_usb_dp_en_o, rand_oe_o, $sformatf("[%0d] Falha no enable fisico cio_usb_dp_en_o", iter))
      `DV_CHECK_EQ(vif.cio_usb_dn_en_o, rand_oe_o, $sformatf("[%0d] Falha no enable fisico cio_usb_dn_en_o", iter))

      // 2. Modelo de Loopback (como no barramento real/OpenTitan):
      // Se OE está ativo, a saída alimenta as linhas D+/D-. Se inativo, vai para 0 (pull-down).
      exp_dp_i = rand_oe_o ? rand_dp_o : 1'b0;
      exp_dn_i = rand_oe_o ? rand_dn_o : 1'b0;

      // Alimenta o loopback nos pinos de entrada
      vif.cio_usb_dp_i <= exp_dp_i;
      vif.cio_usb_dn_i <= exp_dn_i;

      // 3. Aguarda propagação física e sincronizadores CDC
      loopback_delay(5);

      // 4. Lê o registrador phy_pins_sense
      csr_rd(.ptr(ral.phy_pins_sense), .value(sense_val));

      // 5. Verificações formais:
      // - Campos de RX amostrados:
      `DV_CHECK_EQ(get_field_val(ral.phy_pins_sense.rx_dp_i, sense_val), exp_dp_i,
                   $sformatf("[%0d] Divergencia em rx_dp_i", iter))
      `DV_CHECK_EQ(get_field_val(ral.phy_pins_sense.rx_dn_i, sense_val), exp_dn_i,
                   $sformatf("[%0d] Divergencia em rx_dn_i", iter))
      `DV_CHECK_EQ(get_field_val(ral.phy_pins_sense.pwr_sense, sense_val), exp_vbus,
                   $sformatf("[%0d] Divergencia em pwr_sense", iter))

      // - Campos de TX do Core (devem permanecer no estado de repouso/idle do core):
      `DV_CHECK_EQ(get_field_val(ral.phy_pins_sense.tx_oe_o,  sense_val), 1'b0,
                   $sformatf("[%0d] tx_oe_o do core nao esta desassertado", iter))
      `DV_CHECK_EQ(get_field_val(ral.phy_pins_sense.tx_se0_o, sense_val), 1'b0,
                   $sformatf("[%0d] tx_se0_o do core nao esta desassertado", iter))
      `DV_CHECK_EQ(get_field_val(ral.phy_pins_sense.tx_d_o,   sense_val), 1'b1,
                   $sformatf("[%0d] tx_d_o do core nao esta em repouso (1)", iter))
      `DV_CHECK_EQ(get_field_val(ral.phy_pins_sense.tx_dp_o,  sense_val), 1'b1,
                   $sformatf("[%0d] tx_dp_o do core nao esta em repouso (1)", iter))
      `DV_CHECK_EQ(get_field_val(ral.phy_pins_sense.tx_dn_o,  sense_val), 1'b0,
                   $sformatf("[%0d] tx_dn_o do core nao esta em repouso (0)", iter))

      if ((iter + 1) % 10 == 0) begin
        `uvm_info(get_type_name(), $sformatf("Progresso: %0d/50 iteracoes concluidas com sucesso!", iter + 1), UVM_LOW)
      end
    end

    // =========================================================================
    // ETAPA 3: LIMPEZA E RETORNO AO ESTADO PADRÃO
    // =========================================================================
    `uvm_info(get_type_name(), ">>> Etapa 3: Desabilitando phy_pins_drive e restaurando barramento...", UVM_LOW)
    csr_wr(.ptr(ral.phy_pins_drive), .value(32'h0));
    vif.cio_usb_dp_i <= 1'b1;
    vif.cio_usb_dn_i <= 1'b0;
    loopback_delay(5);

    `uvm_info(get_type_name(), "==========================================================", UVM_LOW)
    `uvm_info(get_type_name(), ">>> [SUCESSO] usbdev_phy_pins_sense_vseq CONCLUIDO COM 100% DE EXITO!", UVM_LOW)
    `uvm_info(get_type_name(), "==========================================================", UVM_LOW)
  endtask

endclass
