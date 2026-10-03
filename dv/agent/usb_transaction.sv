class usb_transaction extends uvm_sequence_item;

  // PIDs USB 2.0 (4 bits)
  typedef enum bit [3:0] {
    PID_OUT   = 4'b0001,
    PID_IN    = 4'b1001,
    PID_SOF   = 4'b0101,
    PID_SETUP = 4'b1101,
    PID_DATA0 = 4'b0011,
    PID_DATA1 = 4'b1011,
    PID_ACK   = 4'b0010,
    PID_NAK   = 4'b1010,
    PID_STALL = 4'b1110
  } usb_pid_e;

  // Campos de um pacote token (IN/OUT/SETUP)
  rand usb_pid_e pid;
  rand bit [6:0] addr;
  rand bit [3:0] endp;

  // 1. Registro da classe na fábrica do UVM (UVM Factory)
  `uvm_object_utils_begin(usb_transaction)
    `uvm_field_enum(usb_pid_e, pid, UVM_DEFAULT)
    `uvm_field_int(addr, UVM_DEFAULT)
    `uvm_field_int(endp, UVM_DEFAULT)
  `uvm_object_utils_end

  // 2. Construtor padrão
  function new(string name = "usb_transaction");
    super.new(name);
  endfunction

endclass
