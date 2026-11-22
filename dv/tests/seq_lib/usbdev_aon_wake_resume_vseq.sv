class usbdev_aon_wake_resume_vseq extends usbdev_base_vseq;
  `uvm_object_utils(usbdev_aon_wake_resume_vseq)

  virtual usb20_if vif;
  usb_transaction  req;

  function new(string name = "usbdev_aon_wake_resume_vseq");
    super.new(name);
  endfunction

  virtual task pre_start();
    super.pre_start();
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

  virtual task body();
    // Step 1: Connect the USB device to the usb host model
    // wait until usbctrl.enable (set in super.dut_init) asserts the DP pull-up
    while (vif.usb_dp_pullup_en_o !== 1'b1) begin
      cfg.clk_rst_vif.wait_clks(1);
    end

    // Send a Bus Reset so the device enters the active state (LinkActiveNoSOF)
    `uvm_do_on_with(req, p_sequencer.usb20_sequencer_h,
                    {kind == usb_transaction::USB_ITEM_BUS_RESET;})

    csr_spinwait(.ptr(ral.usbstat.link_state), .exp_data(LinkActiveNoSOF));

    // Enable the link_suspend interrupt
    csr_wr(.ptr(ral.intr_enable.link_suspend), .value(1'b1));

    // Step 2: Send suspend Signaling to the USB device (> 3ms of Idle 'J' state)
    // ensure the bus is in Idle (J: D+ = 1, D- = 0) and wait > 3000 us (48 clks/us)
    vif.cio_usb_dp_i = 1'b1;
    vif.cio_usb_dn_i = 1'b0;
    cfg.clk_rst_vif.wait_clks(3200 * 48);
    // Step 3: Verify that the 'link_suspend' interrupt is raised
    csr_rd_check(.ptr(ral.usbstat.link_state), .compare_value(LinkSuspended));
    csr_rd_check(.ptr(ral.intr_state.link_suspend), .compare_value(1'b1));
    `DV_CHECK_EQ(cfg.intr_vif.pins[IntrLinkSuspend], 1'b1,
                 "intr_link_suspend_o pin should be asserted after 3ms of Idle (J)")
    // Clear the link_suspend interrupt
    csr_wr(.ptr(ral.intr_state.link_suspend), .value(1'b1));
    // Step 4: Enable the AON/Wake module, leaving it to maintain the pull up state
    csr_wr(.ptr(ral.wake_control.suspend_req), .value(1'b1));
    // Wait for the CDC handshake to complete and the AON module to report active
    csr_spinwait(.ptr(ral.wake_events.module_active), .exp_data(1'b1));

    // Verify that the DP pull-up is maintained and wake_req_aon_o is not asserted yet
    `DV_CHECK_EQ(vif.usb_dp_pullup_en_o, 1'b1,
                 "DP pull-up should remain enabled while AON/Wake module is active")
    `DV_CHECK_EQ(vif.wake_req_aon_o, 1'b0, "wake_req_aon_o should be 0 before Resume signaling")

    // Step 5: Initiate Resume Signaling, driving the USB into the 'K' state
    // K state in full speed is D+ = 0, D- = 1
    vif.cio_usb_dp_i = 1'b0;
    vif.cio_usb_dn_i = 1'b1;
    // Hold K state for ~100 us 
    // (20 AON clock cycles at 200 kHz = 100 * 48 USB clocks)
    // so filter_activity (6 AON clks) + u_wake_events_cdc latch
    // the event
    cfg.clk_rst_vif.wait_clks(100 * 48);
    // Step 6: Check that 'wake_req_aon_o' from 'usbdev_aon_wake' 
    // is asserted
    `DV_CHECK_EQ(vif.wake_req_aon_o, 1'b1,
                 "wake_req_aon_o should be asserted after Resume (K) signaling")
    // Step 7: Read from 'wake_events' CSR and check that 'bus_not_idle' is asserted
    csr_rd_check(.ptr(ral.wake_events.bus_not_idle), .compare_value(1'b1));
    csr_rd_check(.ptr(ral.wake_events.disconnected), .compare_value(1'b0));
    csr_rd_check(.ptr(ral.wake_events.bus_reset), .compare_value(1'b0));

    // Complete the USB Resume signaling:
    // 2 Low-Speed bit times of SE0 (64 clks) then Idle (J)
    vif.cio_usb_dp_i = 1'b0;
    vif.cio_usb_dn_i = 1'b0;
    cfg.clk_rst_vif.wait_clks(64);
    vif.cio_usb_dp_i = 1'b1;
    vif.cio_usb_dn_i = 1'b0;

    // Step 8: Disable the AON/Wake module and verify that the
    // USB device is still connected
    csr_wr(.ptr(ral.wake_control.wake_ack), .value(1'b1));
    // Wait for the AON/Wake module to deactivate across the CDC
    csr_spinwait(.ptr(ral.wake_events.module_active), .exp_data(1'b0));
    csr_spinwait(.ptr(ral.wake_events.bus_not_idle), .exp_data(1'b0));

    // Verify wake request and bus_not_idle event are cleared
    `DV_CHECK_EQ(vif.wake_req_aon_o, 1'b0, "wake_req_aon_o should be cleared after wake_ack")
    csr_rd_check(.ptr(ral.wake_events.bus_not_idle), .compare_value(1'b0));
    // Verify the USB device is still connected (DP pullup enabled and DP is high)
    `DV_CHECK_EQ(vif.usb_dp_pullup_en_o, 1'b1,
                 "DP pull-up should remain enabled after disabling AON/Wake module")
    `DV_CHECK_EQ(vif.cio_usb_dp_i, 1'b1, "DP should remain high (Idle J)")
  endtask
endclass : usbdev_aon_wake_resume_vseq
