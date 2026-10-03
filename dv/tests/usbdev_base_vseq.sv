// Sequencia virtual base do usbdev (padrao CIP OpenTitan).
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
  endtask

  //  Finalização do DUT (classe base espera os acessos TL-UL pendentes terminarem)
  virtual task dut_shutdown();
    super.dut_shutdown();
  endtask

  //  Corpo vazio: as vseqs filhas implementam o roteiro do teste
  virtual task body();
  endtask

endclass
