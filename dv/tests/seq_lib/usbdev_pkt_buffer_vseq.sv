/*Verify the functionality of rx fifo.

- Send an OUT transaction to the DUT with appropriate data packet.

- After successful reception read the buffer id, setup/out flag and size from the RX FIFO entry.

- Then perform a read operation on the SRAM with address and control info provided by the rxfifo.

- Verify that the data read from the SRAM matches the data sent to the device in the data packet of the OUT transaction.
*/
class usbdev_pkt_buffer_vseq extends usbdev_smoke_vseq; // herda do smoke pq tem funções parecidas

`uvm_object_utils(usbdev_pkt_buffer_vseq)

function new(string name = "usbdev_pkt_buffer_vseq");
    super.new(name);
endfunction
typedef struct {  
    bit  [3:0] ep;
    bit [4:0] buffer;
    byte      data[];
} 
rxfifo_entry_t;
rxfifo_entry_t expected_q[$];

virtual task body();
  // 1. Configura registradores e conecta o dispositivo
  configure_and_connect();

  // 2. Fase de Injeção: Envia N pacotes acumulando na Rx FIFO
  send_packet_burst(4);

  // 3. Fase de Leitura: Descarrega a Rx FIFO e valida SRAM
  //check_rxfifo_and_sram();

endtask

virtual task send_packet_burst(int num_pkts);
  rxfifo_entry_t entry;
  bit [4:0]      current_buf;
  usb_transaction::usb_pid_e data_pid;
  usb_transaction            usb_rsp;   
  uvm_sequence_item          rsp_base;

bit [4:0] used_bufs[$] = '{setup_buf, out_buf, in_buf}; // connect do smoke

  for (int i = 0; i < num_pkts; i++) begin

    if (i == 0) begin
      current_buf = out_buf;
    end else begin
      // não pegar buffers ja usados
      `DV_CHECK_STD_RANDOMIZE_WITH_FATAL(current_buf,!(current_buf inside {used_bufs});)
      used_bufs.push_back(current_buf);
      // passar para hardware
      csr_wr(.ptr(ral.avoutbuffer), .value(current_buf)); 
    end

   // envio do token out
  `uvm_do_on_with(req, p_sequencer.usb20_sequencer_h, {
      req.kind == usb_transaction::USB_ITEM_NORMAL;
      req.pid  == usb_transaction::PID_OUT;
      req.addr == 7'h00;
      req.endp == ep;
  })
    // envio com data toggle (DATA0/DATA1)
    data_pid = (i % 2 == 0) ? usb_transaction::PID_DATA0 : usb_transaction::PID_DATA1;

    req = usb_transaction::type_id::create("req");
    start_item(req, -1, p_sequencer.usb20_sequencer_h);
    `DV_CHECK_RANDOMIZE_WITH_FATAL(req,
      req.kind == usb_transaction::USB_ITEM_NORMAL;
      req.pid  == data_pid;
    )
    req.want_rsp = 1'b1; // exige a devolução do Handshake (ACK)
    finish_item(req);
   // conferir a resposta
    get_response(rsp_base);
    `DV_CHECK_FATAL($cast(usb_rsp, rsp_base), "Falha no $cast da resposta USB")
    `DV_CHECK_EQ(usb_rsp.pid, usb_transaction::PID_ACK, $sformatf("Esperado ACK no pacote %0d da rajada, veio 0x%0h", i, usb_rsp.pid))
   // salvar valores para comparar
    entry.ep     = ep;
    entry.buffer = current_buf;
    entry.data   = req.data; 
    expected_q.push_back(entry);
    
  end
endtask
//virtual task check_rxfifo_and_sram();
//endtask

endclass