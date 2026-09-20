interface usb20_if (
  input logic clk_i,
  input logic rst_ni
);

  // Modport para o Driver
  modport driver_mp (
    input clk_i,
    input rst_ni
  );

  // Modport para o Monitor
  modport monitor_mp (
    input clk_i,
    input rst_ni
  );

endinterface