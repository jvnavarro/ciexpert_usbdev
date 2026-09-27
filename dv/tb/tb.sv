module tb;
  // Importação das bibliotecas necessárias no topo do módulo
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import usb20_agent_pkg::*;

  // Sinais de clock e reset
  bit clk;
  bit rst_n;

  // Gerador de Clock (período de 20ns = 50MHz)
  always #10 clk = ~clk;

  // Bloco de Reset Inicial
  initial begin
    clk   = 1'b0;
    rst_n = 1'b0;
    #100 rst_n = 1'b1;
  end

  // Instância da Interface Física
  usb20_if usb20_if_inst (
    .clk_i (clk),
    .rst_ni(rst_n)
  );

  // Ponte UVM: Publica a interface física e inicia a simulação UVM
  initial begin
    uvm_config_db#(virtual usb20_if)::set(null, "*", "vif", usb20_if_inst);
    run_test();
  end

endmodule : tb
