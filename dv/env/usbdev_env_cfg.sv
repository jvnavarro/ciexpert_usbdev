// Herda de cip_base_env_cfg, que traz as configurações base do OpenTitan/CIP
class usbdev_env_cfg extends cip_base_env_cfg;

  // 1. Registo na fábrica do UVM 
  `uvm_object_utils(usbdev_env_cfg)

  // 2. Construtor padrão para uvm_object (recebe apenas 1 argumento: name)
  function new(string name = "usbdev_env_cfg");
    super.new(name);
  endfunction

endclass