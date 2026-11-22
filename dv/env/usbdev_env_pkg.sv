// usbdev environment package (OpenTitan CIP style)
// Groups the cfg, coverage, virtual sequencer, scoreboard, env and vseqs.
package usbdev_env_pkg;

  import uvm_pkg::*;
  import top_pkg::*;
  import dv_utils_pkg::*;
  import dv_base_reg_pkg::*;
  import csr_utils_pkg::*;
  import tl_agent_pkg::*;
  import cip_base_pkg::*;
  import usbdev_ral_pkg::*;
  import usb20_agent_pkg::*;

  `include "uvm_macros.svh"
  `include "dv_macros.svh"

  // DUT parameters
  parameter string LIST_OF_ALERTS[] = {"fatal_fault"};
  parameter uint   NUM_ALERTS       = 1;

  // Link states (usbstat.link_state field), mirror of the enum in
  // rtl/usbdev/usbdev_linkstate.sv
  typedef enum bit [2:0] {
    LinkDisconnected     = 0, // no VBUS or no pull-up
    LinkPowered          = 1, // connected, waiting for bus reset
    LinkPoweredSuspended = 2,
    LinkActive           = 3, // active and receiving SOF
    LinkSuspended        = 4,
    LinkActiveNoSOF      = 5, // active after bus reset, no SOF yet
    LinkResuming         = 6
  } usbdev_link_state_e;

  typedef enum int {
    IntrPktReceived   = 0,
    IntrPktSent       = 1,
    IntrDisconnected  = 2,
    IntrHostLost      = 3,
    IntrLinkReset     = 4,
    IntrLinkSuspend   = 5,
    IntrLinkResume    = 6,
    IntrAvOutEmpty    = 7,
    IntrRxFull        = 8,
    IntrAvOverflow    = 9,
    IntrLinkInErr     = 10,
    IntrRxCrcErr      = 11,
    IntrRxPidErr      = 12,
    IntrRxBitstuffErr = 13,
    IntrFrame         = 14,
    IntrPowered       = 15,
    IntrLinkOutErr    = 16,
    IntrAvSetupEmpty  = 17
  } usbdev_intr_e;

  // Environment
  `include "usbdev_env_cfg.sv"
  `include "usbdev_env_cov.sv"
  `include "usbdev_virtual_sequencer.sv"
  `include "usbdev_scoreboard.sv"
  `include "usbdev_env.sv"

  // Virtual sequences (list in tests/seq_lib/usbdev_vseq_list.sv)
  `include "usbdev_vseq_list.sv"

endpackage : usbdev_env_pkg
