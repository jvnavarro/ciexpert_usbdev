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
    bit        is_setup = $urandom_range(0, 1);  // 1: extra buffer goes to SETUP, 0: to OUT
    bit [31:0] mask     = 32'b1 << ral.intr_enable.av_overflow.get_lsb_pos();

    `uvm_info(get_type_name(), $sformatf("Extra buffer goes to the AV %s FIFO",
              is_setup ? "SETUP" : "OUT"), UVM_LOW)

    // 1. Fill both Available buffer FIFOs
    for (int i = 0; i < AV_OUT_DEPTH; i++)   csr_wr(.ptr(ral.avoutbuffer),   .value(i));
    for (int i = 0; i < AV_SETUP_DEPTH; i++) csr_wr(.ptr(ral.avsetupbuffer), .value(i));

    // The pin only rises if the interrupt is enabled; it must still be low before the overflow
    cfg_interrupts(mask);
    `DV_CHECK_EQ(cfg.intr_vif.sample() & mask, 0, "av_overflow pin is high before the overflow")

    // 2 and 3. Write one more buffer ID to the chosen (full) FIFO
    if (is_setup) csr_wr(.ptr(ral.avsetupbuffer), .value($urandom_range(0, 31)));
    else          csr_wr(.ptr(ral.avoutbuffer),   .value($urandom_range(0, 31)));

    // 4. The av_overflow pin must be high
    `DV_CHECK_EQ(cfg.intr_vif.sample() & mask, mask, "av_overflow pin did not go high")

    // Clear the interrupt (write-1-to-clear) so the pin goes low again
    csr_wr(.ptr(ral.intr_state), .value(mask));
  endtask

endclass
