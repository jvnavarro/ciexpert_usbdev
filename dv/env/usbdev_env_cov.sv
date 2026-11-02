// Herda de cip_base_env_cov, que traz os recursos base de cobertura do OpenTitan
class usbdev_env_cov extends cip_base_env_cov #(
  .CFG_T(usbdev_env_cfg)
);

  `uvm_component_utils(usbdev_env_cov)

  // 1. PIDs enviados para o DUT (Host -> DUT)
  covergroup pids_to_dut_cg with function sample(usb_transaction::usb_pid_e pid);
    cp_pid: coverpoint pid {
      bins sof   = {usb_transaction::PID_SOF};
      bins setup = {usb_transaction::PID_SETUP};
      bins out   = {usb_transaction::PID_OUT};
      bins in    = {usb_transaction::PID_IN};
      bins data0 = {usb_transaction::PID_DATA0};
      bins data1 = {usb_transaction::PID_DATA1};
      bins ack   = {usb_transaction::PID_ACK};
      bins nak   = {usb_transaction::PID_NAK};
      bins pre   = {usb_transaction::PID_PRE};
    }
  endgroup

  // 2. PIDs enviados pelo DUT em resposta (DUT -> Host)
  covergroup pids_from_dut_cg with function sample(usb_transaction::usb_pid_e pid);
    cp_pid: coverpoint pid {
      bins data0 = {usb_transaction::PID_DATA0};
      bins data1 = {usb_transaction::PID_DATA1};
      bins ack   = {usb_transaction::PID_ACK};
      bins nak   = {usb_transaction::PID_NAK};
      bins stall = {usb_transaction::PID_STALL};
    }
  endgroup

  // 3. Contadores de frame recebidos em pacotes SOF
  covergroup framenum_rx_cg with function sample(bit [10:0] frame);
    cp_frame: coverpoint frame {
      bins zero               = {0};
      bins one                = {1};
      bins range_2_to_15      = {[2:15]};
      bins range_16_to_127    = {[16:127]};
      bins range_128_to_1023  = {[128:1023]};
      bins range_1024_to_2046 = {[1024:2046]};
      bins max                = {2047};
    }
  endgroup

  // 4. Verificação de integridade CRC16 de dados
  covergroup crc16_cg with function sample(bit dir_in, bit [15:0] crc16);
    cp_crc16: coverpoint crc16 {
      bins all_ones = {65535};
      bins six_ones = {63, 126, 252, 504, 1008, 2016, 4032, 8064, 16128, 32256};
    }
    cp_dir: coverpoint dir_in;
    cr_crc16_X_dir: cross cp_crc16, cp_dir;
  endgroup

  // 5. Verificação de integridade CRC5 de tokens
  covergroup crc5_cg with function sample(bit dir_in, bit [4:0] crc5);
    cp_crc5: coverpoint crc5 {
      bins trailing_zero = {15};
      bins leading_zero  = {30};
      bins all_ones      = {31};
    }
    cp_dir: coverpoint dir_in;
    cr_crc5_X_dir: cross cp_crc5, cp_dir;
  endgroup

  // 6. Endereço do dispositivo e Endpoints
  covergroup address_cg with function sample(bit [6:0] address, bit [4:0] endp);
    cp_address: coverpoint address {
      bins zero            = {0};
      bins one             = {1};
      bins seven           = {7};
      bins range_2_to_14   = {[2:14]};
      bins fifteen         = {15};
      bins range_16_to_126 = {[16:126]};
      bins range_127       = {127};
    }
    cp_endp: coverpoint endp {
      bins three = {3};
      bins seven = {7};
    }
    cr_address_X_endp: cross cp_address, cp_endp;
  endgroup

  // 7. Modos de configuração de Endpoint OUT
  covergroup ep_out_cfg_cg with function sample(usb_transaction::usb_pid_e pid, bit out_enable, bit rxenable_setup,
                                                bit rxenable_out, bit set_nak_out, bit out_stall,
                                                bit out_iso);
    cp_pid: coverpoint pid {
      bins pkt_types[]  = {usb_transaction::PID_SETUP, usb_transaction::PID_OUT};
      bins ignore_pre[] = {usb_transaction::PID_PRE};
    }
    cp_out_enable:     coverpoint out_enable;
    cp_rxenable_setup: coverpoint rxenable_setup;
    cp_rxenable_out:   coverpoint rxenable_out;
    cp_set_nak_out:    coverpoint set_nak_out;
    cp_out_iso:        coverpoint out_iso;
    cp_out_stall:      coverpoint out_stall;

    cr_pid_x_epconfig: cross cp_pid, cp_out_enable, cp_rxenable_setup,
                             cp_rxenable_out, cp_set_nak_out, cp_out_iso, cp_out_stall;
  endgroup

  // 8. Modos de configuração de Endpoint IN
  covergroup ep_in_cfg_cg with function sample(usb_transaction::usb_pid_e pid,
                                               bit in_enable, bit in_stall, bit in_iso);
    cp_pid: coverpoint pid {
      bins pkt_types[]  = {usb_transaction::PID_IN};
      bins ignore_pre[] = {usb_transaction::PID_PRE};
    }
    cp_in_enable: coverpoint in_enable;
    cp_in_iso:    coverpoint in_iso;
    cp_in_stall:  coverpoint in_stall;

    cr_pid_x_epconfig: cross cp_pid, cp_in_enable, cp_in_iso, cp_in_stall;
  endgroup

  // 9. Níveis de preenchimento das FIFOs
  covergroup fifo_lvl_cg with function sample(usb_transaction::usb_pid_e pid, bit [2:0] avsetup_lvl,
                                              bit [3:0] avout_lvl, bit [3:0] rx_lvl);
    cp_avsetup: coverpoint avsetup_lvl {
      bins empty = {0};
      bins solo  = {1};
      bins full  = {4};
    }
    cp_avout: coverpoint avout_lvl {
      bins empty = {0};
      bins solo  = {1};
      bins full  = {8};
    }
    cp_rx: coverpoint rx_lvl {
      bins empty = {0};
      bins solo  = {7};
      bins full  = {8};
    }
    cp_pid: coverpoint pid {
      bins setup = {usb_transaction::PID_SETUP};
      bins out   = {usb_transaction::PID_OUT};
    }
    cr_fifo_X_pid: cross cp_avsetup, cp_avout, cp_rx, cp_pid;
  endgroup

  // 10. Tamanho dos pacotes de dados
  covergroup data_pkt_cg with function sample(bit dir_in, bit [6:0] pkt_len);
      cp_pkt_len: coverpoint pkt_len {
      bins zero       = {0};
      bins one        = {1};
      bins three      = {3};
      bins four       = {4};
      bins five       = {5};
      bins max_len_m3 = {61};
      bins max_len_m2 = {62};
      bins max_len_m1 = {63};
      bins max_len    = {64};
    }
    cp_dir: coverpoint dir_in;
    cr_pktlen_X_dir: cross cp_pkt_len, cp_dir;
  endgroup

  // 11. Data Toggle por Endpoint (O principal do teste)
  covergroup data_tog_endp_cg with function sample(usb_transaction::usb_pid_e pid, bit dir_in, bit [3:0] endp);
    cp_pid: coverpoint pid {
      bins data0 = {usb_transaction::PID_DATA0};
      bins data1 = {usb_transaction::PID_DATA1};
      bins ack   = {usb_transaction::PID_ACK};
      bins nak   = {usb_transaction::PID_NAK};
    }
    cp_dir: coverpoint dir_in;
    cp_endp: coverpoint endp {
      bins endpoints[] = {[0:11]};
    }
    cr_pid_X_dir_X_endp: cross cp_pid, cp_dir, cp_endp;
  endgroup

  // 12. Tipos de token por Endpoint
  covergroup pid_type_endp_cg with function sample(usb_transaction::usb_pid_e pid, bit [3:0] endp);
    cp_pid: coverpoint pid {
      bins pkt_types[] = {usb_transaction::PID_SETUP, usb_transaction::PID_OUT, usb_transaction::PID_IN};
    }
    cp_endp: coverpoint endp {
      bins endpoints[]  = {[0:11]};
      bins invalid_ep[] = {[12:15]};
    }
    cr_pid_X_endp: cross cp_pid, cp_endp;
  endgroup

  // Construtor: instancia todos os 12 covergroups
  function new(string name = "usbdev_env_cov", uvm_component parent = null);
    super.new(name, parent);
    pids_to_dut_cg   = new();
    pids_from_dut_cg = new();
    framenum_rx_cg   = new();
    crc16_cg         = new();
    crc5_cg          = new();
    address_cg       = new();
    ep_out_cfg_cg    = new();
    ep_in_cfg_cg     = new();
    fifo_lvl_cg      = new();
    data_pkt_cg      = new();
    data_tog_endp_cg = new();
    pid_type_endp_cg = new();
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

endclass
