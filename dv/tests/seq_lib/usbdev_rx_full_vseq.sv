/*Verify the functionality of rx_full signal when RX FIFO is full.

- Enable the interrupt for RX full by setting INTR_ENABLE[8] and then send back to back packets to the device.

- Don't service the packets received by popping out from rx_fifo; leave it to become full.

- Verify that this interrupt pin goes high once the received fifo is full.
*/

class usbdev_rx_full_vseq extends usbdev_base_vseq;
  `uvm_object_utils(usbdev_rx_full_vseq)

  function new(string name = "usbdev_rx_full_vseq");
    super.new(name);
  endfunction

  virtual task body();
    // 1. Enable the rx_full interrupt (INTR_ENABLE[8])

    // 2. Send back to back packets; do not read the rxfifo

    // 3. Check that the rx_full pin goes high
  endtask

endclass
