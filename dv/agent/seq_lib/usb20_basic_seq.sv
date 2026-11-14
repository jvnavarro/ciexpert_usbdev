class usb20_basic_seq extends uvm_sequence #(usb_transaction);
  `uvm_object_utils(usb20_basic_seq)
   bit enviar_in_ep2 = 0;
   bit enviar_reset = 0;
   bit enviar_data0 = 0;
   bit enviar_ack = 0;
   byte unsigned dados_enviados[];
   function new(string name = "usb20_basic_seq");
     super.new(name);
   endfunction
virtual task body();
    usb_transaction req;
    usb_transaction rsp;
    req = usb_transaction::type_id::create("req");

    start_item(req);
    
    // Randomize the item. The enviar_* flags select the kind and PID
    // (default: OUT token); IN/OUT/SETUP tokens use device address 0x12 and endpoint 2.
    if (!req.randomize() with { 
        kind == (local::enviar_reset ? USB_ITEM_BUS_RESET : USB_ITEM_NORMAL); 
        pid == (local::enviar_ack ? PID_ACK :
       (local::enviar_data0 ? PID_DATA0 :
       (local::enviar_in_ep2 ? PID_IN : PID_OUT)));
	if (!local::enviar_ack &&
    (local::enviar_in_ep2 || (!local::enviar_data0 && !local::enviar_reset))) {
    addr == 7'h12;
    endp == 4'd2;
}
    }) begin
      `uvm_fatal(get_type_name(), "Failed to randomize usb_transaction")
    end
    
    // For DATA0, ask for the DUT response and keep a copy of the payload
    if (enviar_data0) begin
    req.want_rsp = 1'b1;
    dados_enviados = new[req.data.size()];

    foreach (req.data[i]) begin
        dados_enviados[i] = req.data[i];
    end
end
    finish_item(req);
if (enviar_data0) begin
    get_response(rsp);

    if (rsp.pid !== usb_transaction::PID_ACK) begin
        `uvm_error(get_type_name(),
            $sformatf("Expected ACK after DATA0, got PID=0x%0h", rsp.pid))
    end
    else begin
        `uvm_info(get_type_name(),
            "PASS: USBDEV replied ACK to the DATA0 packet",
            UVM_LOW)
    end
end

  endtask
endclass
