// usbdev base virtual sequence (OpenTitan CIP style).
class usbdev_base_vseq extends cip_base_vseq #(
  .RAL_T               (usbdev_reg_block),
  .CFG_T               (usbdev_env_cfg),
  .COV_T               (usbdev_env_cov),
  .VIRTUAL_SEQUENCER_T (usbdev_virtual_sequencer)
);

  `uvm_object_utils(usbdev_base_vseq)

  function new(string name = "usbdev_base_vseq");
    super.new(name);
  endfunction

  virtual task dut_init(string reset_kind = "HARD");
    super.dut_init(reset_kind);
    
    // 1+2. Enable usbdev (enable turns on the pull-up and the protocol engine) and set address 7'h12.
    // Write the whole register: a per-field write uses the mirror of the other fields, which is
    // not updated in this env, and would end up writing enable=0.
    csr_wr(.ptr(ral.usbctrl),
           .value((uvm_reg_data_t'(7'h12) << ral.usbctrl.device_address.get_lsb_pos()) |
                  (uvm_reg_data_t'(1'b1)  << ral.usbctrl.enable.get_lsb_pos())),
           .predict(1'b1));

    // 3. Enable reception on endpoint 0 (set bit 0 of the register)
    csr_wr(.ptr(ral.ep_out_enable[0]), .value(1'b1));
  endtask

  // DUT shutdown (the base class waits for pending TL-UL accesses to finish)
  virtual task dut_shutdown();
    super.dut_shutdown();
  endtask

  // Empty body: child vseqs implement the test flow
  virtual task body();
  endtask

endclass
