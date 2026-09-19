class usbdev_env extends cip_base_env #( .CFG_T(usbdev_env_cfg));

  // 1. Registro na fábrica do UVM 
  `uvm_component_utils(usbdev_env)

  // 2. Declaração dos subcomponentes membros
  usbdev_env_cov    cov;
  usbdev_scoreboard scoreboard;
  usb20_agent       m_usb20_agent;

  // 3. Construtor padrão
  function new(string name = "usbdev_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // 4. Fase de construção
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase); // <--- VITAL: chama a construção da classe pai

    cov           = usbdev_env_cov::type_id::create("cov", this);
    scoreboard    = usbdev_scoreboard::type_id::create("scoreboard", this);
    m_usb20_agent = usb20_agent::type_id::create("m_usb20_agent", this);
  endfunction

  // 5. Fase de conexão
  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    // no futuro ligaremos as portas TLM do m_usb20_agent ao scoreboard..
  endfunction

endclass