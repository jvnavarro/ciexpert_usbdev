# Plano de Verificação (Testplan) - USB 2.0 (usbdev)

Baseado no plano de testes oficial do OpenTitan adaptado para o projeto ciexpert_usbdev.

Total de Testpoints mapeados: 82

---

## Resumo dos Testpoints

| # | Testpoint | Estágio | Teste Associado | Descrição Resumida |
|---|-----------|---------|-----------------|---------------------|
| 1 | [smoke](#smoke) | `V1` | `usbdev_smoke` | Smoke test of data transfers in each direction, on both the CSR interface |
| 2 | [in_trans](#in_trans) | `V2` | `usbdev_in_trans` | Verify read and write 1 to clear corresponding bits of the 'in_sent' register. |
| 3 | [data_toggle_clear](#data_toggle_clear) | `V2` | `usbdev_data_toggle_clear` | Verify the ability to clear Data Toggle bits. |
| 4 | [phy_pins_sense](#phy_pins_sense) | `V2` | `usbdev_phy_pins_sense` | Verify that the 'phy_pins_sense' register reflects the current state of the DUT pins. |
| 5 | [av_buffer](#av_buffer) | `V2` | `usbdev_av_buffer` | Verify the behavior of the Available OUT and Available SETUP Buffer FIFOs. |
| 6 | [rx_fifo](#rx_fifo) | `V2` | `usbdev_pkt_buffer` | Verify the functionality of rx fifo. |
| 7 | [phy_config_tx_osc_test_mode](#phy_config_tx_osc_test_mode) | `V2` | `usbdev_phy_config_tx_osc_test_mode` | Verify the oscillator test mode when phy_config.tx_osc_test_mode is enabled. |
| 8 | [phy_config_eop_single_bit_handling](#phy_config_eop_single_bit_handling) | `V2` | `usbdev_phy_config_eop_single_bit_handling` | Verify the correct behavior of the phy_config.eop_single_bit configuration in the PHY module |
| 9 | [phy_config_pinflip](#phy_config_pinflip) | `V2` | `usbdev_phy_config_pinflip` | Verify that the 'phy_config.pinflip' bit swaps the use of the DP and DN signals on both |
| 10 | [phy_config_rand_bus_type](#phy_config_rand_bus_type) | `V2` | `usbdev_phy_config_rand_bus_type` | Choose a random bus configuration and verify that the smoke sequence still passes. |
| 11 | [phy_config_rx_dp_dn](#phy_config_rx_dp_dn) | `V2` | `usbdev_phy_config_rx_dp_dn` | Verify that the DP/DN input signals may be used to decode the USB traffic without an |
| 12 | [phy_config_tx_use_d_se0](#phy_config_tx_use_d_se0) | `V2` | `usbdev_phy_config_tx_use_d_se0` | Verify that the D/SE0 outputs can be used to transmit data rather than the DP and DN |
| 13 | [phy_config_usb_ref_disable](#phy_config_usb_ref_disable) | `V2` | `usbdev_phy_config_usb_ref_disable` | Verify the reference signal generation for clock synchronization may be disabled. |
| 14 | [max_length_out_transaction](#max_length_out_transaction) | `V2` | `usbdev_max_length_out_transaction, usbdev_stream_len_max` | Verify the reception of maximum length OUT data packets. |
| 15 | [max_length_in_transaction](#max_length_in_transaction) | `V2` | `usbdev_max_length_in_transaction` | Verify the transmission of maximum length IN data packets. |
| 16 | [min_length_out_transaction](#min_length_out_transaction) | `V2` | `usbdev_min_length_out_transaction` | Verify the reception of minimum length OUT data packets. |
| 17 | [min_length_in_transaction](#min_length_in_transaction) | `V2` | `usbdev_min_length_in_transaction` | Verify the transmission of minimum length IN data packets. |
| 18 | [random_length_out_transaction](#random_length_out_transaction) | `V2` | `usbdev_random_length_out_transaction` | Verify the reception of random length OUT data packets. |
| 19 | [random_length_in_transaction](#random_length_in_transaction) | `V2` | `usbdev_random_length_in_transaction` | Verify the transmission of random length IN data packets. |
| 20 | [out_stall](#out_stall) | `V2` | `usbdev_out_stall` | Verify the functionality of OUT endpoint stall. |
| 21 | [in_stall](#in_stall) | `V2` | `usbdev_in_stall` | Verify the functionality of IN endpoint stall. |
| 22 | [out_iso](#out_iso) | `V2` | `usbdev_out_iso` | Verify the functionality of isochronous transfer for OUT transaction. |
| 23 | [in_iso](#in_iso) | `V2` | `usbdev_in_iso` | Verify the functionality of isochronous transfer for IN transaction. |
| 24 | [pkt_received](#pkt_received) | `V2` | `usbdev_pkt_received` | Verify the interrupt functionality of packet reception. |
| 25 | [pkt_sent](#pkt_sent) | `V2` | `usbdev_pkt_sent` | Verify the interrupt functionality of packet transmission. |
| 26 | [disconnected](#disconnected) | `V2` | `usbdev_disconnected` | Verify that if VBUS is lost then link is disconnected. |
| 27 | [host_lost](#host_lost) | `V2` | `usbdev_host_lost` | Verify that if link is active (i.e. not completely idle) but SOF was not received from |
| 28 | [link_reset](#link_reset) | `V2` | `usbdev_link_reset` | Verify that if the link is at SE0 longer than 10 us indicating a link reset |
| 29 | [link_suspend](#link_suspend) | `V2` | `usbdev_link_suspend` | Verify that if the line has signaled J (Idle) for longer than 3 ms and is therefore in |
| 30 | [link_resume](#link_resume) | `V2` | `usbdev_link_resume` | Verify that when the link becomes active again after being suspended link resume will rise. |
| 31 | [av_empty](#av_empty) | `V2` | `usbdev_av_empty` | Verify the functionality of 'av_out_empty' and 'av_setup_empty' interrupts when the |
| 32 | [rx_full](#rx_full) | `V2` | `usbdev_rx_full` | Verify the functionality of rx_full signal when RX FIFO is full. |
| 33 | [av_overflow](#av_overflow) | `V2` | `usbdev_av_overflow` | Verify that if a write was done to either the Available OUT Buffer FIFO or the Available |
| 34 | [link_in_err](#link_in_err) | `V2` | `usbdev_link_in_err` | Verify that if a packet to an IN endpoint started to be received but was then dropped due to an error |
| 35 | [rx_crc_err](#rx_crc_err) | `V2` | `usbdev_rx_crc_err` | Verify that if a CRC error occurred then rx_crc_err will raise. |
| 36 | [rx_pid_err](#rx_pid_err) | `V2` | `usbdev_rx_pid_err` | Verify that if an invalid packed identifier (PID) was received then rx_pid_err will raise. |
| 37 | [rx_bitstuff_err](#rx_bitstuff_err) | `V2` | `usbdev_bitstuff_err` | Verify that if an invalid bit stuffing was received then rx_bitstuffing_err will raise. |
| 38 | [link_out_err](#link_out_err) | `V2` | `usbdev_link_out_err` | Verify that if a packet to an OUT endpoint started to be received but was then dropped due to an error |
| 39 | [enable](#enable) | `V2` | `usbdev_enable` | Verify that DUT connects to the USB when enable is set. |
| 40 | [resume_link_active](#resume_link_active) | `V2` | `usbdev_resume_link_active` | Verify that the DUT moves from the LinkPowered state to the LinkResuming state in response to |
| 41 | [device_address](#device_address) | `V2` | `usbdev_device_address` | Verify that the device ignores all packets with addresses that do not match the |
| 42 | [invalid_data1_data0_toggle_test](#invalid_data1_data0_toggle_test) | `V2` | `usbdev_invalid_data1_data0_toggle_test` | Verify the detection and reporting of unexpected Data Toggle bits. |
| 43 | [setup_stage](#setup_stage) | `V2` | `usbdev_setup_stage` | Verify the SETUP stage of enumeration. |
| 44 | [endpoint_access](#endpoint_access) | `V2` | `usbdev_endpoint_access` | Verify the accessibility of all endpoints when endpoints are enabled. |
| 45 | [disable_endpoint](#disable_endpoint) | `V2` | `usbdev_disable_endpoint` | Verify that packet transmission (IN and SETUP) and reception requests (IN) are ignored when |
| 46 | [endpoint_types](#endpoint_types) | `V2` | `usbdev_endpoint_types` | Exercise all permutations of endpoint configuration bits with all possible token packets |
| 47 | [out_trans_nak](#out_trans_nak) | `V2` | `usbdev_out_trans_nak` | Verify the functionality of OUT transaction when rxenable_out is not set. |
| 48 | [setup_trans_ignored](#setup_trans_ignored) | `V2` | `usbdev_setup_trans_ignored` | Verify the functionality of SETUP transaction when rxenable_setup is not set. |
| 49 | [nak_trans](#nak_trans) | `V2` | `usbdev_nak_trans` | Verify the functionality of OUT transaction when set_nak_out is set. |
| 50 | [stall_trans](#stall_trans) | `V2` | `usbdev_stall_trans` | Verify that enabling out_stall shall cause STALL response to |
| 51 | [setup_priority_over_stall_response](#setup_priority_over_stall_response) | `V2` | `usbdev_setup_priority_over_stall_response` | Verify that enabling STALL response does not prevent the reception of a SETUP |
| 52 | [stall_priority_over_nak](#stall_priority_over_nak) | `V2` | `usbdev_stall_priority_over_nak` | Verify that if the configuration has both STALL and NAK enabled the STALL |
| 53 | [pending_in_trans](#pending_in_trans) | `V2` | `usbdev_pending_in_trans` | Verify that the a Link Reset or SETUP transaction cancels any waiting IN transactions |
| 54 | [streaming_test](#streaming_test) | `V2` | `usbdev_streaming_out` | Verify the streaming capability of an endpoint in OUT transaction mode. |
| 55 | [max_clock_error_untracked](#max_clock_error_untracked) | `V2` | `usbdev_freq_loclk, usbdev_freq_hiclk` | Verify the functionality of DUT at maximum clock frequency deltas. |
| 56 | [max_clock_error_tracking](#max_clock_error_tracking) | `V2` | `usbdev_freq_loclk_max, usbdev_freq_hiclk_max` | Verify the functionality of DUT at maximum clock frequency difference, adjusting the |
| 57 | [max_phase_error](#max_phase_error) | `V2` | `usbdev_freq_phase` | Verify that the device and host can work in different phase corners of the 48 MHz clock. |
| 58 | [min_inter_pkt_delay](#min_inter_pkt_delay) | `V2` | `usbdev_min_inter_pkt_delay` | Verify the minimum 2 bit times from the SE0-to-J transition (from EOP) to the |
| 59 | [max_inter_pkt_delay](#max_inter_pkt_delay) | `V2` | `usbdev_max_inter_pkt_delay` | Verify the maximum 7.5 bit times from the SE0-to-J transition (from EOP) to |
| 60 | [device_timeout_missing_host_handshake](#device_timeout_missing_host_handshake) | `V2` | `usbdev_timeout_missing_host_handshake` | Verify that the device times out an IN transaction if it does not receive a |
| 61 | [device_timeout](#device_timeout) | `V2` | `usbdev_device_timeout` | Verify that the device times out transactions when a host response is 18 bit times |
| 62 | [packet_buffer](#packet_buffer) | `V2` | `usbdev_pkt_buffer` | Exercise all buffers within the packet buffer memory, performing reads and writes of |
| 63 | [nak_to_out_trans_when_avbuffer_empty_rxfifo_full](#nak_to_out_trans_when_avbuffer_empty_rxfifo_full) | `V2` | `usbdev_nak_to_out_trans_when_avbuffer_empty_rxfifo_full` | Verify that the device sends out NAK responses to OUT transactions when |
| 64 | [aon_wake_resume](#aon_wake_resume) | `V2` | `usbdev_aon_wake_resume` | Verify that the AON/Wake module is able to detect Resume Signaling and indicate that |
| 65 | [aon_wake_reset](#aon_wake_reset) | `V2` | `usbdev_aon_wake_reset` | Verify that the AON/Wake module is able to detect Reset Signaling and indicate that |
| 66 | [aon_wake_disconnect](#aon_wake_disconnect) | `V2` | `usbdev_aon_wake_disconnect` | Verify that the AON/Wake module is able to detect Bus Disconnection and indicate that |
| 67 | [invalid_sync](#invalid_sync) | `V2` | `usbdev_invalid_sync` | Randomized interspersing of valid and invalid USB traffic. Generate bit-level changes |
| 68 | [spurious_pids_ignored](#spurious_pids_ignored) | `V2` | `usbdev_spurious_pids_ignored` | Check that the device ignores packets with unexpected tokens such as NYET, PRE... |
| 69 | [low_speed_traffic](#low_speed_traffic) | `V2` | `usbdev_low_speed_traffic` | Test that Low Speed traffic on the bus in the downstream direction is appropriately |
| 70 | [rand_bus_resets](#rand_bus_resets) | `V2` | `usbdev_rand_bus_resets` | Ensure that all of SETUP, OUT and IN traffic are robust against randomized |
| 71 | [rand_disconnects](#rand_disconnects) | `V2` | `usbdev_rand_bus_disconnects` | Ensure that all of SETUP, OUT and IN traffic are robust against randomized |
| 72 | [rand_suspends](#rand_suspends) | `V2` | `usbdev_rand_suspends` | Deriving from the sequence 'usbdev_max_usb_traffic' ensure that traffic can be streamed |
| 73 | [max_usb_traffic](#max_usb_traffic) | `V2` | `usbdev_max_usb_traffic, usbdev_max_non_iso_usb_traffic` | Verify operation under maximal traffic to maximal endpoints, exercising all transfer |
| 74 | [stress_usb_traffic](#stress_usb_traffic) | `V2` | `usbdev_stress_usb_traffic` | Derived from 'max_usb_traffic' this also randomly introduces unexpected token packets, |
| 75 | [in_packet_retraction](#in_packet_retraction) | `V2` | `usbdev_iso_retraction` | Exercise retraction of IN packets for Isochronous streams, prioritizing the delivery of |
| 76 | [data_toggle_restore](#data_toggle_restore) | `V2` | `usbdev_data_toggle_restore` | Verify that each of the IN and OUT Data Toggle bits may be both set and cleared by |
| 77 | [setup_priority](#setup_priority) | `V2` | `usbdev_setup_priority` | Verify that the final slot of the Rx FIFO is reserved for use by SETUP packets only. |
| 78 | [fifo_resets](#fifo_resets) | `V2` | `usbdev_fifo_rst` | Test the software-controlled FIFO reset functionality, introduced as a contingency |
| 79 | [tx_rx_disruption](#tx_rx_disruption) | `V2` | `usbdev_tx_rx_disruption` | Verify that the DUT is still capable of transmitting and receiving after a spontaneous |
| 80 | [fifo_levels](#fifo_levels) | `V2` | `usbdev_fifo_levels` | Verify the DUT response to SETUP/OUT data packets under the various possible states of |
| 81 | [rxenable_out_conditional](#rxenable_out_conditional) | `V2` | `usbdev_rxenable_out` | Test the conditional update functionality of the `rxenable_out` register. This register |
| 82 | [dpi_config_host](#dpi_config_host) | `V3` | `usbdev_dpi_config_host` | Using the DPI model run the DUT through a typical configuration sequence consisting of |

---

## Detalhamento dos Testpoints

### <a id="smoke"></a>1. smoke
- **Estágio:** `V1`
- **Testes:** `usbdev_smoke`
- **Descrição:**

  Smoke test of data transfers in each direction, on both the CSR interface
              (buffer read/write) and the USB (packet transmission/reception).
  
              - DV environment programs CSRs for suitable pin configuration, leaving the device
                unconnected by not driving the DP pullup.
              - Program CSRs to enable SETUP packet reception, OUT traffic and IN traffic to a chosen
                endpoint.
              - Present a buffer description in the AvSetup Buffer FIFO, to receive the SETUP packet.
              - Enable the interface (assert DP pull up) to indicate device presence.
              - DV host-side detects device presence.
              - DV host-side transmits a SETUP packet to device address 0, chosen endpoint.
              - Check that the description of the SETUP packet appears in the RxFiFo, with the
                expected 'setup' indicator, buffer ID, and a packet length of 8 bytes.
              - Check that the SETUP packet has been received into the packet buffer memory and
                that the buffer holds the expected content.
              - DV host-side checks that ACK was received from usbdev in response to the SETUP packet.
              - Repeat the above for a regular OUT data packet using the AvOut Buffer FIFO, using the
                same endpoint.
              - Populate a buffer with known randomized packet data for collection from a
                randomly-chosen endpoint.
              - Program CSRs to present the packet for collection by the host.
              - DV host-side transmits an IN request to device address 0, chosen endpoint.
              - DV host-side collect IN DATA packet, and ACKnowledges receipt.
              - Check that the received packet matches against that data written into the buffer.
              - Check that CSRs indicate that the packet has been sent.

---

### <a id="in_trans"></a>2. in_trans
- **Estágio:** `V2`
- **Testes:** `usbdev_in_trans`
- **Descrição:**

  Verify read and write 1 to clear corresponding bits of the 'in_sent' register.
  
              - Configure the device for an IN transaction to a particular endpoint.
              - Read the 'in_sent' register value to get current status of sent packets and
                then write 1s to the bits which are already high.
              - Verify that reading the register shows only those bits high whose corresponding
                endpoints have sent a packet, and - for non-Isochronous transfers - received an ACK
                from the host.
              - Writing ones must clear the corresponding bits of the 'in_sent' register.

---

### <a id="data_toggle_clear"></a>3. data_toggle_clear
- **Estágio:** `V2`
- **Testes:** `usbdev_data_toggle_clear`
- **Descrição:**

  Verify the ability to clear Data Toggle bits.
  
              - Set any random bit of the data toggle register from bit 0 to bit 11 then
                initiate an IN/OUT transaction on the corresponding endpoint whose bit is asserted.
              - Verify that writing 0 to a particular bit (bits 0-11) resets the data toggle bit for
                that particular IN/OUT endpoint to DATA0, to resynchronize with the USB host.
              - But it does not prevent toggling of the flags upon successful transmission/receipt of
                subsequent data packets.

---

### <a id="phy_pins_sense"></a>4. phy_pins_sense
- **Estágio:** `V2`
- **Testes:** `usbdev_phy_pins_sense`
- **Descrição:**

  Verify that the 'phy_pins_sense' register reflects the current state of the DUT pins.
  
              - Read the 'phy_pins_sense' register via TL-UL interface and sample the input
                and output signals of the DUT at that particular instant.
              - Verify that the read value of the register reflects the sampled values of the
                inputs and outputs.

---

### <a id="av_buffer"></a>5. av_buffer
- **Estágio:** `V2`
- **Testes:** `usbdev_av_buffer`
- **Descrição:**

  Verify the behavior of the Available OUT and Available SETUP Buffer FIFOs.
  
              - Choose at random whether to send a SETUP packet or an OUT packet.
              - Write a random 5-bit buffer ID into the 'avoutbuffer' or 'avsetupbuffer' as appropriate.
              - Send a SETUP/OUT token packet followed by a DATA packet to the DUT.
              - Verify that the packet arrives in the RX FIFO with the expected properties
                (buffer ID, packet length and setup/non-setup packet).
              - Verify that the specified buffer within the packet buffer memory contains the data that
                was transmitted.

---

### <a id="rx_fifo"></a>6. rx_fifo
- **Estágio:** `V2`
- **Testes:** `usbdev_pkt_buffer`
- **Descrição:**

  Verify the functionality of rx fifo.
  
              - Send an OUT transaction to the DUT with appropriate data packet.
              - After successful reception read the buffer id, setup/out flag and size
                from the RX FIFO entry.
              - Then perform a read operation on the SRAM with address and control info
                provided by the rxfifo.
              - Verify that the data read from the SRAM matches the data sent to the
                device in the data packet of the OUT transaction.

---

### <a id="phy_config_tx_osc_test_mode"></a>7. phy_config_tx_osc_test_mode
- **Estágio:** `V2`
- **Testes:** `usbdev_phy_config_tx_osc_test_mode`
- **Descrição:**

  Verify the oscillator test mode when phy_config.tx_osc_test_mode is enabled.
  
              - Set the phy_config.tx_osc_test_mode.
              - Verify that the device starts transmitting the J/K pattern continuously.

---

### <a id="phy_config_eop_single_bit_handling"></a>8. phy_config_eop_single_bit_handling
- **Estágio:** `V2`
- **Testes:** `usbdev_phy_config_eop_single_bit_handling`
- **Descrição:**

  Verify the correct behavior of the phy_config.eop_single_bit configuration in the PHY module
              where a single SE0 bit is recognized as an end of packet, while two successive bits are
              required otherwise.
  
              - Set eop_single_bit field true in the 'phy_config' register and then send an OUT data packet with
                a single SE0 bit interval at the end followed by J state (bus Idle).
              - Verify that the device recognizes this EOP as valid, accepts the packet into the RX FIFO and
  	      does not ignore the packet or raise any link_err interrupts.

---

### <a id="phy_config_pinflip"></a>9. phy_config_pinflip
- **Estágio:** `V2`
- **Testes:** `usbdev_phy_config_pinflip`
- **Descrição:**

  Verify that the 'phy_config.pinflip' bit swaps the use of the DP and DN signals on both
              the input and the output sides of the DUT.
  
              - Set up the DUT as normal but ensure that the 'pinflip' bit is instead set to true.
              - Ensure that the agent, including driver and monitor are aware of the pins being swapped.
              - Connect the device to the USB.
              - Verify that USB_DN is pulled high instead of USB_DP, and that USB_DP remains low.
              - Verify that OUT and and IN transactions complete normally and with the expected data
                being transferred.

---

### <a id="phy_config_rand_bus_type"></a>10. phy_config_rand_bus_type
- **Estágio:** `V2`
- **Testes:** `usbdev_phy_config_rand_bus_type`
- **Descrição:**

  Choose a random bus configuration and verify that the smoke sequence still passes.

---

### <a id="phy_config_rx_dp_dn"></a>11. phy_config_rx_dp_dn
- **Estágio:** `V2`
- **Testes:** `usbdev_phy_config_rx_dp_dn`
- **Descrição:**

  Verify that the DP/DN input signals may be used to decode the USB traffic without an
              external differential receiver.
              The USBDEV normally relies upon an external differential receiver to ensure USB 2.0
              specification compliance but it can receive traffic directly using just DP and DN for
              reduced complexity and/or cost.
  
              - This just runs the smoke test with modified PHY configuration.

---

### <a id="phy_config_tx_use_d_se0"></a>12. phy_config_tx_use_d_se0
- **Estágio:** `V2`
- **Testes:** `usbdev_phy_config_tx_use_d_se0`
- **Descrição:**

  Verify that the D/SE0 outputs can be used to transmit data rather than the DP and DN
              signals.
  
              - This just runs the smoke test with modified PHY configuration.

---

### <a id="phy_config_usb_ref_disable"></a>13. phy_config_usb_ref_disable
- **Estágio:** `V2`
- **Testes:** `usbdev_phy_config_usb_ref_disable`
- **Descrição:**

  Verify the reference signal generation for clock synchronization may be disabled.
  
              - Generate a number of SOF packets to the DUT.
              - Check that the 'usb_ref_val_o' rises indicating that valid packets are being detected.
              - Check that 'usb_ref_pulse_o' pulses periodically, in time with the transmission of
                SOF packets to the DUT.
              - Set the usb_ref_disable field true in the phy_config register, but continue to transmit
                the SOF packets.
              - Verify that the 'usb_ref_val_o' becomes deasserted and 'usb_ref_pulse_o' no longer
                pulses in response to the arrival of SOF packets.

---

### <a id="max_length_out_transaction"></a>14. max_length_out_transaction
- **Estágio:** `V2`
- **Testes:** `usbdev_max_length_out_transaction, usbdev_stream_len_max`
- **Descrição:**

  Verify the reception of maximum length OUT data packets.
  
              - Configure the endpoint with 'rxenable_out' bit set and 'ep_enable_out' set.
              - Host sends an OUT token followed by the data packet with maximum payload length of 64 bytes.
              - Verify that the DUT acknowledges through an ACK handshake packet.
              - Check that the received data packet within the DUT packet buffer memory matches the
                packet data that was transmitted.

---

### <a id="max_length_in_transaction"></a>15. max_length_in_transaction
- **Estágio:** `V2`
- **Testes:** `usbdev_max_length_in_transaction`
- **Descrição:**

  Verify the transmission of maximum length IN data packets.
  
              - Configure the DUT to present a known packet of maximum length (64 bytes) for collection
                by the host.
              - Host sends an IN token, then device sends the data packet with maximum payload length of 64 bytes.
              - Verify that the usbdev responds appropriately to the ACK by recording that the IN DATA packet
                was successfully transmitted.
              - DV host-side shall check that the IN data packet contains the expected data with no
                bit stuffing errors and with a correct CRC16.

---

### <a id="min_length_out_transaction"></a>16. min_length_out_transaction
- **Estágio:** `V2`
- **Testes:** `usbdev_min_length_out_transaction`
- **Descrição:**

  Verify the reception of minimum length OUT data packets.
  
              - Configure the endpoint with 'rxenable_out' bit set and 'ep_enable_out' set.
              - Host sends an OUT token followed by the data packet with minimum payload length of 0 bytes.
              - Verify that the DUT acknowledges through an ACK handshake packet.
              - Check that the received data packet within the DUT packet buffer memory matches the
                packet data that was transmitted.

---

### <a id="min_length_in_transaction"></a>17. min_length_in_transaction
- **Estágio:** `V2`
- **Testes:** `usbdev_min_length_in_transaction`
- **Descrição:**

  Verify the transmission of minimum length IN data packets.
  
              - Configure the DUT to present the known packet of minimum length (0 bytes) for collection
                by the host.
              - Host sends an IN token, then device sends the data packet with minimum payload length of 0 bytes.
              - Verify that the usbdev responds appropriately to the ACK by recording that the IN DATA packet
                was successfully transmitted.
              - DV host-side shall check that the IN data packet contains the expected data with no
                bit stuffing errors and with a correct CRC16.

---

### <a id="random_length_out_transaction"></a>18. random_length_out_transaction
- **Estágio:** `V2`
- **Testes:** `usbdev_random_length_out_transaction`
- **Descrição:**

  Verify the reception of random length OUT data packets.
  
              - Configure the endpoint with 'rxenable_out' bit set and 'ep_enable_out' set.
              - Host sends an OUT token followed by the data packet with random payload length
                between 0 and 64 bytes.
              - Length from 0 inclusive to 64 inclusive should be supported.
              - Verify that the DUT acknowledges receipt with an ACK handshake packet.

---

### <a id="random_length_in_transaction"></a>19. random_length_in_transaction
- **Estágio:** `V2`
- **Testes:** `usbdev_random_length_in_transaction`
- **Descrição:**

  Verify the transmission of random length IN data packets.
  
              - Configure the DUT to present a packet of known random length (0-64 bytes, inclusive) and
                content for collection by the host.
              - Host sends an IN token, then device sends the data packet.
              - Verify that the DUT records successful transmission of the data packet by setting the
                corresponding bit of the 'in_sent' register.

---

### <a id="out_stall"></a>20. out_stall
- **Estágio:** `V2`
- **Testes:** `usbdev_out_stall`
- **Descrição:**

  Verify the functionality of OUT endpoint stall.
  
              - Set the 'out_stall' register's bit to 1 for a particular endpoint, then host issues an OUT token packet
                followed by data packet for that endpoint.
              - Verify that the device responds with the PID STALL Handshake.

---

### <a id="in_stall"></a>21. in_stall
- **Estágio:** `V2`
- **Testes:** `usbdev_in_stall`
- **Descrição:**

  Verify the functionality of IN endpoint stall.
  
              - Set the 'in_stall' register's bit to 1 for a particular endpoint, then host issues an IN token packet
                for a particular endpoint.
              - Verify that the device responds with the PID STALL Handshake.

---

### <a id="out_iso"></a>22. out_iso
- **Estágio:** `V2`
- **Testes:** `usbdev_out_iso`
- **Descrição:**

  Verify the functionality of isochronous transfer for OUT transaction.
  
              - Set the 'out_iso' register's bit to 1 for a particular endpoint, then host issues an OUT token to that
                endpoint followed by the OUT data packet.
              - Verify that the device does not send any handshake packet in response.

---

### <a id="in_iso"></a>23. in_iso
- **Estágio:** `V2`
- **Testes:** `usbdev_in_iso`
- **Descrição:**

  Verify the functionality of isochronous transfer for IN transaction.
  
              - Set the 'in_iso' register's bit to 1 for an endpoint, then host issues an IN token to that endpoint.
              - Configure the DUT with a data packet available for collection from that endpoint.
              - Host sends an IN request and collects the IN data packet, but does not send a handshake response.
              - Verify that the device signals successful transmission of the packet via the 'in_sent' register
                without awaiting a handshake packet from the host.

---

### <a id="pkt_received"></a>24. pkt_received
- **Estágio:** `V2`
- **Testes:** `usbdev_pkt_received`
- **Descrição:**

  Verify the interrupt functionality of packet reception.
  
              - Send an OUT/SETUP token packet to an enabled endpoint while enabling the INTR_ENABLE[0] followed by the data.
              - Verify that the corresponding interrupt pin goes high after the successful OUT/SETUP packet reception.

---

### <a id="pkt_sent"></a>25. pkt_sent
- **Estágio:** `V2`
- **Testes:** `usbdev_pkt_sent`
- **Descrição:**

  Verify the interrupt functionality of packet transmission.
  
              - Send an IN transaction token packet to an enabled endpoint while INTR_ENABLE[1] is 1.
              - Verify that the corresponding interrupt pin goes high after sending the successful IN packet.

---

### <a id="disconnected"></a>26. disconnected
- **Estágio:** `V2`
- **Testes:** `usbdev_disconnected`
- **Descrição:**

  Verify that if VBUS is lost then link is disconnected.
  
              - VBUS(sense) is set to 0 while INTR_ENABLE[2] is 0.
              - Verify that the corresponding Interrupt pin goes high after the link disconnected.

---

### <a id="host_lost"></a>27. host_lost
- **Estágio:** `V2`
- **Testes:** `usbdev_host_lost`
- **Descrição:**

  Verify that if link is active (i.e. not completely idle) but SOF was not received from
              host for 4.096 ms, the 'host lost' interrupt becomes asserted.
  
              - Note that there must be _some_ non-idle signaling on the USB during this time because
                otherwise the link state will become suspended, and 'host lost' will not be signaled.
              - Send SOF from host after 4.096 ms while INTR_ENABLE [3] is set.
              - Verify that the corresponding interrupt pin goes high once the host is lost.
              - SOF should normally be received every 1 ms.

---

### <a id="link_reset"></a>28. link_reset
- **Estágio:** `V2`
- **Testes:** `usbdev_link_reset`
- **Descrição:**

  Verify that if the link is at SE0 longer than 10 us indicating a link reset
              (host asserts for min 10 ms, device can react after 2.5 us) then link reset
              will raise.
  
              - Send an SE0 Signal for close to the 10 ms. while INTR_ENABLE [4] is set.
              - Verify that the interrupt pin link_reset goes high once the link reset.

---

### <a id="link_suspend"></a>29. link_suspend
- **Estágio:** `V2`
- **Testes:** `usbdev_link_suspend`
- **Descrição:**

  Verify that if the line has signaled J (Idle) for longer than 3 ms and is therefore in
              suspend state the 'link suspend' will be raised.
  
              - Leave the link in idle state for more than 3 ms while enable the INTR_ENABLE [5] is set and
                also set the wake_control.suspend_req afterwards.
              - Verify that the interrupt pin goes high once the link suspended.

---

### <a id="link_resume"></a>30. link_resume
- **Estágio:** `V2`
- **Testes:** `usbdev_link_resume`
- **Descrição:**

  Verify that when the link becomes active again after being suspended link resume will rise.
  
              - First suspend the link by keeping J signal for 3.1ms and then resume it by changing the
                polarity for 20ms. While the INTR_ENABLE[6] bit is set, also set the wake_control.wake_ack signal.
              - Verify that the interrupt pin link_resume goes high once the link resume.

---

### <a id="av_empty"></a>31. av_empty
- **Estágio:** `V2`
- **Testes:** `usbdev_av_empty`
- **Descrição:**

  Verify the functionality of 'av_out_empty' and 'av_setup_empty' interrupts when the
        	    Av OUT/SETUP Buffer FIFO is empty.
  
              - Choose at random whether to test the AV OUT Buffer FIFO or the AV SETUP Buffer FIFO.
              - Enable the interrupt for AV OUT/SETUP empty by setting INTR_ENABLE[7/17] and then send back to back
                packets to the device.
              - Receive and discard any buffers that appear in the RX FIFO.
              - Verify that this interrupt pin goes high once the Av OUT/SETUP Buffer FIFO is empty.

---

### <a id="rx_full"></a>32. rx_full
- **Estágio:** `V2`
- **Testes:** `usbdev_rx_full`
- **Descrição:**

  Verify the functionality of rx_full signal when RX FIFO is full.
  
              - Enable the interrupt for RX full by setting INTR_ENABLE[8] and then send back to back packets
                to the device.
              - Don't service the packets received by popping out from rx_fifo; leave it to become full.
              - Verify that this interrupt pin goes high once the received fifo is full.

---

### <a id="av_overflow"></a>33. av_overflow
- **Estágio:** `V2`
- **Testes:** `usbdev_av_overflow`
- **Descrição:**

  Verify that if a write was done to either the Available OUT Buffer FIFO or the Available
              SETUP Buffer FIFO when the FIFO was full the 'av_overflow' signal becomes high.
  
              - Fill both of the Available buffer FIFOs.
              - Choose at random whether to supply an additional OUT buffer or a SETUP buffer.
              - Attempt to write a buffer ID to the chosen FIFO.
              - Verify that this interrupt pin goes high indicating that the available fifo has
                reached the overflowing condition.

---

### <a id="link_in_err"></a>34. link_in_err
- **Estágio:** `V2`
- **Testes:** `usbdev_link_in_err`
- **Descrição:**

  Verify that if a packet to an IN endpoint started to be received but was then dropped due to an error
              then link_in_err will raise.
  
              - Send an IN token to the device for initiating an IN transaction.
              - The device should respond with an IN data packet.
              - DV environment returns an invalid crc16 or unexpected PID in the handshake packet.
              - Verify that the link_in_err interrupt goes high following the handshake packet sent by the host.

---

### <a id="rx_crc_err"></a>35. rx_crc_err
- **Estágio:** `V2`
- **Testes:** `usbdev_rx_crc_err`
- **Descrição:**

  Verify that if a CRC error occurred then rx_crc_err will raise.
  
              - Send a token/data packet to the device while intentionally corrupting any of the CRC bits.
              - Verify that the rx_crc_err goes high following the reception of the invalid packet.

---

### <a id="rx_pid_err"></a>36. rx_pid_err
- **Estágio:** `V2`
- **Testes:** `usbdev_rx_pid_err`
- **Descrição:**

  Verify that if an invalid packed identifier (PID) was received then rx_pid_err will raise.
  
              - Send an invalid PID to the device with the higher bits not complementing the lower bits.
              - Verify that the interrupt pin goes high indicating PID error.

---

### <a id="rx_bitstuff_err"></a>37. rx_bitstuff_err
- **Estágio:** `V2`
- **Testes:** `usbdev_bitstuff_err`
- **Descrição:**

  Verify that if an invalid bit stuffing was received then rx_bitstuffing_err will raise.
  
              - generate a packet with 7 consecutive ones (bypassing bitstufffing) on data line.
              - Verify that the interrupt pin goes high indicating bitstuff error.

---

### <a id="link_out_err"></a>38. link_out_err
- **Estágio:** `V2`
- **Testes:** `usbdev_link_out_err`
- **Descrição:**

  Verify that if a packet to an OUT endpoint started to be received but was then dropped due to an error
              then link_out_err will raise.
  
              - send an out packet to the device with invalid crc, token, avbuffer_empty, rx_fifo full conditions.
              - Verify that the interrupt pin goes high indicating an error in the link in OUT transaction.

---

### <a id="enable"></a>39. enable
- **Estágio:** `V2`
- **Testes:** `usbdev_enable`
- **Descrição:**

  Verify that DUT connects to the USB when enable is set.
  
              - set USB_CTRL_enable pin high.
              - Make sure 'phy_config.pinflip' isn't set.
              - Verify that the 'usb_dp_pullup_o' pin goes high.

---

### <a id="resume_link_active"></a>40. resume_link_active
- **Estágio:** `V2`
- **Testes:** `usbdev_resume_link_active`
- **Descrição:**

  Verify that the DUT moves from the LinkPowered state to the LinkResuming state in response to
              the 'resume_link_active' bit being set.
  
              - Disconnect VBUS.
              - Read the link state from `usbstat` register to see if it is in Disconnected state and
                restore VBUS and the pull up.
              - The DUT should move to the Powered state.
              - Send resume signaling (K state) for 20 ms and set the usbctrl.resume_link_active.
              - Verify that the DUT moves into the Resuming state and subsequently ActiveNoSOF.

---

### <a id="device_address"></a>41. device_address
- **Estágio:** `V2`
- **Testes:** `usbdev_device_address`
- **Descrição:**

  Verify that the device ignores all packets with addresses that do not match the
              assigned device address.
  
              - Assign device address to (usbctrl[22:16]) and send packets to this address.
              - Send packets to other addresses.
              - Verify that the device responds to all packets sent by the DV environment (USB side)
                to the assigned address.
              - Verify that the device ignores all packets that are sent to other addresses.

---

### <a id="invalid_data1_data0_toggle_test"></a>42. invalid_data1_data0_toggle_test
- **Estágio:** `V2`
- **Testes:** `usbdev_invalid_data1_data0_toggle_test`
- **Descrição:**

  Verify the detection and reporting of unexpected Data Toggle bits.
  
              - Send a sequence of OUT data packets to the device without toggling between DATA0 and
                DATA1 PIDs in consecutive data packets.
              - Verify that the interrupt pin goes high indicating a link error during OUT
                transactions.

---

### <a id="setup_stage"></a>43. setup_stage
- **Estágio:** `V2`
- **Testes:** `usbdev_setup_stage`
- **Descrição:**

  Verify the SETUP stage of enumeration.
  
              - Send a setup token with a valid setup packet followed by a DATA0 packet requesting
                information about device i.e. descriptors.
              - Verify that the device ACKs the setup packet.

---

### <a id="endpoint_access"></a>44. endpoint_access
- **Estágio:** `V2`
- **Testes:** `usbdev_endpoint_access`
- **Descrição:**

  Verify the accessibility of all endpoints when endpoints are enabled.
  
              - Access all the endpoints of the device in IN and OUT direction by enabling ep_out_enable and
                ep_in_enable along with rxenable_out for OUT transaction.
              - Verify that the device allows access to all endpoints by responding with ACK for OUT
                accesses and data_packet for IN Accesses.

---

### <a id="disable_endpoint"></a>45. disable_endpoint
- **Estágio:** `V2`
- **Testes:** `usbdev_disable_endpoint`
- **Descrição:**

  Verify that packet transmission (IN and SETUP) and reception requests (IN) are ignored when
              endpoints are disabled.
  
              - Disable an endpoint by clearing bit of ep_out_enable and ep_in_enable.
              - Then initiate an IN/OUT transaction to that endpoint.
              - Verify that the Out transactions as well as IN transactions sent to the device on the
                particular endpoint will be ignored.

---

### <a id="endpoint_types"></a>46. endpoint_types
- **Estágio:** `V2`
- **Testes:** `usbdev_endpoint_types`
- **Descrição:**

  Exercise all permutations of endpoint configuration bits with all possible token packets
              (SETUP, OUT, IN and PRE).
  
              - Randomize all endpoint configuration bits (ep_out_enable, ep_in_enable,
                out_stall, in_stall, rxenable_out, rxenable_setup, set_nak_out, out_iso, in_iso).
              - Targeting only the correct device address with randomized traffic, check that only the
                expected traffic is received by the DUT and that all other packets are correctly dropped.

---

### <a id="out_trans_nak"></a>47. out_trans_nak
- **Estágio:** `V2`
- **Testes:** `usbdev_out_trans_nak`
- **Descrição:**

  Verify the functionality of OUT transaction when rxenable_out is not set.
  
              - clear a particular endpoint bit for rx_enable_out register.
              - Then send an out transaction to that endpoint.
              - Verify that the OUT transactions shall be NAKED by OUT endpoints.

---

### <a id="setup_trans_ignored"></a>48. setup_trans_ignored
- **Estágio:** `V2`
- **Testes:** `usbdev_setup_trans_ignored`
- **Descrição:**

  Verify the functionality of SETUP transaction when rxenable_setup is not set.
  
              - clear a particular endpoint bit for rxenable_setup register.
              - Then send a setup transaction to that endpoint.
              - Verify that the SETUP transactions shall not be received by enabled OUT endpoints
                if rxenable_setup is not set.

---

### <a id="nak_trans"></a>49. nak_trans
- **Estágio:** `V2`
- **Testes:** `usbdev_nak_trans`
- **Descrição:**

  Verify the functionality of OUT transaction when set_nak_out is set.
  
              - Set_nak_out and rxenable_out are both set
              - Issue OUT transaction and observe it complete.
              - Observe rxenable_out cleared.
              - Issue OUT transaction and observe it get NAK'd.
              - Verify that the OUT transactions shall be NAKED for disabled endpoint and
                the corresponding bit in rxenable_out register will be cleared.

---

### <a id="stall_trans"></a>50. stall_trans
- **Estágio:** `V2`
- **Testes:** `usbdev_stall_trans`
- **Descrição:**

  Verify that enabling out_stall shall cause STALL response to
              attempted OUT transactions.
  
              - Set out_stall register bits for a particular transaction.
              - Verify that we will get STALL response when we try to attempt OUT transactions.

---

### <a id="setup_priority_over_stall_response"></a>51. setup_priority_over_stall_response
- **Estágio:** `V2`
- **Testes:** `usbdev_setup_priority_over_stall_response`
- **Descrição:**

  Verify that enabling STALL response does not prevent the reception of a SETUP
              transaction/packet. Receipt of the SETUP packet shall clear both the `in_stall` and
              the `out_stall` bits for that endpoint.
  
              - Configure an endpoint for stall response to OUT transactions and then send a SETUP
                transaction to the device on the stalled endpoint.
              - Verify that the SETUP transaction, being higher in priority, clears both in_stall and
                out_stall bits for that endpoint.

---

### <a id="stall_priority_over_nak"></a>52. stall_priority_over_nak
- **Estágio:** `V2`
- **Testes:** `usbdev_stall_priority_over_nak`
- **Descrição:**

  Verify that if the configuration has both STALL and NAK enabled the STALL
              handshake will take priority.
  
              - Configure an endpoint with STALL as well as NAK responses then issue an OUT
                transaction to that endpoint.
              - Verify that the STALL being higher in priority will take precedence over NAK responses.

---

### <a id="pending_in_trans"></a>53. pending_in_trans
- **Estágio:** `V2`
- **Testes:** `usbdev_pending_in_trans`
- **Descrição:**

  Verify that the a Link Reset or SETUP transaction cancels any waiting IN transactions
              by clearing the rdy bit in the configin register of all endpoints.
  
              - Configure an endpoint for transmission by setting fields in 'configin[ep]' register and
                then setting the 'rdy' bit to 1.
              - Send a SETUP transaction to that endpoint or issue a link reset.
              - Verify that the 'rdy' bit in 'configin[ep]' is cleared and the 'pend' bit is set to 1.

---

### <a id="streaming_test"></a>54. streaming_test
- **Estágio:** `V2`
- **Testes:** `usbdev_streaming_out`
- **Descrição:**

  Verify the streaming capability of an endpoint in OUT transaction mode.
  
              - Issue back to back data packets to a particular enabled endpoint.
              - Read the information from RX FIFO as soon as a packet is received
                along with the buffer in the SRAM.
              - Send the buffer ID back to Available buffer FIFO after successful buffer read.
              - Verify that the device is capable of handling the streaming traffic for a
                large number of iterations without Available OUT Buffer FIFO becoming empty or the
                RX FIFO becoming full.

---

### <a id="max_clock_error_untracked"></a>55. max_clock_error_untracked
- **Estágio:** `V2`
- **Testes:** `usbdev_freq_loclk, usbdev_freq_hiclk`
- **Descrição:**

  Verify the functionality of DUT at maximum clock frequency deltas.
              This test does not attempt to model the adjustment of the usb_clk oscillator,
              in response to SOF packets received from the USB host, and therefore cannot
              support the full frequency mismatch required by the USB 2.0 protocol specification.
  
              - Clock the device and the agent with opposite extremes of allowable frequency
                ranges and initiate a transaction with maximum data length.
              - Verify that the transactions occur successfully between the device and host agent
                in both directions, and that all transmitted bytes are decoded correctly.
              - Verify that there are no reports of bit stuffing errors or CRC errors.

---

### <a id="max_clock_error_tracking"></a>56. max_clock_error_tracking
- **Estágio:** `V2`
- **Testes:** `usbdev_freq_loclk_max, usbdev_freq_hiclk_max`
- **Descrição:**

  Verify the functionality of DUT at maximum clock frequency difference, adjusting the
              frequency of 'usb_clk' in response to the arrival times of the SOF packets sent
              from the USB host agent.
  
              - Implement tracking of the SOF packets from the host, using the 'usb_ref_pulse_o'
                signal from the DUT to adjust the USB device clock.
              - With the USB host agent operating at the maximum frequency permissible within the
                USB 2.0 protocol specification, start the USB device operating at the minimum
                permissible frequency and check that SOF packets are still received and decoded
                correctly.
              - Check that the 'usb_ref_pulse_o' signal is produced as expected, and that the
                'usb_clk' signal increases in frequency to match that of the USB host agent.
              - Verify that full length packet transmission to and from the host occurs successfully
                without reports of bit stuffing errors or CRC errors.
              - Repeat the above with the USB host agent at the minimum permissible frequency and
                the USB device starting at the maximum frequency.

---

### <a id="max_phase_error"></a>57. max_phase_error
- **Estágio:** `V2`
- **Testes:** `usbdev_freq_phase`
- **Descrição:**

  Verify that the device and host can work in different phase corners of the 48 MHz clock.
  
              - Clock the device and the agent with opposite corners of phases and initiate a
                transaction with maximum data length.
              - Verify that the transaction between the host agent and device must be successful by
                raising interrupts for successful packet reception or transmission after the end
                of the transaction.

---

### <a id="min_inter_pkt_delay"></a>58. min_inter_pkt_delay
- **Estágio:** `V2`
- **Testes:** `usbdev_min_inter_pkt_delay`
- **Descrição:**

  Verify the minimum 2 bit times from the SE0-to-J transition (from EOP) to the
              J-to-K transition.
  
              - Send at random either a SETUP token packet or an OUT token packet to the DUT.
              - After just 2 bit intervals of Idle state, transmit a DATA packet to the DUT.
              - Verify that the packet is received, decoded correctly and ACKnowledged by the DUT.

---

### <a id="max_inter_pkt_delay"></a>59. max_inter_pkt_delay
- **Estágio:** `V2`
- **Testes:** `usbdev_max_inter_pkt_delay`
- **Descrição:**

  Verify the maximum 7.5 bit times from the SE0-to-J transition (from EOP) to
              the J-to-K transition.
  
              - Send at random either a SETUP token packet or an OUT token packet to the DUT.
              - After 7.5 bit intervals of Idle state, transmit a DATA packet to the DUT.
              - Verify that the packet is received, decoded correctly and ACKnowledged by the DUT.

---

### <a id="device_timeout_missing_host_handshake"></a>60. device_timeout_missing_host_handshake
- **Estágio:** `V2`
- **Testes:** `usbdev_timeout_missing_host_handshake`
- **Descrição:**

  Verify that the device times out an IN transaction if it does not receive a
              handshake response from the host.
  
              - Configure the DUT to present a single packet for IN collection.
              - Collect a non-Isochronous IN packet from the DUT but do not send a handshake packet.
              - Host sends a random choice of SETUP, OUT or IN token packet to the DUT.
              - Check that the packet is still marked as 'rdy' and that 'in_sent' is not set.
              - Retry the IN packet collection and this time send the ACK handshake within the normal
                response period.
              - Check that that packet is collected, that 'rdy' is cleared and that the
                'in_sent' register bit indicates successful transmission of the packet.

---

### <a id="device_timeout"></a>61. device_timeout
- **Estágio:** `V2`
- **Testes:** `usbdev_device_timeout`
- **Descrição:**

  Verify that the device times out transactions when a host response is 18 bit times
              after the packet transmitted by the DUT.
  
              - Configure the DUT to present a single packet for IN collection.
              - Collect a non-Isochronous IN packet from the DUT but do not send a handshake packet
                in response within 18 bit intervals.
              - Check that the packet is still marked as 'rdy' and that 'in_sent' is not set.
              - Send a delayed ACKnowledge handshake packet to the DUT.
              - Check that the packet is still marked as 'rdy' and that 'in_sent' is not set.
              - Retry the IN packet collection and this time send the ACK handshake within the normal
                response period.
              - Check that that packet is collected, that 'rdy' is cleared and that the
                'in_sent' register bit indicates successful transmission of the packet.

---

### <a id="packet_buffer"></a>62. packet_buffer
- **Estágio:** `V2`
- **Testes:** `usbdev_pkt_buffer`
- **Descrição:**

  Exercise all buffers within the packet buffer memory, performing reads and writes of
              packet buffer data from both sides (CSR and USB) simultaneously.
  
              - Randomly choose between IN and OUT packet transfer on the USB side.
              - Randomly choose between buffer read and buffer write on the CSR side.
              - Ensure, however, that the CSR side and the USB side never access the same buffer
                simultaneously; this is guaranteed by the contract that exists between hardware and
                software.
              - Check all transferred data on both sides.
              - Ensure that it is possible for individual read and write accesses to occur at the
                packet buffer memory from both sides within the same cycle.
                Since the packet buffer memory is now a Single Port RAM implementation, this requires
                the CSR-side access to be delayed until the USB side is idle.

---

### <a id="nak_to_out_trans_when_avbuffer_empty_rxfifo_full"></a>63. nak_to_out_trans_when_avbuffer_empty_rxfifo_full
- **Estágio:** `V2`
- **Testes:** `usbdev_nak_to_out_trans_when_avbuffer_empty_rxfifo_full`
- **Descrição:**

  Verify that the device sends out NAK responses to OUT transactions when
              available buffer is empty and RX FIFO is full.
  
              - send out packets to the device at such a rate that avbuffer gets empty and
                RX Fifo becomes full.
              - Verify that the device unable to consume packets at such a rate will set NAK
                responses even though endpoint is enabled.

---

### <a id="aon_wake_resume"></a>64. aon_wake_resume
- **Estágio:** `V2`
- **Testes:** `usbdev_aon_wake_resume`
- **Descrição:**

  Verify that the AON/Wake module is able to detect Resume Signaling and indicate that
              via the USB device register interface.
  
              - Connect the USB device to the USB host model.
              - Send Suspend Signaling to the USB device.
              - Verify that the 'link_suspend' interrupt is raised indicating that the USB has been
                Idle (J) for at least 3ms.
              - Enable the AON/Wake module, leaving it to maintain the pull up state.
              - Initiate Resume Signaling, driving the USB into the 'K' state.
              - Check that the 'wake_req_aon_o' signal from the 'usbdev_aon_wake' module becomes
                asserted.
              - Read from the 'wake_events' CSR of the USB device and check that the 'bus_not_idle'
                bit is asserted.
              - Disable the AON/Wake module and verify that the USB device is still connected,
                i.e. the DP pullup is enabled and DP is high.

---

### <a id="aon_wake_reset"></a>65. aon_wake_reset
- **Estágio:** `V2`
- **Testes:** `usbdev_aon_wake_reset`
- **Descrição:**

  Verify that the AON/Wake module is able to detect Reset Signaling and indicate that
              via the USB device register interface.
  
              - Connect the USB device to the USB host model.
              - Enable the AON/Wake module, leaving it to maintain the pull up state.
              - Perform a Bus Reset, driving SE0 state onto the USB for at least 10us; the
                specification requires at least 10ms of Reset Signaling for a full reset, but the
                AON/Wake module should respond a lot faster, to allow time for chip start up and
                software reinitialization.
              - Check that the 'wake_req_aon_o' signal from the 'usbdev_aon_wake' module becomes
                asserted.
              - Read from the 'wake_events' CSR of the USB device and check that the 'bus_reset'
                bit is asserted.
              - Disable the AON/Wake module and verify that the USB device is still connected,
                i.e. the DP pullup is enabled and DP is high.

---

### <a id="aon_wake_disconnect"></a>66. aon_wake_disconnect
- **Estágio:** `V2`
- **Testes:** `usbdev_aon_wake_disconnect`
- **Descrição:**

  Verify that the AON/Wake module is able to detect Bus Disconnection and indicate that
              via the USB device register interface.
  
              - Connect the USB device to the USB host model.
              - Enable the AON/Wake module, leaving it to maintain the pull up state.
              - Verify that the DP pull up remains asserted, indicating the presence of the device
                on the USB.
              - Lower the VBUS/SENSE signal.
              - Check that the 'wake_req_aon_o' signal from the 'usbdev_aon_wake' module becomes
                asserted.
              - Read from the 'wake_events' CSR of the USB device and check that the 'disconnected'
                bit is asserted.
              - Check that the DP pull up is no longer asserted; it shall be dropped by the
                usbdev_aon_wake module to protect against spurious reconnection.
              - Disable the AON/Wake module and verify that the USB device remains disconnected.

---

### <a id="invalid_sync"></a>67. invalid_sync
- **Estágio:** `V2`
- **Testes:** `usbdev_invalid_sync`
- **Descrição:**

  Randomized interspersing of valid and invalid USB traffic. Generate bit-level changes
              on the USB that do not constitute valid SYNC signaling, interspersed with valid USB
              traffic to/from the device.
  
              - Set up the device with a single IN and a single OUT endpoint.
              - Fully populate the Available OUT Buffer FIFO.
              - Stream and check known traffic to (OUT) and from (IN) the device, with the CSR
                side simply returning unmodified every OUT packet that is received.
              - Randomly select whether to send an OUT packet, request an IN packet or generate
                invalid noise (never including a valid SYNC signal) on the USB.
              - Verify that all data has been streamed successfully, and that the USB device continued
                to operate correctly, ignoring all of the invalid signaling.

---

### <a id="spurious_pids_ignored"></a>68. spurious_pids_ignored
- **Estágio:** `V2`
- **Testes:** `usbdev_spurious_pids_ignored`
- **Descrição:**

  Check that the device ignores packets with unexpected tokens such as NYET, PRE...
              Also test ACK and NAK when not in response to a transmitted IN packet.
  
              - Randomly transmit valid token packets that use unexpected/unsupported PIDs and,
                in the case of ACK/NAK handshake packet that are out of sequence.
              - This is important in ensuring that the USB device/communications does not fail in
                the event of host handshake responses (to IN packets) being delayed.
              - Test all possible PIDs other than SETUP, OUT and IN, including invalid PIDs where
                the lower and upper nibbles are not complementary, and DATA0 and DATA1 PIDs without
                a preceding SETUP, OUT or IN token packet.

---

### <a id="low_speed_traffic"></a>69. low_speed_traffic
- **Estágio:** `V2`
- **Testes:** `usbdev_low_speed_traffic`
- **Descrição:**

  Test that Low Speed traffic on the bus in the downstream direction is appropriately
              ignored and does not cause the USB device to enter an invalid state.
              Background: Hubs are permitted to propagate downstream Low Speed signaling to Full
              Speed devices on other ports.
  
              - Connect the USB device, with a SETUP- and OUT-capable endpoint.
              - Repeatedly generate and check valid SETUP and OUT packets at Full Speed signaling
                speeds, whilst interspersing Full Speed traffic that consists of PRE tokens followed
                by randomized packet contents at Low Speed signaling.
              - Check that the USB device receives correctly all of the SETUP and OUT packets and is
                unaffected by the Low Speed signaling.
              - In particular, check that it does not generate unexpected interrupts because these
                could devalue the diagnostic use of those interrupts in detecting and reporting
                unreliable connections.

---

### <a id="rand_bus_resets"></a>70. rand_bus_resets
- **Estágio:** `V2`
- **Testes:** `usbdev_rand_bus_resets`
- **Descrição:**

  Ensure that all of SETUP, OUT and IN traffic are robust against randomized
              bus resets from the USB and that communications may successfully be resumed after
              subsequent reconfiguration.
  
              - Configure the USB device to receive SETUP, OUT and IN traffic (the regular
                Default Pipe, i.e. just Endpoint Zero, should suffice).
              - During the process of normal device configuration, issue a Bus Reset to the device at
                a random time (ensuring that it may occur during all transaction types), and then
                restart the configuration, checking that it completes successfully this time when no
                reset occurs.
              - The intention is to ensure that the internal state machines and logic do not get
                stuck or hold persistent inappropriate state.

---

### <a id="rand_disconnects"></a>71. rand_disconnects
- **Estágio:** `V2`
- **Testes:** `usbdev_rand_bus_disconnects`
- **Descrição:**

  Ensure that all of SETUP, OUT and IN traffic are robust against randomized
              disconnection of the USB and that communications may successfully be resumed after a
              bus reset and reconfiguration. (The bus reset should occur have a disconnection that
              was host-initiated, and before configuration traffic commences.)
  
              - Configure the USB device to receive SETUP, OUT and IN traffic (the regular
                Default Pipe, i.e. just Endpoint Zero should suffice).
              - During the process of normal device configuration, disconnect the USB at a random
                time (ensuring that it may occur during all transaction types), and then restart
                the configuration after a Bus Reset and check that
                configuration completes successfully this time when no disconnection occurs.

---

### <a id="rand_suspends"></a>72. rand_suspends
- **Estágio:** `V2`
- **Testes:** `usbdev_rand_suspends`
- **Descrição:**

  Deriving from the sequence 'usbdev_max_usb_traffic' ensure that traffic can be streamed
              back and forth successfully with the device being randomly suspended and resumed.

---

### <a id="max_usb_traffic"></a>73. max_usb_traffic
- **Estágio:** `V2`
- **Testes:** `usbdev_max_usb_traffic, usbdev_max_non_iso_usb_traffic`
- **Descrição:**

  Verify operation under maximal traffic to maximal endpoints, exercising all transfer
              types and all packet lengths, with randomized delays on the CSR side when receiving
              packets, supplying packets, making buffers available for use, and responding to
              interrupts.

---

### <a id="stress_usb_traffic"></a>74. stress_usb_traffic
- **Estágio:** `V2`
- **Testes:** `usbdev_stress_usb_traffic`
- **Descrição:**

  Derived from 'max_usb_traffic' this also randomly introduces unexpected token packets,
              low speed traffic, invalid traffic, bus resets and disconnects, to ensure that these do
              not interfere with the transmission and reception of valid traffic.

---

### <a id="in_packet_retraction"></a>75. in_packet_retraction
- **Estágio:** `V2`
- **Testes:** `usbdev_iso_retraction`
- **Descrição:**

  Exercise retraction of IN packets for Isochronous streams, prioritizing the delivery of
              the most recent data over the reliable delivery of all data presented.
  
              - Configure a single IN endpoint for Isochronous support.
              - Repeatedly poll for and collect IN packets from the USB host model, randomizing the
                delays between collection attempts.
              - Present a stream of Isochronous packets on the IN endpoint, with each packet containing
                a serial number. Randomize the times between packet presentations, and keep on the CSR
                side a record of which packets were retracted/overwritten rather than being transmitted
                successfully to the host.
              - Check that the CSR side and the USB host model agree on which packets were successfully
                transmitted from the device to the host.

---

### <a id="data_toggle_restore"></a>76. data_toggle_restore
- **Estágio:** `V2`
- **Testes:** `usbdev_data_toggle_restore`
- **Descrição:**

  Verify that each of the IN and OUT Data Toggle bits may be both set and cleared by
              software to ensure that resuming communications after returning from Deep Sleep
              is possible.
  
              - Ensure that the USB device disconnected (pull up not enabled) such that no
                communications shall occur with the device.
              - Set all of the even-numbered OUT Data Toggle bits to 1 and all of the odd-numbered
                OUT Data Toggle bits to 0.
              - Check that the OUT Data Toggle bits read as 0x555.
              - Set all of the even-numbered IN Data Toggle bits to 0 and all of the odd-numbered
                IN Data Toggle bits to 1.
              - Check that the IN Data Toggle bits read as 0xAAA.
              - Check that the OUT Data Toggle bits read as 0x555.
              - Invert all of the OUT Data Toggle bits.
              - Invert all of the IN Data Toggle bits.
              - Check that the OUT Data Toggle bits read as 0xAAA.
              - Check that the IN Data Toggle bits read as 0x555.
              - Set all of the OUT Data Toggle bits to random values.
              - Set all of the IN Data Toggle bits to random values.
              - Check that all of the OUT and IN Data Toggle bits read back as expected.
              - Test the interaction of USB traffic with the IN and OUT Data Toggle bits, but note
                that data toggle bits may only be toggled safely between packets.

---

### <a id="setup_priority"></a>77. setup_priority
- **Estágio:** `V2`
- **Testes:** `usbdev_setup_priority`
- **Descrição:**

  Verify that the final slot of the Rx FIFO is reserved for use by SETUP packets only.
              The final slot of the Rx FIFO buffer shall never be assigned to an OUT DATA packet
              because it could force the USB device to be unresponsive to a SETUP DATA packet.
  
              - Configure the USB device to receive SETUP packets on Endpoint Zero.
              - Configure endpoint 1 to receive OUT DATA packets.
              - Place 1 buffer in the Available SETUP Buffer FIFO.
              - Place 8 buffers in the Available OUT Buffer FIFO.
              - Transmit 7 OUT DATA packets to endpoint 1, checking that each packet is
                ACKed, but do not read from Rx FIFO.
              - Check that the Rx FIFO contains 7 buffers.
              - Transmit 1 OUT DATA packet to endpoint 1.
              - Verify that the OUT DATA packet is NAKed as expected.
              - Check that the Rx FIFO depth is still 7.
              - Transmit a SETUP DATA packet to Endpoint Zero, checking that the packet is ACKed.
              - Check that the Rx FIFO depth is now 8.
              - Read the packets from the Rx FIFO, checking the properties of each of the 7 OUT
                DATA packets and the final 1 SETUP DATA packet in turn.

---

### <a id="fifo_resets"></a>78. fifo_resets
- **Estágio:** `V2`
- **Testes:** `usbdev_fifo_rst`
- **Descrição:**

  Test the software-controlled FIFO reset functionality, introduced as a contingency
              for error recovery and to permit reconfiguration of the USB device hardware without
              resorting to use of the block-level asynchronous reset.
  
              - Populate the USBDEV FIFOs with packets randomly.
              - Choose a random set of FIFOs to reset.
              - Check the FIFO levels match expectations.
              - Note: the handling of the Received Buffer FIFO requires configuration of,
                and transmission of packets to, the USB device since there is no direct means
                to inject packets from the CSR side.

---

### <a id="tx_rx_disruption"></a>79. tx_rx_disruption
- **Estágio:** `V2`
- **Testes:** `usbdev_tx_rx_disruption`
- **Descrição:**

  Verify that the DUT is still capable of transmitting and receiving after a spontaneous
              disruption to the connection during transmission or reception, without requiring an
              IP block reset. On some implementations resetting of individual IP blocks may not be
              an option.
  
              Note that after a Bus Reset the USB host must restart the entire device addressing and
              configuration sequence, so the first transmissions will be SOF and SETUP packets.
  
              - Configure the device, choosing an endpoint and choose whether to transmit or receive.
              - Choose the moment at which the link reset shall occur.
              - Transmit/receive a partial transaction before instructing the driver to perform a
                USB Bus Reset.
              - Reconfigure the device _without_ resetting the block or even the FIFO state, since
                normally the software will rely upon its knowledge of the device state in handling
                a Bus Reset.
              - Retry transmission or reception to/from the device both to the previously-active
                endpoint and to a different endpoint to guard against persistent internal state.

---

### <a id="fifo_levels"></a>80. fifo_levels
- **Estágio:** `V2`
- **Testes:** `usbdev_fifo_levels`
- **Descrição:**

  Verify the DUT response to SETUP/OUT data packets under the various possible states of
              the Available OUT/SETUP Buffer FIFOs and Rx FIFO.
  
              - Choose levels for each of the FIFOs at random and populate the FIFOs accordingly,
                i.e. in the case of Av OUT/SETUP buffer FIFOs supply the appropriate number of buffers
                for use, and for the Rx FIFO send that number of SETUP DATA packets without removing
                them from the FIFO.
              - Use ascending endpoint numbers for each transmitted packet so that there is no issue
                of a data toggle mismatch leading to packet drops.
              - Choose at random whether to send a SETUP DATA packet, a regular OUT DATA packet or
                an Isochronous OUT DATA packet.
              - Predict the response of the device, which may be either ACK, NAK or no response.
              - Send the packet and verify that the DUT produces the expected response.

---

### <a id="rxenable_out_conditional"></a>81. rxenable_out_conditional
- **Estágio:** `V2`
- **Testes:** `usbdev_rxenable_out`
- **Descrição:**

  Test the conditional update functionality of the `rxenable_out` register. This register
              has been modified to accept changes conditionally, based upon corresponding 'preserve'
              bits being set in the upper half of the word written, in order to avoid a potential
              race hazard when the hardware is clearing the enable bit of another output endpoint
              because the `set_nak_out` functionality is in use.
  
              - Perform the following steps a number of times:
               - Read the current `rxenable_out` state.
               - Choose a random set of OUT endpoints to enable/disable.
               - Choose randomly for each such endpoint whether to enable/disable it.
               - Write the new enable state, using a `preserve` bit of 0 for only those endpoints
                 that shall be reconfigured, and a value of 1 for all other endpoints.

---

### <a id="dpi_config_host"></a>82. dpi_config_host
- **Estágio:** `V3`
- **Testes:** `usbdev_dpi_config_host`
- **Descrição:**

  Using the DPI model run the DUT through a typical configuration sequence consisting of
              Control Transfers that mimic the behavior of a physical USB host controller.
  
              - Connect the DUT to the USB and perform a Bus Reset.
              - Set up endpoint zero and read the Device Descriptor.
              - Set the device address.
              - Read the configuration descriptor.
              - Set the configuration.

---
