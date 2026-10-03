class usbdev_env extends cip_base_env #(
    .CFG_T               (usbdev_env_cfg),
    .COV_T               (usbdev_env_cov),
    .VIRTUAL_SEQUENCER_T (usbdev_virtual_sequencer),
    .SCOREBOARD_T        (usbdev_scoreboard)
);

  // 1. Registro na fábrica do UVM
  `uvm_component_utils(usbdev_env)

  // 2. Agente USB 2.0 (cov e scoreboard ja sao criados pelo cip_base_env)
  usb20_agent m_usb20_agent;

  // 3. Construtor padrão
  function new(string name = "usbdev_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // 4. Fase de construção
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase); //  chama a construção da classe pai

    uvm_config_db#(usb20_agent_cfg)::set(this, "m_usb20_agent*", "cfg", cfg.m_usb20_agent_cfg);
    m_usb20_agent = usb20_agent::type_id::create("m_usb20_agent", this);
  endfunction

  // 5. Fase de conexão
  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (cfg.m_usb20_agent_cfg.is_active) begin
      virtual_sequencer.usb20_sequencer_h = m_usb20_agent.sequencer;
    end
    // no futuro ligaremos as portas TLM do m_usb20_agent ao scoreboard..
  endfunction

endclass
