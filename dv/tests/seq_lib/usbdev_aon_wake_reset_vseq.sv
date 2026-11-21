class usbdev_aon_wake_reset_vseq extends usbdev_base_vseq;

  `uvm_object_utils(usbdev_aon_wake_reset_vseq)

  virtual usb20_if vif;
  usb_transaction  req;

  function new(string name = "usbdev_aon_wake_reset_vseq");
    super.new(name);
  endfunction

  // turns off monitor because we'll be driving the raw electrical signaling
  // on D+ / D- later in the test, rather than sending framed USB packets
  virtual task pre_start();
    super.pre_start();
    if (cfg != null && cfg.m_usb20_agent_cfg != null) begin
      cfg.m_usb20_agent_cfg.en_monitor = 1'b0;
    end
  endtask

  // this runs after the body(), it renables the monitor, for when multiple vseqs are chained together.
  virtual task post_start();
    if (cfg != null && cfg.m_usb20_agent_cfg != null) begin
      cfg.m_usb20_agent_cfg.en_monitor = 1'b1;
    end
    super.post_start();
  endtask

  // dv_base_vseq::pre_start() calls dut_init() before returning, so disabling
  // the monitor in dut_init() turns it off immediately after reset (and on any
  // mid-test re-initialization). Keeping it in pre_start() as well ensures the
  // monitor is still disabled if this sequence is ever run with do_dut_init = 0.
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
    // Step 1: connect the USB device to the USB host model
    while (vif.usb_dp_pullup_en_o !== 1'b1) begin
      cfg.clk_rst_vif.wait_clks(1);
    end

    `uvm_do_on_with(req, p_sequencer.usb20_sequencer_h,
                    {kind == usb_transaction::USB_ITEM_BUS_RESET;})

    csr_spinwait(.ptr(ral.usbstat.link_state), .exp_data(LinkActiveNoSOF));

    // Step 2: Enable the AON/Wake module, leaving it to maintain the pull up state
    //ensure the bus is in Idle (J: D+ = 1, D- = 0) before handing over to AON
    vif.cio_usb_dp_i = 1'b1;
    vif.cio_usb_dn_i = 1'b0;


    // Wait ~40 us (8 AON clock cycles) in Idle (J) so the 200 kHz AON filters
    // clear the initial Bus Reset before enabling the AON/Wake module
    cfg.clk_rst_vif.wait_clks(40 * 48);
    csr_wr(.ptr(ral.wake_control.suspend_req), .value(1'b1));
    // wait for the CDC handshake to complete and the AON module to report active
    csr_spinwait(.ptr(ral.wake_events.module_active), .exp_data(1'b1));

    // verify that the D+ pull-up is maintained and wake_req_aon_o is not asserted yet
    `DV_CHECK_EQ(vif.usb_dp_pullup_en_o, 1'b1,
                 "D+ pull-up should remain enabled while (AON/Wake module is active)")
    `DV_CHECK_EQ(vif.wake_req_aon_o, 1'b0, "wake_req_aon_o should be 0 before Bus Reset signaling")

    // Step 3: Perform a Bus Reset, driving SE0 state onto the USB for at least 10us
    // SE0 state is D+ = 0 and D- = 0
    vif.cio_usb_dp_i = 1'b0;
    vif.cio_usb_dn_i = 1'b0;

    // Hold SE0 for ~50us (10 AON clock cycles at 200kHz = 50  * 48 USB clocks)
    // so filter_bus_reset (2 sync + 3 filter AON clks) + u_wake_events_cdc latch the event
    cfg.clk_rst_vif.wait_clks(50 * 48);

    // Return the bus back to Idle (J: D+ = 1, D- = 0)
    vif.cio_usb_dp_i = 1'b1;
    vif.cio_usb_dn_i = 1'b0;

    // Step 4: Check that the 'wake_req_aon_o' signal from 'usbdev_aon_wake' becomes asserted
    `DV_CHECK_EQ(vif.wake_req_aon_o, 1'b1,
                 "wake_req_aon_o should be asserted after Bus Reset (SE0) signaling")
    // Step 5: Read from the 'wake events' CSR and check that 'bus_reset' is asserted
    csr_rd_check(.ptr(ral.wake_events.bus_reset), .compare_value(1'b1));
    csr_rd_check(.ptr(ral.wake_events.disconnected), .compare_value(1'b0));

    // Step 6: Disable the AON/Wake module and verify that the USB device is still connected
    csr_wr(.ptr(ral.wake_control.wake_ack), .value(1'b1));
    // Wait for the AON/Wake module to deactivate across the CDC
    csr_spinwait(.ptr(ral.wake_events.module_active), .exp_data(1'b0));
    csr_spinwait(.ptr(ral.wake_events.bus_reset), .exp_data(1'b0));

    // Verify wake request and bus_reset event are cleared
    `DV_CHECK_EQ(vif.wake_req_aon_o, 1'b0, "wake_req_aon_o should be cleared after wake_ack")
    csr_rd_check(.ptr(ral.wake_events.bus_reset), .compare_value(1'b0));

    // Verify the USB device is still connected (D+ pullup enabled and D+ is high)
    `DV_CHECK_EQ(vif.usb_dp_pullup_en_o, 1'b1,
                 "D+ pullup should remain enabled after disabling AON/Wake module")
    `DV_CHECK_EQ(vif.cio_usb_dp_i, 1'b1, "D+ should remain high (Idle J)")

  endtask
endclass : usbdev_aon_wake_reset_vseq
