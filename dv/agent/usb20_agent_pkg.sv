// Pacote do Agente USB 2.0
// Agrupa todas as classes do agente e define a ordem de inclusão para compilação
package usb20_agent_pkg;

  // 1. Importação de dependências globais
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  import dv_utils_pkg::*;
  import dv_base_reg_pkg::*;

  // 2. Inclusão dos arquivos do agente na ordem exata de dependência
  `include "usb_transaction.sv"
  `include "usb20_agent_cfg.sv"
  `include "usb20_sequencer.sv"
  `include "usb20_driver.sv"
  `include "usb20_monitor.sv"
  `include "usb20_agent.sv"

endpackage