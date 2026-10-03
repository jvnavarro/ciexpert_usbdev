// Testbench top do usbdev (padrao CIP OpenTitan)
module tb;
  // Importação das bibliotecas necessárias no topo do módulo
  import uvm_pkg::*;
  import dv_utils_pkg::*;
  import usbdev_env_pkg::*;
  import usbdev_test_pkg::*;
  import usb20_agent_pkg::*;

  `include "uvm_macros.svh"
  `include "dv_macros.svh"
  `include "cip_macros.svh"

  // Sinais de clock e reset (gerados pelo clk_rst_if, 48 MHz definido no env_cfg)
  wire clk, rst_n;
  // Clock always-on (~200 kHz)
  bit  clk_aon;
  wire [NUM_MAX_INTERRUPTS-1:0] interrupts;

  always #2500ns clk_aon = ~clk_aon;

  // Interfaces CIP
  clk_rst_if clk_rst_if (.clk(clk), .rst_n(rst_n));
  pins_if #(NUM_MAX_INTERRUPTS) intr_if (interrupts);
  tl_if tl_if (.clk(clk), .rst_n(rst_n));
  `DV_ALERT_IF_CONNECT()

  // Interface física USB 2.0 (agente do projeto)
  usb20_if usb20_if_inst (
    .clk_i (clk),
    .rst_ni(rst_n)
  );

  // Barramento USB em idle (J state: D+ alto, D- baixo) e VBUS presente
  assign usb20_if_inst.cio_usb_dp_i = 1'b1;
  assign usb20_if_inst.cio_usb_dn_i = 1'b0;
  assign usb20_if_inst.cio_sense_i  = 1'b1;

  // DUT
  usbdev dut (
    .clk_i                        (clk),
    .rst_ni                       (rst_n),
    .clk_aon_i                    (clk_aon),
    .rst_aon_ni                   (rst_n),

    .tl_i                         (tl_if.h2d),
    .tl_o                         (tl_if.d2h),

    .alert_rx_i                   (alert_rx),
    .alert_tx_o                   (alert_tx),

    .cio_usb_dp_i                 (usb20_if_inst.cio_usb_dp_i),
    .cio_usb_dn_i                 (usb20_if_inst.cio_usb_dn_i),
    .usb_rx_d_i                   (1'b1),

    .cio_usb_dp_o                 (usb20_if_inst.cio_usb_dp_o),
    .cio_usb_dp_en_o              (usb20_if_inst.cio_usb_dp_en_o),
    .cio_usb_dn_o                 (usb20_if_inst.cio_usb_dn_o),
    .cio_usb_dn_en_o              (usb20_if_inst.cio_usb_dn_en_o),
    .usb_tx_se0_o                 (),
    .usb_tx_d_o                   (),

    .cio_sense_i                  (usb20_if_inst.cio_sense_i),
    .usb_dp_pullup_o              (),
    .usb_dn_pullup_o              (),
    .usb_rx_enable_o              (),
    .usb_tx_use_d_se0_o           (),

    .usb_aon_suspend_req_o        (),
    .usb_aon_wake_ack_o           (),

    .usb_aon_bus_reset_i          (1'b0),
    .usb_aon_sense_lost_i         (1'b0),
    .usb_aon_bus_not_idle_i       (1'b0),
    .usb_aon_wake_detect_active_i (1'b0),

    .usb_ref_val_o                (),
    .usb_ref_pulse_o              (),

    .ram_cfg_i                    (prim_ram_1p_pkg::RAM_1P_CFG_REQ_DEFAULT),
    .ram_cfg_o                    (),

    .intr_pkt_received_o          (interrupts[0]),
    .intr_pkt_sent_o              (interrupts[1]),
    .intr_disconnected_o          (interrupts[2]),
    .intr_host_lost_o             (interrupts[3]),
    .intr_link_reset_o            (interrupts[4]),
    .intr_link_suspend_o          (interrupts[5]),
    .intr_link_resume_o           (interrupts[6]),
    .intr_av_out_empty_o          (interrupts[7]),
    .intr_rx_full_o               (interrupts[8]),
    .intr_av_overflow_o           (interrupts[9]),
    .intr_link_in_err_o           (interrupts[10]),
    .intr_rx_crc_err_o            (interrupts[11]),
    .intr_rx_pid_err_o            (interrupts[12]),
    .intr_rx_bitstuff_err_o       (interrupts[13]),
    .intr_frame_o                 (interrupts[14]),
    .intr_powered_o               (interrupts[15]),
    .intr_link_out_err_o          (interrupts[16]),
    .intr_av_setup_empty_o        (interrupts[17])
  );

  assign interrupts[NUM_MAX_INTERRUPTS-1:18] = '0;

  // Ponte UVM: publica as interfaces e inicia a simulação
  initial begin
    clk_rst_if.set_active();
    uvm_config_db#(virtual clk_rst_if)::set(null, "*.env", "clk_rst_vif", clk_rst_if);
    uvm_config_db#(intr_vif)::set(null, "*.env", "intr_vif", intr_if);
    uvm_config_db#(virtual tl_if)::set(null, "*.env.m_tl_agent_usbdev_reg_block*", "vif", tl_if);
    uvm_config_db#(virtual usb20_if)::set(null, "*", "vif", usb20_if_inst);
    $timeformat(-12, 0, " ps", 12);
    run_test();
  end

`ifdef DUMP_FSDB
  initial begin
    $fsdbDumpfile("sim_waves.fsdb");
    $fsdbDumpvars(0, tb);
  end
`endif

endmodule : tb
