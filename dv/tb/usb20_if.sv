interface usb20_if (input logic clk_i, input logic rst_ni);

  // DUT inputs (driven by the driver / testbench)
  logic cio_usb_dp_i;
  logic cio_usb_dn_i;
  logic cio_sense_i;

  // DUT outputs (driven by the USB device)
  logic cio_usb_dp_o;
  logic cio_usb_dn_o;

  // Output enable signals (driven by the USB device)
  logic cio_usb_dp_en_o;
  logic cio_usb_dn_en_o;
  logic cio_usb_oe_o;

endinterface : usb20_if
