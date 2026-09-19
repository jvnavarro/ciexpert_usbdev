// Herda de cip_base_env_cov, que traz os recursos base de cobertura do OpenTitan
class usbdev_env_cov extends cip_base_env_cov #(
  .CFG_T(usbdev_env_cfg)
);

  // 1. Registro na fábrica do UVM 
  `uvm_component_utils(usbdev_env_cov)

  // 2. Construtor padrão de componente 
  function new(string name = "usbdev_env_cov", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // 3. Fase de construção onde os covergroups serão instanciados no futuro
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

endclass