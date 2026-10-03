class usbdev_env extends cip_base_env #(
    .CFG_T(usbdev_env_cfg),
    .VIRTUAL_SEQUENCER_T(usbdev_virtual_sequencer),
    .SCOREBOARD_T(usbdev_scoreboard),
    .COV_T(usbdev_env_cov)
);

  // 1. Registro na fábrica do UVM 
  `uvm_component_utils(usbdev_env)

  // 2. Declaração dos subcomponentes membros
  usb20_agent       m_usb20_agent;

  // 3. Construtor padrão
  function new(string name = "usbdev_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // 4. Fase de construção
  virtual function void build_phase(uvm_phase phase);
    // a classe pai cria automaticamente o tl_agent, scoreboard, virtual_sequencer e ral
    super.build_phase(phase); //  chama a construção da classe pai
    // passa a configuracao para o agente usb 2.0 e o instancia
    uvm_config_db#(usb20_agent_cfg)::set(this, "m_usb20_agent*", "cfg", cfg.m_usb20_agent_cfg);
    m_usb20_agent = usb20_agent::type_id::create("m_usb20_agent", this);
  endfunction

  // 5. Fase de conexão
  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    // conecta o sequencer do agente usb 2.0 ao virtual sequencer
    if(cfg.m_usb20_agent_cfg.is_active) begin
      virtual_sequencer.usb20_sequencer_h = m_usb20_agent.sequencer;
    end
    // no futuro ligaremos as portas TLM do m_usb20_agent ao scoreboard..
  endfunction

endclass
