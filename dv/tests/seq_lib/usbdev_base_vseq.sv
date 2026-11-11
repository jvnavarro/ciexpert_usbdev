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
    
    // 1+2. Habilita o usbdev (enable liga o pull-up e o protocol engine) e define o endereco 7'h12.
    // Escreve o registrador inteiro: escrita por campo usa o mirror dos outros campos, que nao e
    // atualizado neste env, e acabaria escrevendo enable=0.
    csr_wr(.ptr(ral.usbctrl),
           .value((uvm_reg_data_t'(7'h12) << ral.usbctrl.device_address.get_lsb_pos()) |
                  (uvm_reg_data_t'(1'b1)  << ral.usbctrl.enable.get_lsb_pos())),
           .predict(1'b1));

    // 3. Habilita a recepção no Endpoint 0 (setando o bit 0 do registrador)
    csr_wr(.ptr(ral.ep_out_enable[0]), .value(1'b1));
  endtask

  //  Finalização do DUT (classe base espera os acessos TL-UL pendentes terminarem)
  virtual task dut_shutdown();
    super.dut_shutdown();
  endtask

  //  Corpo vazio: as vseqs filhas implementam o roteiro do teste
  virtual task body();
  endtask

endclass
