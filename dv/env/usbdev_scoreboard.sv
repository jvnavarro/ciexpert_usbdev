// 1. Declaração da macro fora da classe (para evitar conflitos de nomes no UVM)
`uvm_analysis_imp_decl(_usb20)

class usbdev_scoreboard extends cip_base_scoreboard #(
  .CFG_T          (usbdev_env_cfg),
  .RAL_T          (usbdev_reg_block),
  .COV_T          (usbdev_env_cov)
);
  `uvm_component_utils(usbdev_scoreboard)

  // 2. Declaração da porta de análise para receber dados do usb20_monitor
  uvm_analysis_imp_usb20 #(usb_transaction, usbdev_scoreboard) usb20_fifo;

  function new(string name = "usbdev_scoreboard", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // Instancia a porta de análise no build_phase
    usb20_fifo = new("usb20_fifo", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
  endfunction

  // 3. Função obrigatória chamada automaticamente quando o monitor faz analysis_port.write()
  virtual function void write_usb20(usb_transaction trans);
    `uvm_info(`gfn, $sformatf("SCOREBOARD: Pacote USB recebido | PID=0x%0h ADDR=0x%0h ENDP=0x%0h",
                              trans.pid, trans.addr, trans.endp), UVM_LOW)

    // Aqui os membros da equipe poderão implementar a validação dos pacotes USB
  endfunction

  // Acessos TL-UL: obrigatório sobrescrever na cip_base_scoreboard
  virtual task process_tl_access(tl_seq_item item, tl_channels_e channel, string ral_name);
    // Checagens dos CSRs/SRAM serão implementadas no futuro
  endtask

endclass