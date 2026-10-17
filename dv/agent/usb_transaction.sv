class usb_transaction extends uvm_sequence_item;

  // PIDs USB 2.0 (4 bits)
  typedef enum bit [3:0] {
    PID_OUT   = 4'b0001,
    PID_IN    = 4'b1001,
    PID_SOF   = 4'b0101,
    PID_SETUP = 4'b1101,
    PID_DATA0 = 4'b0011,
    PID_DATA1 = 4'b1011,
    PID_ACK   = 4'b0010,
    PID_NAK   = 4'b1010,
    PID_STALL = 4'b1110,
    PID_PRE   = 4'b1100
  } usb_pid_e;
  // Tipos de transação para o Driver
  typedef enum bit [1:0] {
    USB_ITEM_NORMAL,
    USB_ITEM_BUS_RESET,
    USB_ITEM_IDLE
  } item_kind_e;

  rand item_kind_e kind;
  rand int unsigned reset_us;
  rand int unsigned idle_bits;
  // Campos de cabeçalho
  rand usb_pid_e pid;
  rand bit [6:0] addr;
  rand bit [3:0] endp;
  rand bit       dir_in; // 0 = OUT, 1 = IN

  // NOVO: Array dinâmico para carregar o payload de dados
  rand byte data[];
  rand bit [10:0] frame_num;

  // Preenchidos pelo agente (não randomizados):
  bit want_rsp;    // req: 1 = a sequência quer a resposta do DUT (vai chamar get_response)
  bit no_response; // rsp do driver: 1 = o DUT não respondeu a tempo
  bit from_device; // monitor: 1 = pacote enviado pelo DUT, 0 = pelo host
  // ---------------------------------------------------------
  // CONSTRAINTS (Regras de valores mínimos, máximos e lógicos)
  // ---------------------------------------------------------

  // Regra 1: Limita o tamanho do pacote de dados entre 0 e 64 bytes (padrão USB Full Speed)
  constraint c_data_size {
    data.size() inside {[0:64]};
  }

  // Regra 2: O OpenTitan usbdev suporta endpoints físicos de 0 a 11.
  constraint c_valid_endp {
    endp inside {[0:11]}; 
  }

  // Regra 3: Se for um Token de IN, OUT ou SETUP, não há payload de dados.
  constraint c_token_no_data {
    if (pid inside {PID_IN, PID_OUT, PID_SETUP}) {
      data.size() == 0;
    }
  }

  // Regra 4: Limites dos itens de controle (o DUT detecta reset após ~3 us de SE0)
  constraint c_reset_us {
    reset_us inside {[5:20]};
  }

  constraint c_idle_bits {
    idle_bits inside {[1:100]};
  }

  `uvm_object_utils_begin(usb_transaction)
    `uvm_field_enum(item_kind_e, kind, UVM_DEFAULT)
    `uvm_field_enum(usb_pid_e, pid, UVM_DEFAULT)
    `uvm_field_int(addr, UVM_DEFAULT)
    `uvm_field_int(endp, UVM_DEFAULT)
    `uvm_field_int(dir_in, UVM_DEFAULT)
    `uvm_field_int(frame_num, UVM_DEFAULT)
    `uvm_field_array_int(data, UVM_DEFAULT)
    `uvm_field_int(reset_us, UVM_DEFAULT)
    `uvm_field_int(idle_bits, UVM_DEFAULT)
    `uvm_field_int(want_rsp, UVM_DEFAULT)
    `uvm_field_int(no_response, UVM_DEFAULT)
    `uvm_field_int(from_device, UVM_DEFAULT)
  `uvm_object_utils_end

  // 2. Construtor padrão
  function new(string name = "usb_transaction");
    super.new(name);
  endfunction
// Retorna 1 se for um pacote Token (IN, OUT, SETUP)
  function bit is_token();
    return (pid == PID_IN || pid == PID_OUT || pid == PID_SETUP);
  endfunction

  // Funções auxiliares
  // 1. Retorna 1 se o pacote for do fluxo IN (DUT -> Host)
  function bit is_in();
    return (pid inside {PID_IN}) || dir_in;
  endfunction

  // Retorna 1 se for um pacote de Dados (DATA0, DATA1)
  function bit is_data();
    return (pid == PID_DATA0 || pid == PID_DATA1);
  endfunction

  // Retorna 1 se for um Start of Frame
  function bit is_sof();
    return (pid == PID_SOF);
  endfunction

  // Retorna 1 se o host, depois de enviar este pacote, espera resposta do device:
  // DATA -> handshake (ACK/NAK/STALL); IN -> DATA ou handshake
  function bit expects_response();
    return (is_data() || pid == PID_IN);
  endfunction
endclass