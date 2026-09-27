interface usb20_if (input logic clk_i, input logic rst_ni);

  // Sinais de Entrada do DUT (injetados pelo Driver / Testbench)
  logic cio_usb_dp_i;
  logic cio_usb_dn_i;
  logic cio_sense_i;

  // Sinais de Saída do DUT (gerados pelo chip USB)
  logic cio_usb_dp_o;
  logic cio_usb_dn_o;

  // Sinais de Habilitação de Saída (gerados pelo chip USB)
  logic cio_usb_dp_en_o;
  logic cio_usb_dn_en_o;
  logic cio_usb_oe_o;

endinterface : usb20_if
