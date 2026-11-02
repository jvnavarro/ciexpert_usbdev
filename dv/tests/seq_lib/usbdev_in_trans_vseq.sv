class usbdev_in_trans_vseq extends usbdev_base_vseq;

`uvm_object_utils(usbdev_in_trans_vseq)

function new(string name = "usbdev_in_trans_vseq");
	super.new(name);
endfunction

virtual task body();
	uvm_reg_data_t valor_lido;
	usb20_basic_seq m_usb20_seq;
        byte unsigned dados_out_esperados[];
        bit [31:0] palavra_recebida;
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
// Configuracao inicial da recepcao OUT no endpoint 2
// Disponibilizar o buffer 7 para receber os dados USB

csr_wr(.ptr(ral.ep_out_enable[0].enable[2]), .value(1'b1));

csr_wr(.ptr(ral.rxenable_out), .value(32'h0FFB0004));

csr_wr(.ptr(ral.avoutbuffer.buffer), .value(5'd7));

`uvm_info(get_type_name(),
    "Recepcao OUT configurada no endpoint 2 com buffer 7",
    UVM_LOW)
// Ativar a verificacao da Etapa 10 no scoreboard
uvm_config_db#(bit)::set(
    null,
    "uvm_test_top.env.scoreboard",
    "verificar_etapa10",
    1'b1
);
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

`uvm_info(get_type_name(),
  $sformatf("DEBUG RDY RESTAURADO: configin[2] = 0x%08h", valor_lido),
  UVM_LOW)
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
csr_rd(.ptr(ral.usbctrl), .value(valor_lido));
//`uvm_info(get_type_name(),
  //  $sformatf("DEBUG USBCTRL APOS RESTAURAR ENDERECO: 0x%08h", valor_lido), UVM_LOW)
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
// Gerar reset USB antes de enviar o token IN
m_usb20_seq = usb20_basic_seq::type_id::create("m_usb20_reset_seq");
m_usb20_seq.enviar_reset = 1;
m_usb20_seq.start(p_sequencer.usb20_sequencer_h);
csr_rd(.ptr(ral.configin[2]), .value(valor_lido));

`uvm_info(get_type_name(),
  $sformatf("DEBUG APOS RESET: configin[2] = 0x%08h", valor_lido),
  UVM_LOW)
csr_rd(.ptr(ral.usbctrl), .value(valor_lido));
//`uvm_info(get_type_name(),
  //  $sformatf("DEBUG USBCTRL DEPOIS DO RESET: 0x%08h", valor_lido), UVM_LOW)
// Restaurar o endereco USB apos o reset do barramento
ral.usbctrl.write(
    .status(usbctrl_status),
    .value(32'h00120001),
    .parent(this)
);
// Restaurar a prontidão do endpoint 2 após o reset USB
csr_wr(.ptr(ral.configin[2]), .value(32'h80000800));
// Restaurar a recepcao OUT apos o reset USB
csr_wr(.ptr(ral.ep_out_enable[0].enable[2]), .value(1'b1));
csr_wr(.ptr(ral.rxenable_out), .value(32'h0FFB0004));
csr_wr(.ptr(ral.avoutbuffer.buffer), .value(5'd7));

`uvm_info(get_type_name(),
    "Recepcao OUT restaurada apos reset USB",
    UVM_LOW)
// Enviar token OUT para o endpoint 2
m_usb20_seq = usb20_basic_seq::type_id::create("m_usb20_out_seq");
m_usb20_seq.start(p_sequencer.usb20_sequencer_h);

`uvm_info(get_type_name(),
    "Token OUT enviado ao endpoint 2",
    UVM_LOW)
// Enviar DATA0 com conteudo e tamanho aleatorios
m_usb20_seq = usb20_basic_seq::type_id::create("m_usb20_data0_seq");
m_usb20_seq.enviar_data0 = 1'b1;
m_usb20_seq.start(p_sequencer.usb20_sequencer_h);
dados_out_esperados = m_usb20_seq.dados_enviados;
// Disponibilizar os dados do OUT para verificacao da resposta IN
uvm_config_db#(usb_bytes_t)::set(
    null,
    "uvm_test_top.env.scoreboard",
    "dados_in_esperados",
    dados_out_esperados
);
// Ler o RX FIFO apos a recepcao do pacote OUT/DATA0
csr_rd(.ptr(ral.rxfifo), .value(valor_lido));

`uvm_info(get_type_name(),
    $sformatf("RX FIFO apos DATA0: 0x%08h", valor_lido),
    UVM_LOW)
// Verificar se o pacote OUT foi recebido no endpoint 2
if (valor_lido[23:20] !== 4'd2) begin
    `uvm_error(get_type_name(),
        $sformatf("RX FIFO: endpoint esperado 2, recebido %0d",
                  valor_lido[23:20]))
end
else begin
    `uvm_info(get_type_name(),
        "PASS: RX FIFO indica endpoint 2",
        UVM_LOW)
end
// Verificar se o pacote recebido e OUT, nao SETUP
if (valor_lido[19] !== 1'b0) begin
    `uvm_error(get_type_name(),
        "RX FIFO: campo SETUP deveria ser zero")
end
else begin
    `uvm_info(get_type_name(),
        "PASS: RX FIFO confirma pacote OUT",
        UVM_LOW)
end
// Verificar o tamanho do pacote recebido
if (valor_lido[14:8] !== 7'(dados_out_esperados.size())) begin
    `uvm_error(get_type_name(),
        $sformatf("RX FIFO: tamanho esperado %0d, recebido %0d",
                  dados_out_esperados.size(), valor_lido[14:8]))
end
else begin
    `uvm_info(get_type_name(),
        $sformatf("PASS: RX FIFO confirma %0d bytes recebidos",
                  dados_out_esperados.size()),
        UVM_LOW)
end
// Verificar se o USBDEV utilizou o buffer 7
if (valor_lido[4:0] !== 5'd7) begin
    `uvm_error(get_type_name(),
        $sformatf("RX FIFO: buffer esperado 7, recebido %0d",
                  valor_lido[4:0]))
end
else begin
    `uvm_info(get_type_name(),
        "PASS: RX FIFO confirma buffer 7",
        UVM_LOW)
end
// Verificar os dados recebidos no buffer 7
for (int i = 0; i < dados_out_esperados.size(); i++) begin

    // Ler uma nova palavra a cada quatro bytes
    if ((i % 4) == 0) begin
        mem_rd(
            .ptr(ral.buffer),
            .offset(32'h70 + (i / 4)),
            .data(palavra_recebida)
        );
    end

    // Comparar o byte correspondente
    if (palavra_recebida[8*(i%4) +: 8] !== dados_out_esperados[i]) begin
        `uvm_error(get_type_name(),
            $sformatf("Buffer 7: byte %0d esperado 0x%02h, recebido 0x%02h",
                      i,
                      dados_out_esperados[i],
                      palavra_recebida[8*(i%4) +: 8]))
    end
end

`uvm_info(get_type_name(),
    "Verificacao dos dados recebidos no buffer 7 concluida",
    UVM_LOW)
// Preparar a transmissao IN utilizando os dados recebidos no OUT
csr_wr(
    .ptr(ral.configin[2]),
    .value(32'h80000000 | (dados_out_esperados.size() << 8) | 32'd7)
);
csr_rd(.ptr(ral.usbctrl), .value(valor_lido));
//`uvm_info(get_type_name(),
  //  $sformatf("DEBUG USBCTRL APOS RESTAURAR ENDERECO: 0x%08h", valor_lido), UVM_LOW)
// Habilitar interrupcao de pacote IN enviado
csr_wr(.ptr(ral.intr_enable.pkt_sent), .value(1'b1));
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
// Enviar ACK do host após receber o DATA0 do USBDEV
m_usb20_seq = usb20_basic_seq::type_id::create("m_usb20_ack_seq");
m_usb20_seq.enviar_ack = 1'b1;
m_usb20_seq.start(p_sequencer.usb20_sequencer_h);

`uvm_info(get_type_name(),
    "ACK do host enviado apos DATA0 do USBDEV",
    UVM_LOW)
// Verificar interrupcao de pacote enviado
csr_rd(.ptr(ral.intr_state.pkt_sent), .value(valor_lido));

if (valor_lido != 1'b1) begin
    `uvm_error(get_type_name(),
        "ETAPA 11: interrupcao pkt_sent nao foi ativada")
end
else begin
    `uvm_info(get_type_name(),
        "PASS ETAPA 11: interrupcao pkt_sent ativada",
        UVM_LOW)
end
// Etapa 12: Verificar registro de envio no endpoint 2
csr_rd(.ptr(ral.in_sent[0].sent[2]), .value(valor_lido));

if (valor_lido != 1'b1) begin
    `uvm_error(get_type_name(),
        "ETAPA 12: in_sent do endpoint 2 nao foi ativado")
end
else begin
    `uvm_info(get_type_name(),
        "PASS ETAPA 12: in_sent do endpoint 2 ativado",
        UVM_LOW)
end
// Etapa 13: Limpar o registro in_sent do endpoint 2
csr_wr(.ptr(ral.in_sent[0].sent[2]), .value(1'b1));

csr_rd(.ptr(ral.in_sent[0].sent[2]), .value(valor_lido));

if (valor_lido != 1'b0) begin
    `uvm_error(get_type_name(),
        "ETAPA 13: in_sent do endpoint 2 nao foi limpo")
end
else begin
    `uvm_info(get_type_name(),
        "PASS ETAPA 13: in_sent do endpoint 2 limpo corretamente",
        UVM_LOW)
end
end
endtask
endclass
