class usb_transaction extends uvm_sequence_item;

  // USB 2.0 PIDs (4 bits)
  typedef enum bit [3:0] {
    PID_OUT   = 4'b0001,
    PID_IN    = 4'b1001,
    PID_SOF   = 4'b0101,
    PID_SETUP = 4'b1101,
    PID_DATA0 = 4'b0011,
    PID_DATA1 = 4'b1011,
    PID_ACK   = 4'b0010,
    PID_NAK   = 4'b1010,
    PID_STALL = 4'b1110,
    PID_PRE   = 4'b1100
  } usb_pid_e;
  // Item kinds for the driver
  typedef enum bit [1:0] {
    USB_ITEM_NORMAL,
    USB_ITEM_BUS_RESET,
    USB_ITEM_IDLE
  } item_kind_e;

  rand item_kind_e kind;
  rand int unsigned reset_us;
  rand int unsigned idle_bits;
  // Header fields
  rand usb_pid_e pid;
  rand bit [6:0] addr;
  rand bit [3:0] endp;
  rand bit       dir_in; // 0 = OUT, 1 = IN

  // Dynamic array with the data payload
  rand byte data[];
  rand bit [10:0] frame_num;

  // Filled in by the agent (not randomized):
  bit [4:0]  crc5;   // monitor: CRC5 captured from Token/SOF packets
  bit [15:0] crc16;  // monitor: CRC16 captured from DATA packets
  bit want_rsp;    // req: 1 = the sequence wants the DUT response (will call get_response)
  bit no_response; // driver rsp: 1 = the DUT did not respond in time
  bit from_device; // monitor: 1 = packet sent by the DUT, 0 = by the host
  // ---------------------------------------------------------
  // CONSTRAINTS (value limits and protocol rules)
  // ---------------------------------------------------------

  // Rule 1: data payload between 0 and 64 bytes (USB Full Speed limit)
  constraint c_data_size {
    data.size() inside {[0:64]};
  }

  // Rule 2: the OpenTitan usbdev supports endpoints 0 to 11.
  constraint c_valid_endp {
    endp inside {[0:11]}; 
  }

  // Rule 3: IN, OUT and SETUP tokens have no data payload.
  constraint c_token_no_data {
    if (pid inside {PID_IN, PID_OUT, PID_SETUP}) {
      data.size() == 0;
    }
  }

  // Rule 4: limits for control items (the DUT detects a reset after ~3 us of SE0)
  constraint c_reset_us {
    reset_us inside {[5:20]};
  }

  constraint c_idle_bits {
    idle_bits inside {[1:100]};
  }

  `uvm_object_utils_begin(usb_transaction)
    `uvm_field_enum(item_kind_e, kind, UVM_DEFAULT)
    `uvm_field_enum(usb_pid_e, pid, UVM_DEFAULT)
    `uvm_field_int(addr, UVM_DEFAULT)
    `uvm_field_int(endp, UVM_DEFAULT)
    `uvm_field_int(dir_in, UVM_DEFAULT)
    `uvm_field_int(frame_num, UVM_DEFAULT)
    `uvm_field_array_int(data, UVM_DEFAULT)
    `uvm_field_int(reset_us, UVM_DEFAULT)
    `uvm_field_int(idle_bits, UVM_DEFAULT)
    `uvm_field_int(crc5, UVM_DEFAULT)
    `uvm_field_int(crc16, UVM_DEFAULT)
    `uvm_field_int(want_rsp, UVM_DEFAULT)
    `uvm_field_int(no_response, UVM_DEFAULT)
    `uvm_field_int(from_device, UVM_DEFAULT)
  `uvm_object_utils_end

  function new(string name = "usb_transaction");
    super.new(name);
  endfunction
// Returns 1 for a Token packet (IN, OUT, SETUP)
  function bit is_token();
    return (pid == PID_IN || pid == PID_OUT || pid == PID_SETUP);
  endfunction

  // Helper functions
  // Returns 1 if the packet belongs to an IN transfer (DUT -> host)
  function bit is_in();
    return (pid inside {PID_IN}) || dir_in;
  endfunction

  // Returns 1 for a DATA packet (DATA0, DATA1)
  function bit is_data();
    return (pid == PID_DATA0 || pid == PID_DATA1);
  endfunction

  // Returns 1 for a Start of Frame
  function bit is_sof();
    return (pid == PID_SOF);
  endfunction

  // Returns 1 if the host expects a device response after sending this packet:
  // DATA -> handshake (ACK/NAK/STALL); IN -> DATA or handshake
  function bit expects_response();
    return (is_data() || pid == PID_IN);
  endfunction
endclass