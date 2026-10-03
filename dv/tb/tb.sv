module tb;
  // Importação das bibliotecas necessárias no topo do módulo
  import uvm_pkg::*;
  import usb20_agent_pkg::*;
  import dv_utils_pkg::*;  // /cip_infra/dv_utils/dv_utils_pkg.sv (byJ)
  import usbdev_env_pkg::*;
  import usbdev_test_pkg::*;

  `include "uvm_macros.svh"
  `include "dv_macros.svh"
  `include "cip_macros.svh"
  // Sinais de clock e reset
  wire usb_clk, usb_rst_n;
  wire aon_clk, aon_rst_n;
  wire [NUM_MAX_INTERRUPTS-1:0] interrupts; // NUM_MAX_INTERRUPTS ta em /cip_infra/dv_utils/dv_utils_pkg.sv (byJ)
  // Interfaces de Clock/Reset padrao do CIP (byJ)
  // Encontrado em /cip_infra/common_ifs/clk_rst_if (byJ)
  clk_rst_if usbdev_clk_rst_if (.clk(usb_clk), .rst_n(usb_rst_n));
  clk_rst_if aon_clk_rst_if (.clk(aon_clk), .rst_n(aon_rst_n));
  
  // Interface de Interrupcoes (byJ)
  // Encontrado em /cip_infra/common_ifs/pins_if (byJ)
  pins_if #(NUM_MAX_INTERRUPTS) intr_if(interrupts);

  // Interface do barramento TileLink (host -> DUT) (byJ)
  tl_if tl_if (.clk(usb_clk), .rst_n(usb_rst_n)); // tl_if está em /cip_infra/tl_agent/tl_if.sv (byJ)
  // Interface do agente usb 2.0 (byJ)
  usb20_if usb20_if_inst (
    .clk_i  (usb_clk),
    .rst_ni (usb_rst_n)
    );

  // Macro que conecta a interface de alertas que o RTL do OpenTitan exige (byJ)
  // definicao em /cip_infra/ (byJ)
  `DV_ALERT_IF_CONNECT(usb_clk, usb_rst_n)


  usbdev dut(
    // 1. Clocks e Resets
    // .instance_port (signal)
    .clk_i                            (usb_clk),
    .rst_ni                           (usb_rst_n),
    .clk_aon_i                        (aon_clk),
    .rst_aon_ni                       (aon_rst_n),

    // 2. Barramento de Controle TileLink (TL-UL)
    .tl_i                             (tl_if.h2d),
    .tl_o                             (tl_if.d2h),

    // 3. Alertas de segurança (gerados pela macro `DV_ALERT_IF_CONNECT)
    .alert_rx_i                       (alert_rx),
    .alert_tx_o                       (alert_tx),

    // 4. Sinais Físicos USB 2.0 (ligados na usb20_if_inst)
    .cio_usb_dp_i                     (usb20_if_inst.cio_usb_dp_i),
    .cio_usb_dn_i                     (usb20_if_inst.cio_usb_dn_i),
    .usb_rx_d_i                       (1'b0),
    .cio_usb_dp_o                     (usb20_if_inst.cio_usb_dp_o),
    .cio_usb_dp_en_o                  (usb20_if_inst.cio_usb_dp_en_o),
    .cio_usb_dn_o                     (usb20_if_inst.cio_usb_dn_o),
    .cio_usb_dn_en_o                  (usb20_if_inst.cio_usb_dn_en_o),
    .usb_tx_se0_o                     (),
    .usb_tx_d_o                       (),
    .cio_sense_i                      (usb20_if_inst.cio_sense_i),
    .usb_dp_pullup_o                  (),
    .usb_dn_pullup_o                  (),
    .usb_rx_enable_o                  (),
    .usb_tx_use_d_se0_o               (),

    // 5. Suspensao / AON (desativado pro smoke test)
    .usb_aon_suspend_req_o            (), 
    .usb_aon_wake_ack_o               (),
    .usb_aon_bus_reset_i              (1'b0),
    .usb_aon_sense_lost_i             (1'b0),
    .usb_aon_bus_not_idle_i           (1'b0),           
    .usb_aon_wake_detect_active_i     (1'b0),

    // 6. Referência de clock SOF
    .usb_ref_val_o                    (),
    .usb_ref_pulse_o                  (),

    // 7. Configuracao da SRAM interna
    .ram_cfg_i                        (prim_ram_1p_pkg::RAM_1P_CFG_REQ_DEFAULT),
    .ram_cfg_o                        (),

    
    .intr_pkt_received_o                  (interrupts[0]),
    .intr_pkt_sent_o                      (interrupts[1]),
    .intr_disconnected_o                  (interrupts[2]),
    .intr_host_lost_o                     (interrupts[3]),
    .intr_link_reset_o                    (interrupts[4]),
    .intr_link_suspend_o                  (interrupts[5]),
    .intr_link_resume_o                   (interrupts[6]),
    .intr_av_out_empty_o                  (interrupts[7]),
    .intr_rx_full_o                       (interrupts[8]),
    .intr_av_overflow_o                   (interrupts[9]),
    .intr_link_in_err_o                   (interrupts[10]),
    .intr_rx_crc_err_o                    (interrupts[11]),
    .intr_rx_pid_err_o                    (interrupts[12]),
    .intr_rx_bitstuff_err_o               (interrupts[13]),
    .intr_frame_o                         (interrupts[14]),
    .intr_powered_o                       (interrupts[15]),
    .intr_link_out_err_o                  (interrupts[16]),
    .intr_av_setup_empty_o                (interrupts[17])
  );



  // Ponte UVM: Publica a interface física e inicia a simulação UVM
  initial begin
    // 1. Ativa a geracao de clock nas interfaces clk_rst_if
    usbdev_clk_rst_if.set_active();
    aon_clk_rst_if.set_active();
    uvm_config_db#(virtual clk_rst_if)::set(null, "*.env", "clk_rst_vif", usbdev_clk_rst_if);
    uvm_config_db#(virtual clk_rst_if)::set(null, "*.env", "aon_clk_rst_vif", aon_clk_rst_if);
    uvm_config_db#(intr_vif)::set(null, "*.env", "intr_vif", intr_if);
    uvm_config_db#(virtual tl_if)::set(null, "*.env.m_tl_agent*", "vif", tl_if);
    
    uvm_config_db#(virtual usb20_if)::set(null, "*", "vif", usb20_if_inst);
    run_test();
  end

endmodule : tb
