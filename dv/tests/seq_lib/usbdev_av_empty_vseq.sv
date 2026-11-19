/*Verify the functionality of 'av_out_empty' and 'av_setup_empty' interrupts when the Av OUT/SETUP Buffer FIFO is empty.

- Choose at random whether to test the AV OUT Buffer FIFO or the AV SETUP Buffer FIFO.

- Enable the interrupt for AV OUT/SETUP empty by setting INTR_ENABLE[7/17] and then send back to back packets to the device.

- Receive and discard any buffers that appear in the RX FIFO.

- Verify that this interrupt pin goes high once the Av OUT/SETUP Buffer FIFO is empty. */

class usbdev_av_empty_vseq extends usbdev_base_vseq;

`uvm_object_utils(usbdev_av_empty_vseq);

function new (name="usbdev_av_empty_vseq");
    super.new(name);
endfunction

virtual task body();

endtask;

endclass