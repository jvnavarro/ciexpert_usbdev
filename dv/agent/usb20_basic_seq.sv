class usb20_basic_seq extends uvm_sequence #(usb_transaction);
  `uvm_object_utils(usb20_basic_seq)
	bit enviar_in_ep2 = 0;
   function new(string name = "usb20_basic_seq");
     super.new(name);
   endfunction

  virtual task body();
   usb_transaction req;

   req = usb_transaction::type_id::create("req");
	start_item(req);
   if(enviar_in_ep2) begin
	if(!req.randomize() with {
		pid == PID_IN;
		addr == 7'h12;
		endp == 4'd2;
}) begin
`uvm_fatal(get_type_name(), "Falha ao configurar transacao IN EP2")
end
end
else begin
	if(!req.randomize()) begin
`uvm_fatal(get_type_name(), "Falha ao randomizar usb_transaction")
end
end
finish_item(req);
`uvm_info(get_type_name(), "DEBUG: finish_item_concluiu", UVM_NONE)
  endtask

endclass
