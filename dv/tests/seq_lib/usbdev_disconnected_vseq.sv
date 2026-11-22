// USBDEV disconnection interrupt verification sequence.
//
// Test objective:
// Verify that removing VBUS causes the USB link to enter the disconnected
// state and asserts the disconnected interrupt.
//
// Verification scenario:
// - Enable and clear the disconnected interrupt.
// - Wait for the USB link to leave the disconnected state.
// - Verify that the interrupt is initially deasserted.
// - Remove VBUS through the USB interface.
// - Verify the disconnected link state and interrupt assertion.

class usbdev_disconnected_vseq extends usbdev_base_vseq;
  `uvm_object_utils(usbdev_disconnected_vseq)

  virtual usb20_if vif;

  function new(string name = "usbdev_disconnected_vseq");
    super.new(name);
  endfunction

  virtual task body();
    uvm_reg_data_t link_state;

    if (!uvm_config_db#(virtual usb20_if)::get(null, "*", "vif", vif)) begin
      `uvm_fatal(get_type_name(), "Failed to get USB interface")
    end

    `uvm_info(get_type_name(), "Starting disconnected interrupt test", UVM_LOW)

    // Ensure that VBUS is present before testing disconnection.
    vif.drive_vbus = 1'b1;

    // Enable the disconnected interrupt and clear any pending event.
    csr_wr(.ptr(ral.intr_enable.disconnected), .value(1'b1));
    csr_wr(.ptr(ral.intr_state.disconnected), .value(1'b1));

    // The link must first leave LinkDisconnected so that removing VBUS
    // generates a new transition into the disconnected state.
    for (int i = 0; i < 100; i++) begin
      csr_rd(.ptr(ral.usbstat.link_state), .value(link_state));
      if (link_state != LinkDisconnected) break;
      cfg.clk_rst_vif.wait_clks(10);
    end

    `DV_CHECK_NE(link_state, LinkDisconnected,
                 "USB link did not leave the disconnected state")

    csr_rd_check(.ptr(ral.intr_state.disconnected), .compare_value(1'b0));

    // Simulate physical disconnection by removing VBUS.
    vif.drive_vbus = 1'b0;

    // Allow the VBUS indication to propagate through the clock domains.
    csr_spinwait(.ptr(ral.usbstat.link_state), .exp_data(LinkDisconnected));
    csr_spinwait(.ptr(ral.intr_state.disconnected), .exp_data(1'b1));

    `uvm_info(get_type_name(),
              "PASS: USB disconnection detected and interrupt asserted",
              UVM_LOW)

    // Restore VBUS for subsequent tests.
    vif.drive_vbus = 1'b1;
  endtask

endclass : usbdev_disconnected_vseq
