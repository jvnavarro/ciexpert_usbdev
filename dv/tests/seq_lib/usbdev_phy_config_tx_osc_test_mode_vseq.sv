// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

/*
 * Verify the oscillator test mode when phy_config.tx_osc_test_mode is enabled.
 * - Set phy_config.tx_osc_test_mode.
 * - Verify that the device starts transmitting the J/K pattern continuously.
 */
class usbdev_phy_config_tx_osc_test_mode_vseq extends usbdev_base_vseq;
  `uvm_object_utils(usbdev_phy_config_tx_osc_test_mode_vseq)

  virtual usb20_if vif;
  usb_transaction  req;
  uvm_hdl_data_t   pullup_val;

  function new(string name = "usbdev_phy_config_tx_osc_test_mode_vseq");
    super.new(name);
  endfunction

  virtual task pre_start();
    super.pre_start();
    // Disable packet decoding in the monitor while driving raw J/K oscillation
    if (cfg != null && cfg.m_usb20_agent_cfg != null) begin
      cfg.m_usb20_agent_cfg.en_monitor = 1'b0;
    end
  endtask

  virtual task post_start();
    if (cfg != null && cfg.m_usb20_agent_cfg != null) begin
      cfg.m_usb20_agent_cfg.en_monitor = 1'b1;
    end
    super.post_start();
  endtask

  virtual task dut_init(string reset_kind = "HARD");
    super.dut_init(reset_kind);

    if (cfg != null && cfg.m_usb20_agent_cfg != null) begin
      cfg.m_usb20_agent_cfg.en_monitor = 1'b0;
    end

    if (!uvm_config_db#(virtual usb20_if)::get(null, "*", "vif", vif)) begin
      `uvm_fatal(get_type_name(), "Failed to get 'vif' (usb20_if) from uvm_config_db")
    end
  endtask

  // Sample DP/DN outputs and output enables on the 48 MHz DUT clock
  virtual task sample_signals(output bit dp, output bit dn, output bit dp_en, output bit dn_en);
    cfg.clk_rst_vif.wait_clks(1);
    dp    = vif.cio_usb_dp_o;
    dn    = vif.cio_usb_dn_o;
    dp_en = vif.cio_usb_dp_en_o;
    dn_en = vif.cio_usb_dn_en_o;
  endtask

  virtual task body();
    int unsigned num_phases     = 2_000;
    int unsigned total_duration = 0;
    int unsigned phase_duration = 0;
    int unsigned phase          = 0;
    bit prev_dp, prev_dn;
    bit dp, dn;
    bit dp_en, dn_en;

    // 1. Wait for device pull-up to be enabled, then send Bus Reset to exit LinkReset
    do begin
      cfg.clk_rst_vif.wait_clks(1);
      void'(uvm_hdl_read("tb.dut.usb_dp_pullup_o", pullup_val));
    end while (pullup_val[0] !== 1'b1);

    `uvm_do_on_with(req, p_sequencer.usb20_sequencer_h, {
      kind == usb_transaction::USB_ITEM_BUS_RESET;
    })

    csr_spinwait(.ptr(ral.usbstat.link_state), .exp_data(LinkActiveNoSOF));

    // 2. Enable TX oscillator test mode
    csr_wr(.ptr(ral.phy_config.tx_osc_test_mode), .value(1'b1));

    // Allow up to 1 byte time (32 cycles) + output register propagation to start transmitting
    cfg.clk_rst_vif.wait_clks(44);

    // 3. Collect initial sample and verify continuous J/K toggling at 12 Mbps (4 clks/phase)
    sample_signals(prev_dp, prev_dn, dp_en, dn_en);

    while (phase < num_phases) begin
      phase_duration++;
      sample_signals(dp, dn, dp_en, dn_en);

      `uvm_info(get_type_name(), $sformatf("Sampled DP=%0b DN=%0b DP_EN=%0b DN_EN=%0b",
                                           dp, dn, dp_en, dn_en), UVM_HIGH)

      `DV_CHECK_EQ(dp_en, 1'b1, "cio_usb_dp_en_o should remain active during tx_osc_test_mode")
      `DV_CHECK_EQ(dn_en, 1'b1, "cio_usb_dn_en_o should remain active during tx_osc_test_mode")
      `DV_CHECK_EQ(dp, !dn, "DP and DN should be opposites")

      if (dp == prev_dp) begin
        `DV_CHECK_LT(phase_duration, 8, "Phase too long; check osc frequency")
      end else begin
        `DV_CHECK(!phase || (phase_duration >= 3 && phase_duration <= 5),
                  $sformatf("Unexpected phase duration %0d", phase_duration))
        total_duration += phase_duration;
        phase_duration = 0;
        prev_dp = dp;
        phase++;
      end
    end

    // 4. Disable TX oscillator test mode and verify average phase duration and bus release
    csr_wr(.ptr(ral.phy_config.tx_osc_test_mode), .value(1'b0));

    `DV_CHECK(total_duration >= 4 * (num_phases - 1) && total_duration <= 4 * (num_phases + 1),
              "Average phase duration is unexpected; check osc frequency")

    cfg.clk_rst_vif.wait_clks(44);
    `DV_CHECK_EQ(vif.cio_usb_dp_en_o, 1'b0,
                 "cio_usb_dp_en_o should be released after disabling tx_osc_test_mode")
    `DV_CHECK_EQ(vif.cio_usb_dn_en_o, 1'b0,
                 "cio_usb_dn_en_o should be released after disabling tx_osc_test_mode")
  endtask

endclass

