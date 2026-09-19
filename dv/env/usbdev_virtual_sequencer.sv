class usbdev_virtual_sequencer extends cip_base_virtual_sequencer #(
  .CFG_T(usbdev_env_cfg),
  .COV_T(usbdev_env_cov)
);

  // 1. Registo na fábrica do UVM como COMPONENTE
  `uvm_component_utils(usbdev_virtual_sequencer)

  // 2. Construtor padrão
  function new(string name = "usbdev_virtual_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // 3. Fase de construção
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  // 4. Fase de conexão (onde no futuro residirão os handles para os sequenciadores dos agentes)
  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
  endfunction

endclass