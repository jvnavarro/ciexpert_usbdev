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
	`uvm_fatal(get_type_name(), "STEP 9: Failed to retrieve the USB interface")
end
`uvm_info(get_type_name(),
	"Starting in_trans test",
	UVM_LOW)
dut_init();
// Initial OUT reception configuration for endpoint 2
// Make buffer 7 available for incoming USB data

csr_wr(.ptr(ral.ep_out_enable[0].enable[2]), .value(1'b1));

csr_wr(.ptr(ral.rxenable_out), .value(32'h0FFB0004));

csr_wr(.ptr(ral.avoutbuffer.buffer), .value(5'd7));

`uvm_info(get_type_name(),
    "OUT reception configured on endpoint 2 using buffer 7",
    UVM_LOW)
// Enable step 10 verification in the scoreboard
uvm_config_db#(bit)::set(
    null,
    "uvm_test_top.env.scoreboard",
    "verificar_etapa10",
    1'b1
);
// Step 1: Read the in_sent register
csr_rd(.ptr(ral.in_sent[0]), .value(valor_lido));

	`uvm_info(get_type_name(),
		$sformatf("in_sent value: 0x%08h", valor_lido),
		UVM_LOW)

// Step 2: Check the initial state
if(valor_lido !== 32'h0) begin
	`uvm_error(get_type_name(),
		$sformatf("Expected 0x00000000, received 0x%08h",valor_lido))
end
else begin
`uvm_info(get_type_name(),
	"PASS: in_sent is zero",
	UVM_LOW)
	end
// Check the initial configuration of endpoint 2
csr_rd(.ptr(ral.configin[2]), .value(valor_lido));

`uvm_info(get_type_name(),
	$sformatf("Initial configin[2] value: 0x%08h",valor_lido),
	UVM_LOW)
if (valor_lido !== 32'h0) begin
	`uvm_error(get_type_name(),
	$sformatf("configin[2] should initially be zero, but returned 0x%08h",valor_lido))
end
else begin
	`uvm_info(get_type_name(),
		"PASS: configin[2] initial value is zero",
		UVM_LOW)
end
// Step 3: Configure endpoint 2 initially
// Buffer 0, 8 bytes, transmission still disabled

csr_wr(.ptr(ral.configin[2]), .value(32'h00000800));

csr_rd(.ptr(ral.configin[2]), .value(valor_lido));

if ((valor_lido & 32'h80007F1F) !== 32'h00000800) begin
	`uvm_error(get_type_name(),
		$sformatf("Initial configuration failed: 0x%08h",
		valor_lido))
end
else begin
	`uvm_info(get_type_name(),
	"PASS: Initial endpoint 2 configuration successful",
	UVM_LOW)
end
// Step 4: Prepare the IN transmission buffer
// Buffer 0: Two 32-bit words = 8 bytes

mem_wr(.ptr(ral.buffer), .offset(0), .data(32'h04030201));
mem_wr(.ptr(ral.buffer), .offset(1), .data(32'h08070605));
	`uvm_info(get_type_name(),
	"Transmission data written to buffer 0",
	UVM_LOW)
// Step 5: Verify data written to buffer 0
// First word: bytes 01 02 03 04
mem_rd(.ptr(ral.buffer),
	.offset(0),
	.data(valor_lido));
if(valor_lido !== 32'h04030201) begin
	`uvm_error(get_type_name(),
		$sformatf("Error in buffer[0]: 0x%08h", valor_lido))
end
else begin
	`uvm_info(get_type_name(),
	"PASS: First buffer word is correct",
	UVM_LOW)
end
// Second word: bytes 05 06 07 08
mem_rd(.ptr(ral.buffer), .offset(1), .data(valor_lido));
if(valor_lido !== 32'h08070605) begin
	`uvm_error(get_type_name(),
		$sformatf("Error in buffer[1]: 0x%08h", valor_lido))
end
else begin
	`uvm_info(get_type_name(),
		"PASS: Second buffer word is correct",
		UVM_LOW)
end
// Step 6: Enable endpoint 2 for IN transactions
csr_wr(.ptr(ral.ep_in_enable[0]), .value(32'h00000004));
csr_rd(.ptr(ral.ep_in_enable[0]), .value(valor_lido));
if(valor_lido !== 32'h00000004) begin
	`uvm_error(get_type_name(),
		$sformatf("Failed to enable endpoint 2: 0x0%08h", valor_lido))
end
else begin
	`uvm_info(get_type_name(),
		"PASS: Endpoint 2 enabled for IN transactions", UVM_LOW)
end
//Step 7: Prepare endpoint 2 for IN transmission
// Buffer 0, 8 bytes, rdy = 1
csr_wr(.ptr(ral.configin[2]), .value(32'h80000800));
csr_rd(.ptr(ral.configin[2]), .value(valor_lido));

`uvm_info(get_type_name(),
  $sformatf("DEBUG RDY RESTORED: configin[2] = 0x%08h", valor_lido),
  UVM_LOW)
csr_rd(.ptr(ral.configin[2]), .value(valor_lido));
if (valor_lido !== 32'h80000800) begin
	`uvm_error(get_type_name(),
		$sformatf(" Failed to configure endpoint 2 for IN: 0x%08h", valor_lido))
end 
else begin
	`uvm_info(get_type_name(),
		"PASS: Endpoint 2 ready to transmit 8 bytes", UVM_LOW)
end
csr_rd(.ptr(ral.usbctrl), .value(valor_lido));
`uvm_info(get_type_name(),
	$sformatf("DEBUG USBCTRL: 0x%08h", valor_lido), UVM_LOW)
// Enable the USB controller and configure its address
 `uvm_info(get_type_name(), 
        $sformatf(" DEBUG UNDER_RESET: %0b", csr_utils_pkg::under_reset), UVM_LOW) 

csr_wr(.ptr(ral.usbctrl.enable), .value(1'b1));
csr_wr(.ptr(ral.usbctrl.device_address), .value(7'h12));
csr_rd(.ptr(ral.usbctrl), .value(valor_lido));
//`uvm_info(get_type_name(),
  //  $sformatf("DEBUG USBCTRL AFTER RESTORING ADDRESS: 0x%08h", valor_lido), UVM_LOW)
`uvm_info(get_type_name(),
	$sformatf("DEBUG RAL USBCTRL: 0x%08h", ral.usbctrl.get_mirrored_value()), UVM_LOW)
// Confirm configuration 
csr_rd(.ptr(ral.usbctrl), .value(valor_lido));
`uvm_info(get_type_name(),
	$sformatf(" USBCTRL configured: 0x%08h", valor_lido), UVM_LOW)
ral.usbctrl.write(
	.status(usbctrl_status),
	.value(32'h00120001),
	.parent(this)
);
`uvm_info(get_type_name(),
	$sformatf(" DEBUG USBCTRL WRITE STATUS: %s", usbctrl_status.name()),UVM_LOW)
csr_rd(.ptr(ral.usbctrl), .value(valor_lido));
`uvm_info(get_type_name(),
	$sformatf("DEBUG USBCTRL AFTER DIRECT WRITE: 0x%08h", valor_lido), UVM_LOW)
// Generate USB reset before sending the IN token
m_usb20_seq = usb20_basic_seq::type_id::create("m_usb20_reset_seq");
m_usb20_seq.enviar_reset = 1;
m_usb20_seq.start(p_sequencer.usb20_sequencer_h);
csr_rd(.ptr(ral.configin[2]), .value(valor_lido));

`uvm_info(get_type_name(),
  $sformatf("DEBUG AFTER RESET: configin[2] = 0x%08h", valor_lido),
  UVM_LOW)
csr_rd(.ptr(ral.usbctrl), .value(valor_lido));
//`uvm_info(get_type_name(),
  //  $sformatf("DEBUG USBCTRL AFTER RESET: 0x%08h", valor_lido), UVM_LOW)
// Restore the USB address after bus reset
ral.usbctrl.write(
    .status(usbctrl_status),
    .value(32'h00120001),
    .parent(this)
);
// Restore endpoint 2 readiness after USB reset
csr_wr(.ptr(ral.configin[2]), .value(32'h80000800));
// Restore OUT reception after USB reset
csr_wr(.ptr(ral.ep_out_enable[0].enable[2]), .value(1'b1));
csr_wr(.ptr(ral.rxenable_out), .value(32'h0FFB0004));
csr_wr(.ptr(ral.avoutbuffer.buffer), .value(5'd7));

`uvm_info(get_type_name(),
    "OUT reception restored after USB reset",
    UVM_LOW)
// Send OUT token to endpoint 2
m_usb20_seq = usb20_basic_seq::type_id::create("m_usb20_out_seq");
m_usb20_seq.start(p_sequencer.usb20_sequencer_h);

`uvm_info(get_type_name(),
    "OUT token sent to endpoint 2",
    UVM_LOW)
// Send DATA0 with randomized payload and length
m_usb20_seq = usb20_basic_seq::type_id::create("m_usb20_data0_seq");
m_usb20_seq.enviar_data0 = 1'b1;
m_usb20_seq.start(p_sequencer.usb20_sequencer_h);
dados_out_esperados = m_usb20_seq.dados_enviados;
// Provide OUT data for IN response verification
uvm_config_db#(usb_bytes_t)::set(
    null,
    "uvm_test_top.env.scoreboard",
    "dados_in_esperados",
    dados_out_esperados
);
// Read RX FIFO after receiving the OUT/DATA0 packet
csr_rd(.ptr(ral.rxfifo), .value(valor_lido));

`uvm_info(get_type_name(),
    $sformatf("RX FIFO after DATA0: 0x%08h", valor_lido),
    UVM_LOW)
// Verify that the OUT packet was received on endpoint 2
if (valor_lido[23:20] !== 4'd2) begin
    `uvm_error(get_type_name(),
        $sformatf("RX FIFO: Expected endpoint 2, received %0d",
                  valor_lido[23:20]))
end
else begin
    `uvm_info(get_type_name(),
        "PASS: RX FIFO indicates endpoint 2",
        UVM_LOW)
end
// Verify that the received packet is OUT, not SETUP
if (valor_lido[19] !== 1'b0) begin
    `uvm_error(get_type_name(),
        "RX FIFO: SETUP field should be zero")
end
else begin
    `uvm_info(get_type_name(),
        "PASS: RX FIFO confirms OUT packet",
        UVM_LOW)
end
// Verify the received packet length
if (valor_lido[14:8] !== 7'(dados_out_esperados.size())) begin
    `uvm_error(get_type_name(),
        $sformatf("RX FIFO: Expected length %0d, received %0d",
                  dados_out_esperados.size(), valor_lido[14:8]))
end
else begin
    `uvm_info(get_type_name(),
        $sformatf("PASS: RX FIFO confirms %0d received bytes",
                  dados_out_esperados.size()),
        UVM_LOW)
end
// Verify that USBDEV used buffer 7
if (valor_lido[4:0] !== 5'd7) begin
    `uvm_error(get_type_name(),
        $sformatf("RX FIFO: Expected buffer 7, received %0d",
                  valor_lido[4:0]))
end
else begin
    `uvm_info(get_type_name(),
        "PASS: RX FIFO confirms buffer 7",
        UVM_LOW)
end
// Verify data received in buffer 7
for (int i = 0; i < dados_out_esperados.size(); i++) begin

    // Read a new word every four bytes
    if ((i % 4) == 0) begin
        mem_rd(
            .ptr(ral.buffer),
            .offset(32'h70 + (i / 4)),
            .data(palavra_recebida)
        );
    end

    // Compare the corresponding byte
    if (palavra_recebida[8*(i%4) +: 8] !== dados_out_esperados[i]) begin
        `uvm_error(get_type_name(),
            $sformatf("Buffer 7: Byte %0d expected 0x%02h, received 0x%02h",
                      i,
                      dados_out_esperados[i],
                      palavra_recebida[8*(i%4) +: 8]))
    end
end

`uvm_info(get_type_name(),
    "Verification of data received in buffer 7 completed",
    UVM_LOW)
// Prepare IN transmission using the data received through OUT
csr_wr(
    .ptr(ral.configin[2]),
    .value(32'h80000000 | (dados_out_esperados.size() << 8) | 32'd7)
);
csr_rd(.ptr(ral.usbctrl), .value(valor_lido));
//`uvm_info(get_type_name(),
  //  $sformatf("DEBUG USBCTRL AFTER RESTORING ADDRESS: 0x%08h", valor_lido), UVM_LOW)
// Enable the IN packet sent interrupt
csr_wr(.ptr(ral.intr_enable.pkt_sent), .value(1'b1));
// Step 8: Start the USB 2.0 sequence
m_usb20_seq = usb20_basic_seq::type_id::create("m_usb20_seq");
m_usb20_seq.enviar_in_ep2 = 1;
	`uvm_info(get_type_name(),
		"Starting USB sequence for IN test", UVM_LOW)
// Step 9: Verify that the DUT enables its USB output
// Wait up to 2000 clock cycles for a DUT response
begin
bit resposta_detectada = 0;

fork
begin
m_usb20_seq.start(p_sequencer.usb20_sequencer_h);
`uvm_info(get_type_name(),
	"DEBUG STEP 9: IN token transmission completed", UVM_LOW)
end

begin
for(int i = 0; i < 2000; i++) begin
	@(posedge usb_vif.clk_i);
	if(i<20) begin
		`uvm_info(get_type_name(),
			$sformatf(" DEBUG STEP 9: cycle=%0d DP_EN=%b DN_EN=%b", 
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
	"STEP 9: DUT enabled its USB output", UVM_LOW)
	end
	else begin
	`uvm_error(get_type_name(),
	"STEP 9: DUT did not enable its USB output")
	end
// Send host ACK after receiving DATA0 from USBDEV
m_usb20_seq = usb20_basic_seq::type_id::create("m_usb20_ack_seq");
m_usb20_seq.enviar_ack = 1'b1;
m_usb20_seq.start(p_sequencer.usb20_sequencer_h);

`uvm_info(get_type_name(),
    "Host ACK sent after USBDEV DATA0",
    UVM_LOW)
// Verify the packet sent interrupt
csr_rd(.ptr(ral.intr_state.pkt_sent), .value(valor_lido));

if (valor_lido != 1'b1) begin
    `uvm_error(get_type_name(),
        "STEP 11: pkt_sent interrupt was not asserted")
end
else begin
    `uvm_info(get_type_name(),
        "PASS STEP 11: pkt_sent interrupt asserted",
        UVM_LOW)
end
// Step 12: Verify the sent status for endpoint 2
csr_rd(.ptr(ral.in_sent[0].sent[2]), .value(valor_lido));

if (valor_lido != 1'b1) begin
    `uvm_error(get_type_name(),
        "STEP 12: Endpoint 2 in_sent bit was not set")
end
else begin
    `uvm_info(get_type_name(),
        "PASS STEP 12: Endpoint 2 in_sent bit set",
        UVM_LOW)
end
// Step 13: Clear the in_sent bit for endpoint 2
csr_wr(.ptr(ral.in_sent[0].sent[2]), .value(1'b1));

csr_rd(.ptr(ral.in_sent[0].sent[2]), .value(valor_lido));

if (valor_lido != 1'b0) begin
    `uvm_error(get_type_name(),
        "STEP 13: Endpoint 2 in_sent bit was not cleared")
end
else begin
    `uvm_info(get_type_name(),
        "PASS STEP 13: Endpoint 2 in_sent bit cleared successfully",
        UVM_LOW)
end
end
endtask
endclass
