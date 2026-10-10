class usbdev_in_trans_vseq extends usbdev_base_vseq;

`uvm_object_utils(usbdev_in_trans_vseq)

function new(string name = "usbdev_in_trans_vseq");
	super.new(name);
endfunction

virtual task body();
	uvm_reg_data_t valor_lido;

	`uvm_info(get_type_name(),
		"Iniciando teste in_trans",
		UVM_LOW)
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
endtask
endclass
