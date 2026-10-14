class usb20_basic_seq extends uvm_sequence #(usb_transaction);
  `uvm_object_utils(usb20_basic_seq)

   function new(string name = "usb20_basic_seq");
     super.new(name);
   endfunction
virtual task body();
    usb_transaction req;

    req = usb_transaction::type_id::create("req");

    start_item(req);
    
    // Passo 2: Randomiza, mas com REGRAS específicas!
    // Forçamos a ser um pacote normal (não um reset) e forçamos o PID a ser OUT
    if (!req.randomize() with { 
        kind == USB_ITEM_NORMAL; 
        pid  == PID_OUT; 
    }) begin
      `uvm_fatal(get_type_name(), "Falha ao randomizar usb_transaction")
    end
    
    // Passo 3: O pacote está pronto e randomizado (dentro das regras), envia pro Driver!
    finish_item(req);

  endtask
endclass
