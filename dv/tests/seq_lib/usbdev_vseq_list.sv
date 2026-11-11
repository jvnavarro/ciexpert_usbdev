
// A usbdev_base_vseq precisa ser a primeira (todas as outras estendem dela).
`include "usbdev_base_vseq.sv"
`include "usbdev_smoke_vseq.sv"
`include "usbdev_in_trans_vseq.sv"
`include "usbdev_data_toggle_clear_vseq.sv"
`include "usbdev_av_buffer_vseq.sv"
`include "usbdev_phy_config_pinflip_vseq.sv"
`include "usbdev_phy_pins_sense_vseq.sv"
`include "usbdev_pkt_buffer_vseq.sv"