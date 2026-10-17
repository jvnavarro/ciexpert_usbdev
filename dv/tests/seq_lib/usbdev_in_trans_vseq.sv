class usbdev_in_trans_vseq extends usbdev_base_vseq;

`uvm_object_utils(usbdev_in_trans_vseq)

function new(string name = "usbdev_in_trans_vseq");
	super.new(name);
endfunction

virtual task body();
	uvm_reg_data_t valor_lido;
	usb20_basic_seq m_usb20_seq;
	virtual usb20_if usb_vif;
	uvm_status_e usbctrl_status;
	if(!uvm_config_db#(virtual usb20_if)::get(
	null, "uvm_test_top.env.m_usb20_agent.driver", "vif", usb_vif)) begin
	`uvm_fatal(get_type_name(), "ETAPA 9: Nao foi possivel obter a interface USB")
end
`uvm_info(get_type_name(),
	"Iniciando teste in_trans",
	UVM_LOW)
dut_init();
// Etapa 1: ler o registrador in_sent
csr_rd(.ptr(ral.in_sent[0]), .value(valor_lido));

	`uvm_info(get_type_name(),
		$sformatf("Valor de in_sent: 0x%08h", valor_lido),
		UVM_LOW)

// Etapa 2: verificar o estado inicial
if(valor_lido !== 32'h0) begin
	`uvm_error(get_type_name(),
		$sformatf("Esperado 0x00000000, recebido 0x%08h",valor_lido))
end
else begin
`uvm_info(get_type_name(),
	"PASS: in_sent apresenta valor zero",
	UVM_LOW)
	end
// Vetifica o estado inicial da configuração do endpoint 2
csr_rd(.ptr(ral.configin[2]), .value(valor_lido));

`uvm_info(get_type_name(),
	$sformatf("Valor inicial de configin[2]: 0x%08h",valor_lido),
	UVM_LOW)
if (valor_lido !== 32'h0) begin
	`uvm_error(get_type_name(),
	$sformatf("configin[2] deveria inicar em zero, mas retornou 0x%08h",valor_lido))
end
else begin
	`uvm_info(get_type_name(),
		"PASS: configin[2] apresenta valor inicial zero",
		UVM_LOW)
end
// Etapa 3: configuração inicial do endpoint 2
// Buffer 0, tamanho 8 bytes, transmissão ainda desabilitada

csr_wr(.ptr(ral.configin[2]), .value(32'h00000800));

csr_rd(.ptr(ral.configin[2]), .value(valor_lido));

if ((valor_lido & 32'h80007F1F) !== 32'h00000800) begin
	`uvm_error(get_type_name(),
		$sformatf("Falha na configuração inicial: 0x%08h",
		valor_lido))
end
else begin
	`uvm_info(get_type_name(),
	"PASS: configuração inicial no endpoint 2",
	UVM_LOW)
end
// Etapa 4: preparar o buffer de transmissão IN
// Buffer 0: duas palavras de 32 bits = 8 bytes

mem_wr(.ptr(ral.buffer), .offset(0), .data(32'h04030201));
mem_wr(.ptr(ral.buffer), .offset(1), .data(32'h08070605));
	`uvm_info(get_type_name(),
	"Dados de transmissão escritos no buffer 0",
	UVM_LOW)
// Etapa 5: Verificar os dados escritos no buffer 0
// Primeira palavra: bytes 01 02 03 04
mem_rd(.ptr(ral.buffer),
	.offset(0),
	.data(valor_lido));
if(valor_lido !== 32'h04030201) begin
	`uvm_error(get_type_name(),
		$sformatf("Erro no buffer[0]: 0x%08h", valor_lido))
end
else begin
	`uvm_info(get_type_name(),
	"PASS: primeira palavra do buffer correta",
	UVM_LOW)
end
// Segunda palavra: bytes 05 06 07 08
mem_rd(.ptr(ral.buffer), .offset(1), .data(valor_lido));
if(valor_lido !== 32'h08070605) begin
	`uvm_error(get_type_name(),
		$sformatf("Erro no buffer[1]: 0x%08h", valor_lido))
end
else begin
	`uvm_info(get_type_name(),
		"PASS: segunda palavra do buffer correta",
		UVM_LOW)
end
// Etapa 6: Habilitar o endpoint 2 para transacoes IN
csr_wr(.ptr(ral.ep_in_enable[0]), .value(32'h00000004));
csr_rd(.ptr(ral.ep_in_enable[0]), .value(valor_lido));
if(valor_lido !== 32'h00000004) begin
	`uvm_error(get_type_name(),
		$sformatf("Falha ao habilitar enpoint 2: 0x0%08h", valor_lido))
end
else begin
	`uvm_info(get_type_name(),
		"PASS: endpoint 2 habilitado parac IN", UVM_LOW)
end
//Etapa 7 : Preparar a transmissão IN do endpoint 2
// Buffer 0, tamanho 8 bytes, rdy = 1
csr_wr(.ptr(ral.configin[2]), .value(32'h80000800));
csr_rd(.ptr(ral.configin[2]), .value(valor_lido));
if (valor_lido !== 32'h80000800) begin
	`uvm_error(get_type_name(),
		$sformatf(" Falha ao configurar IN do ednpoint 2: 0x%08h", valor_lido))
end 
else begin
	`uvm_info(get_type_name(),
		"PASS: endpoint 2 pronto para transmitir 8 bytes", UVM_LOW)
end
csr_rd(.ptr(ral.usbctrl), .value(valor_lido));
`uvm_info(get_type_name(),
	$sformatf("DEBUG USBCTRL: 0x%08h", valor_lido), UVM_LOW)
// Habilitar controlador USB e configuarar seu endereco
 `uvm_info(get_type_name(), 
        $sformatf(" DEBUG UNDER_RESET: %0b", csr_utils_pkg::under_reset), UVM_LOW) 

csr_wr(.ptr(ral.usbctrl.enable), .value(1'b1));
csr_wr(.ptr(ral.usbctrl.device_address), .value(7'h12));
`uvm_info(get_type_name(),
	$sformatf("DEBUG RAL USBCTRL: 0x%08h", ral.usbctrl.get_mirrored_value()), UVM_LOW)
// Confirmar configuracao 
csr_rd(.ptr(ral.usbctrl), .value(valor_lido));
`uvm_info(get_type_name(),
	$sformatf(" USBCTRL configurado: 0x%08h", valor_lido), UVM_LOW)
ral.usbctrl.write(
	.status(usbctrl_status),
	.value(32'h00120001),
	.parent(this)
);
`uvm_info(get_type_name(),
	$sformatf(" DEBUG USBCTRL WRITE STATUS: %s", usbctrl_status.name()),UVM_LOW)
csr_rd(.ptr(ral.usbctrl), .value(valor_lido));
`uvm_info(get_type_name(),
	$sformatf("DEBUG USBCTRL APOS WRITE DIRETO: 0x%08h", valor_lido), UVM_LOW)
// Etapa 8: Iniciar a sequencia USB 2.0
m_usb20_seq = usb20_basic_seq::type_id::create("m_usb20_seq");
m_usb20_seq.enviar_in_ep2 = 1;
	`uvm_info(get_type_name(),
		"Iniciando sequencia USB para teste IN", UVM_LOW)
// Etapa 9: Verificar se o DUT habilita sua saída USB
// Aguarda ate 2000 ciclos de clock por uma resposta do DUT
begin
bit resposta_detectada = 0;

fork
begin
m_usb20_seq.start(p_sequencer.usb20_sequencer_h);
`uvm_info(get_type_name(),
	"DEBUG ETAPA 9: transmissao do token IN concluida", UVM_LOW)
end

begin
for(int i = 0; i < 2000; i++) begin
	@(posedge usb_vif.clk_i);
	if(i<20) begin
		`uvm_info(get_type_name(),
			$sformatf(" DEBUG ETAPA 9: ciclo=%0d DP_EN=%b DN_EN=%b", 
			i, 
			usb_vif.cio_usb_dp_en_o,
			usb_vif.cio_usb_dn_en_o),
			UVM_LOW)
	end
	if((usb_vif.cio_usb_dp_en_o === 1'b1) ||
	(usb_vif.cio_usb_dn_en_o === 1'b1))  begin
		resposta_detectada = 1;
		break;
		end
	end
end
join
	if(resposta_detectada) begin
	`uvm_info(get_type_name(),
	"ETAPA 9: DUT habilitou a saída USB", UVM_LOW)
	end
	else begin
	`uvm_error(get_type_name(),
	"ETAPA 9: DUT nao habilitou a saída USB")
	end
end
endtask
endclass
