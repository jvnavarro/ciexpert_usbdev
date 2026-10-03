package usbdev_test_pkg;

    // 1. Dependencias do UVM, CIP e do nosso ambiente
    import uvm_pkg::*;
    import dv_utils_pkg::*;
    import csr_utils_pkg::*;
    import cip_base_pkg::*;
    import usbdev_env_pkg::*;
    import usbdev_ral_pkg::*;

    // Macros UVM e DV
    `include "uvm_macros.svh"
    `include "dv_macros.svh"

    // 2. Inclusao das sequencias e testes (ordem de dependencia)
    `include "usbdev_base_vseq.sv"
    `include "usbdev_base_test.sv"
endpackage: usbdev_test_pkg












