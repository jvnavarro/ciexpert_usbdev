class usb_transaction extends uvm_sequence_item;

  // 1. Registro da classe na fábrica do UVM (UVM Factory)
  `uvm_object_utils(usb_transaction)

  // 2. Construtor padrão
  function new(string name = "usb_transaction");
    super.new(name);
  endfunction

endclass
