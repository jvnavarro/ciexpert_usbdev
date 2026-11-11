/*
        "Verify that the 'phy_config.pinflip' bit swaps the use of the DP and DN signals on both the input and the output sides of the DUT.

            - Set up the DUT as normal but ensure that the 'pinflip' bit is instead set to true.

            - Ensure that the agent, including driver and monitor are aware of the pins being swapped.

            - Connect the device to the USB.

            - Verify that USB_DN is pulled high instead of USB_DP, and that USB_DP remains low.

            - Verify that OUT and and IN transactions complete normally and with the expected data being transferred."
        */

class usbdev_phy_config_pinflip_vseq extends usbdev_smoke_vseq;
  `uvm_object_utils(usbdev_phy_config_pinflip_vseq)

  uvm_hdl_data_t dp_pullup_val, dn_pullup_val;
  uvm_hdl_data_t dp_line_val,   dn_line_val;

  function new(string name = "usbdev_phy_config_pinflip_vseq");
    super.new(name);
  endfunction

  virtual task configure_and_connect();
    // 1. Disconnect the controller before configuring the pins
    csr_wr(.ptr(ral.usbctrl.enable), .value(1'b0));

    // 2. [Item 1 of the testplan] Configure the PHY: Single-Ended (use_diff_rcvr=0) + pinflip=1
    ral.phy_config.use_diff_rcvr.set(1'b0);
    ral.phy_config.pinflip.set(1'b1);
    csr_update(ral.phy_config);

    // 3. [Item 2 of the testplan] Tell the agent (driver and monitor) that the pins are inverted.
    cfg.m_usb20_agent_cfg.pinflip = 1'b1;

    // 4. Enables the endpoints and supplies the buffers of OUT and SETUP
    csr_wr(.ptr(ral.ep_out_enable[0]), .value(1'b1 << ep));
    csr_wr(.ptr(ral.ep_in_enable[0]), .value(1'b1 << ep));
    csr_wr(.ptr(ral.rxenable_setup[0]), .value(1'b1 << ep));
    csr_wr(.ptr(ral.rxenable_out), .value(1'b1 << ep));

    csr_wr(.ptr(ral.avsetupbuffer), .value(setup_buf));
    csr_wr(.ptr(ral.avoutbuffer), .value(out_buf));

    // 5. [Item 3 of the testplan] Connects the device to the USB
    csr_wr(.ptr(ral.usbctrl.enable), .value(1'b1));

    // 6. [Item 4 of the tesplan] Waits the pull-up go high (1) in usb_dn and verifies that usb_dp is in low (0)
    do begin
      cfg.clk_rst_vif.wait_clks(1);
      void'(uvm_hdl_read("tb.dut.usb_dn_pullup_o", dn_pullup_val));
    end while (dn_pullup_val[0] !== 1'b1);

    void'(uvm_hdl_read("tb.dut.usb_dp_pullup_o", dp_pullup_val));

    `DV_CHECK_EQ(dn_pullup_val[0], 1'b1, "Error: usb_dn_pullup_o should be in 1 with pinflip=1")
    `DV_CHECK_EQ(dp_pullup_val[0], 1'b0, "Erro: usb_dp_pullup_o should stay in 0 with pinflip=1")

    // Checks that the line in rest (inverted J) is in D+=0 and D-=1
    void'(uvm_hdl_read("tb.dut.cio_usb_dp_i", dp_line_val));
    void'(uvm_hdl_read("tb.dut.cio_usb_dn_i", dn_line_val));
    `DV_CHECK_EQ(dp_line_val[0], 1'b0,
                 "Error: cio_usb_dp_i should stay in 0 in the Idle state with pinflip=1")
    `DV_CHECK_EQ(dn_line_val[0], 1'b1,
                 "Error: cio_usb_dn_i should stay in 1 in the Idle state with pinflip=1")

    `uvm_info(get_type_name(), "Pull-up in DN confirmed! Sending Bus Reset...", UVM_LOW)

    // 7. Sends Bus Reset and waits for LinkActiveNoSOF
    `uvm_do_on_with(req, p_sequencer.usb20_sequencer_h,
                    {
            kind == usb_transaction::USB_ITEM_BUS_RESET;
        })

    csr_spinwait(.ptr(ral.usbstat.link_state), .exp_data(LinkActiveNoSOF));
  endtask
endclass
