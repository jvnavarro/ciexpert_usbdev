package usbdev_env_pkg;
    // byJ
    // 1. PAcotes de dependência externa e do cip_infra
    import uvm_pkg::*;
    import top_pkg::*;
    import dv_utils_pkg::*;
    import dv_base_reg_pkg::*;
    import csr_utils_pkg::*;
    import tl_agent_pkg::*;
    import usb20_agent_pkg::*;
    import dv_lib_pkg::*;
    import cip_base_pkg::*;
    import usbdev_ral_pkg::*;

    // Macros UVM e DV
    `include "uvm_macros.svh"
    `include "dv_macros.svh"

    // 2. Parâmetros do Hardware USBDEV
    parameter uint NEndpoints = 12;             // suporta 12 endpoints (0 a 11)
    parameter uint MaxPktSizeByte = 64;         // tamanho maximo de pacote usb full-speed (12mbps)
    parameter uint NumBuffers = 32;             // 32 buffers de 64 bytes na SRAM interna

    // 3. Alertas exigidos pela macro DV_ALERT_IF_CONNECT
    parameter uint NUM_ALERTS = 1;
    parameter string LIST_OF_ALERTS[NUM_ALERTS] = {"fatal_fault"};

    // 4. Inclusao dos componentes do ambiente (na ordem de dependencia)
`include "usbdev_env_cfg.sv"
`include "usbdev_env_cov.sv"
`include "usbdev_virtual_sequencer.sv"
`include "usbdev_scoreboard.sv"
`include "usbdev_env.sv"

endpackage: usbdev_env_pkg