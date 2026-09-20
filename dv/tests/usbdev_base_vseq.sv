class usbdev_base_test extends cip_base_test #(.ENV_T        (usbdev_env), .CFG_T        (usbdev_env_cfg),.VSQR_T       (usbdev_virtual_sequencer));
  `uvm_component_utils(usbdev_base_test)

  function new(string name = "usbdev_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  virtual task run_phase(uvm_phase phase);
    usbdev_base_vseq vseq;
    super.run_phase(phase);
    // 1. Instancia a sequência através da fábrica do UVM
    vseq = usbdev_base_vseq::type_id::create("vseq");
    // 2. Aponta a sequência para o virtual sequencer que reside dentro do env
    vseq.set_sqr(env.virtual_sequencer);
    // 3. Levanta a 'objection' para avisar o UVM que a simulação NÃO deve terminar ainda
    phase.raise_objection(this);
    // 4. Inicia a execução do roteiro (task body da vseq) dentro do virtual sequencer
    vseq.start(env.virtual_sequencer);
    // 5. Baixa a 'objection' indicando que este teste terminou e a simulação pode fechar
    phase.drop_objection(this);
  endtask

endclass