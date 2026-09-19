class usb20_agent extends dv_base_agent #(.CFG_T(usb20_agent_cfg));

  // 1. Registro na fábrica 
  `uvm_component_utils(usb20_agent)

  // 2. Construtor padrão de componente (recebe name e parent)
  function new(string name = "usb20_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // 3. Fase de construção: onde os subcomponentes serão instanciados no futuro..(monitor,driver)
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  // 4. Fase de conexão: onde as portas TLM e interfaces serão ligadas
  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
  endfunction

endclass