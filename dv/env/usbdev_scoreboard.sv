// 1. Declaração da macro fora da classe (para evitar conflitos de nomes no UVM)
`uvm_analysis_imp_decl(_usb20)

class usbdev_scoreboard extends cip_base_scoreboard #(
  .CFG_T          (usbdev_env_cfg),
  .RAL_T          (usbdev_reg_block),
  .COV_T          (usbdev_env_cov)
);
  `uvm_component_utils(usbdev_scoreboard)
// Indica se a Etapa 10 foi validada com sucesso
bit etapa10_validada = 0;
// Habilita a verificacao especifica da etapa 10
bit verificar_etapa10 = 0;

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
// Consultar se a verificacao da Etapa 10 foi habilitada
void'(uvm_config_db#(bit)::get(
    this,
    "",
    "verificar_etapa10",
    verificar_etapa10
));
    `uvm_info(`gfn, $sformatf("SCOREBOARD: Item USB recebido | %s | %s | PID=0x%0h ADDR=0x%0h ENDP=0x%0h DATA=%0d bytes",
                              trans.kind.name(), trans.from_device ? "DUT->host" : "host->DUT",
                              trans.pid, trans.addr, trans.endp, trans.data.size()), UVM_LOW)

    // Aqui os membros da equipe poderão implementar a validação dos pacotes USB
    // Etapa 10: verificar os 8 bytes transmitidos pelo DUT
if (
verificar_etapa10 &&
trans.from_device &&
 trans.kind == usb_transaction::USB_ITEM_NORMAL &&
 trans.pid == usb_transaction::PID_DATA0) begin

  if (trans.data.size() != 8) begin
    `uvm_error(get_type_name(),
      $sformatf("ETAPA 10: esperado 8 bytes, recebido %0d",
                trans.data.size()))
  end
  else begin
  bit dados_corretos = 1;
    foreach (trans.data[i]) begin
      if (trans.data[i] !== (i + 1)) begin
      dados_corretos = 0;
        `uvm_error(get_type_name(),
          $sformatf("ETAPA 10: byte %0d incorreto. Esperado=0x%02h Recebido=0x%02h",
                    i, i + 1, trans.data[i]))
      end
    end
      if (dados_corretos) begin
	etapa10_validada = 1;
    `uvm_info(get_type_name(),
      "ETAPA 10: pacote DATA0 de 8 bytes verificado",
      UVM_LOW)
	end
  end
end
  endfunction
// Verificar se a Etapa 10 foi concluída
virtual function void check_phase(uvm_phase phase);
  super.check_phase(phase);

  if (verificar_etapa10 && !etapa10_validada) begin
    `uvm_error(get_type_name(),
      "ETAPA 10: nenhum pacote DATA0 valido de 8 bytes foi recebido")
  end
endfunction

  // Acessos TL-UL: obrigatório sobrescrever na cip_base_scoreboard
  virtual task process_tl_access(tl_seq_item item, tl_channels_e channel, string ral_name);
    // Checagens dos CSRs/SRAM serão implementadas no futuro
  endtask

endclass
