// Herda de cip_base_env_cfg, que traz as configurações base do OpenTitan/CIP
class usbdev_env_cfg extends cip_base_env_cfg #(.RAL_T(usbdev_reg_block)); // usbdev_reg_block ta em /cip_infra/ral/usbdev_ral_pkg.sv

  // configuracao do agente usb 2.0
  rand usb20_agent_cfg m_usb20_agent_cfg;

  // 1. Registo na fábrica do UVM 
  `uvm_object_utils_begin(usbdev_env_cfg)
    `uvm_field_object(m_usb20_agent_cfg, UVM_DEFAULT)
  `uvm_object_utils_end

  // 2. Construtor padrão para uvm_object (recebe apenas 1 argumento: name)
  function new(string name = "usbdev_env_cfg");
    super.new(name);
  endfunction

  // Metodx de inicializacao do ambiente cip
  virtual function void initialize(bit inherit_ral_models = 1'b0);
    list_of_alerts = usbdev_env_pkg::LIST_OF_ALERTS;
    super.initialize(inherit_ral_models);

    // o hw usbdev suporta 1 transacao TL-UL por vez
    m_tl_agent_cfgs[RAL_T::type_name].max_outstanding_req = 1;
    
    // cria o objeto de configuracao do agente usb 2.0
    m_usb20_agent_cfg = usb20_agent_cfg::type_id::create("m_usb20_agent_cfg");
    
    // numero de interrupcoes suportadas pelo rtl do usbdev
    num_interrupts = 18;
  endfunction
  // 
endclass