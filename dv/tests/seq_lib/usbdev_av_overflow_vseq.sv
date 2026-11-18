/*Verify that if a write was done to either the Available OUT Buffer FIFO or the Available SETUP Buffer FIFO when the FIFO was full the 'av_overflow' signal becomes high.

- Fill both of the Available buffer FIFOs.

- Choose at random whether to supply an additional OUT buffer or a SETUP buffer.

- Attempt to write a buffer ID to the chosen FIFO.

- Verify that this interrupt pin goes high indicating that the available fifo has reached the overflowing condition.
*/

class usbdev_av_overflow_vseq extends usbdev_base_vseq;
  `uvm_object_utils(usbdev_av_overflow_vseq)

  // FIFO depths (from rtl/usbdev/usbdev.sv: AVOutFifoDepth / AVSetupFifoDepth)
  localparam int AV_OUT_DEPTH   = 8;
  localparam int AV_SETUP_DEPTH = 4;

  function new(string name = "usbdev_av_overflow_vseq");
    super.new(name);
  endfunction

  virtual task body();
    bit is_setup;
    is_setup = $urandom_range(0, 1); // choose SETUP or OUT FIFO for the extra write
    `uvm_info(get_type_name(), $sformatf("Extra buffer goes to the AV %s FIFO",
              is_setup ? "SETUP" : "OUT"), UVM_LOW)

    fill_av_fifos();
    write_extra_buffer(is_setup);
    check_overflow(is_setup);
  endtask

  // Fill both AV FIFOs to their maximum depth and check that no overflow was flagged yet
  virtual task fill_av_fifos();
    uvm_reg_data_t usbstat_val, intr_val;

    for (int i = 0; i < AV_OUT_DEPTH; i++) begin
      csr_wr(.ptr(ral.avoutbuffer), .value(i));
    end
    for (int i = 0; i < AV_SETUP_DEPTH; i++) begin
      csr_wr(.ptr(ral.avsetupbuffer), .value(i));
    end

    // Both FIFOs must be exactly full
    csr_rd(.ptr(ral.usbstat), .value(usbstat_val));
    `DV_CHECK_EQ(get_field_val(ral.usbstat.av_out_depth, usbstat_val), AV_OUT_DEPTH,
                 "AV OUT FIFO did not fill up correctly")
    `DV_CHECK_EQ(get_field_val(ral.usbstat.av_setup_depth, usbstat_val), AV_SETUP_DEPTH,
                 "AV SETUP FIFO did not fill up correctly")

    // Negative check: filling up to the exact depth must NOT raise av_overflow
    csr_rd(.ptr(ral.intr_state), .value(intr_val));
    `DV_CHECK_EQ(get_field_val(ral.intr_state.av_overflow, intr_val), 1'b0,
                 "av_overflow was set before any write to a full FIFO")
  endtask

  // Write one more buffer ID into the chosen (already full) FIFO
  virtual task write_extra_buffer(bit is_setup);
    bit [4:0] id = $urandom_range(0, 31);

    if (is_setup) begin
      `uvm_info(get_type_name(), $sformatf("Testing AV SETUP FIFO overflow (extra buffer id %0d)", id), UVM_LOW)
      csr_wr(.ptr(ral.avsetupbuffer), .value(id));
    end else begin
      `uvm_info(get_type_name(), $sformatf("Testing AV OUT FIFO overflow (extra buffer id %0d)", id), UVM_LOW)
      csr_wr(.ptr(ral.avoutbuffer), .value(id));
    end
  endtask

  // The overflow interrupt must be set, the FIFO must stay full, and the bit must be clearable
  virtual task check_overflow(bit is_setup);
    uvm_reg_data_t intr_val, usbstat_val;

    csr_rd(.ptr(ral.intr_state), .value(intr_val));
    `DV_CHECK_EQ(get_field_val(ral.intr_state.av_overflow, intr_val), 1'b1,
                 "av_overflow was not raised after writing to a full FIFO")

    // The dropped write must not change the FIFO level
    csr_rd(.ptr(ral.usbstat), .value(usbstat_val));
    `DV_CHECK_EQ(get_field_val(ral.usbstat.av_out_depth, usbstat_val), AV_OUT_DEPTH,
                 "AV OUT FIFO level changed after the overflow")
    `DV_CHECK_EQ(get_field_val(ral.usbstat.av_setup_depth, usbstat_val), AV_SETUP_DEPTH,
                 "AV SETUP FIFO level changed after the overflow")

    // intr_state is write-1-to-clear: write the whole register with only av_overflow set
    csr_wr(.ptr(ral.intr_state),
           .value(uvm_reg_data_t'(1'b1) << ral.intr_state.av_overflow.get_lsb_pos()));
    csr_rd(.ptr(ral.intr_state), .value(intr_val));
    `DV_CHECK_EQ(get_field_val(ral.intr_state.av_overflow, intr_val), 1'b0,
                 "av_overflow did not clear after write-1-to-clear")
  endtask

endclass
