class usb20_basic_seq extends uvm_sequence #(usb_transaction);
  `uvm_object_utils(usb20_basic_seq)

   function new(string name = "usb20_basic_seq");
     super.new(name);
   endfunction

  virtual task body();
   usb_transaction req;

   req = usb_transaction::type_id::create("req");

   start_item(req);
   finish_item(req);
  endtask

endclass
