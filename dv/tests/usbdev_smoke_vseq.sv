class usbdev_smoke_vseq extends usbdev_base_vseq;
  `uvm_object_utils(usbdev_smoke_vseq)

  // Instância da sequência do agente USB
  usb20_basic_seq m_usb20_seq;

  function new(string name = "usbdev_smoke_vseq");
    super.new(name);
  endfunction

  virtual task body();
    // Instancia a sequência do agente USB
    m_usb20_seq = usb20_basic_seq::type_id::create("m_usb20_seq");

    `uvm_info(get_type_name(), "Disparando a usb20_basic_seq a partir do virtual sequencer...", UVM_LOW)

    // Inicia a sequência no sequencer do agente USB 2.0 apontado pelo p_sequencer
    m_usb20_seq.start(p_sequencer.usb20_sequencer_h);
  endtask

endclass