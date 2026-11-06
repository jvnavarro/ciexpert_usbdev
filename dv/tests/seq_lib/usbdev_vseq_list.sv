
// A usbdev_base_vseq precisa ser a primeira (todas as outras estendem dela).
`include "usbdev_base_vseq.sv"
`include "usbdev_smoke_vseq.sv"
`include "usbdev_data_toggle_clear_vseq.sv"
`include "usbdev_pkt_buffer_vseq.sv"
