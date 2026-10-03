// Sequencia virtual base do usbdev (padrao CIP OpenTitan).
// Todas as vseqs do usbdev (ex.: usbdev_smoke_vseq) herdam desta classe.
class usbdev_base_vseq extends cip_base_vseq #(
  .RAL_T               (usbdev_reg_block),
  .CFG_T               (usbdev_env_cfg),
  .COV_T               (usbdev_env_cov),
  .VIRTUAL_SEQUENCER_T (usbdev_virtual_sequencer)
);

  // 1. Registro na fábrica do UVM como OBJETO (sequencias nao sao componentes)
  `uvm_object_utils(usbdev_base_vseq)

  // 2. Construtor padrão de uvm_object (recebe apenas o nome)
  function new(string name = "usbdev_base_vseq");
    super.new(name);
  endfunction

  // 3. Inicialização do DUT (reset feito pela classe base)
  virtual task dut_init(string reset_kind = "HARD");
    super.dut_init(reset_kind);
  endtask

  // 4. Finalização do DUT (classe base espera os acessos TL-UL pendentes terminarem)
  virtual task dut_shutdown();
    super.dut_shutdown();
  endtask

  // 5. Corpo vazio: as vseqs filhas implementam o roteiro do teste
  virtual task body();
  endtask

endclass
