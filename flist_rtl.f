// ==============================================================================
// Filelist: RTL usbdev e dependencias (OpenTitan)
// ==============================================================================

// Include directories para macros e headers
+incdir+rtl/prim
+incdir+rtl/tlul
+incdir+rtl/usbdev

// 1. Packages Primitivos e de Suporte (Ordem de Dependencia)
rtl/prim/prim_util_pkg.sv
rtl/prim/prim_count_pkg.sv
rtl/prim/prim_mubi_pkg.sv
rtl/prim/prim_secded_pkg.sv
rtl/prim/prim_alert_pkg.sv
rtl/prim/prim_esc_pkg.sv
rtl/prim/prim_subreg_pkg.sv
rtl/prim/prim_ram_1p_pkg.sv
rtl/prim/prim_ram_2p_pkg.sv

// 2. Packages Top e TL-UL
rtl/top/top_pkg.sv
rtl/top/lc_ctrl_pkg.sv
rtl/top/lc_ctrl_reg_pkg.sv
rtl/top/lc_ctrl_state_pkg.sv
rtl/tlul/tlul_pkg.sv

// 3. Packages USBDEV
rtl/usbdev/usb_consts_pkg.sv
rtl/usbdev/usbdev_pkg.sv
rtl/usbdev/usbdev_reg_pkg.sv

// 4. Modulos Primitivos (prim)
rtl/prim/prim_assert.sv
rtl/prim/prim_buf.sv
rtl/prim/prim_clock_mux2.sv
rtl/prim/prim_count.sv
rtl/prim/prim_diff_decode.sv
rtl/prim/prim_edge_detector.sv
rtl/prim/prim_fifo_sync.sv
rtl/prim/prim_fifo_sync_cnt.sv
rtl/prim/prim_filter.sv
rtl/prim/prim_flop.sv
rtl/prim/prim_flop_2sync.sv
rtl/prim/prim_flop_macros.sv
rtl/prim/prim_intr_hw.sv
rtl/prim/prim_onehot_check.sv
rtl/prim/prim_pulse_sync.sv
rtl/prim/prim_ram_1p.sv
rtl/prim/prim_ram_1p_adv.sv
rtl/prim/prim_reg_cdc.sv
rtl/prim/prim_reg_cdc_arb.sv
rtl/prim/prim_reg_we_check.sv
rtl/prim/prim_sec_anchor_buf.sv
rtl/prim/prim_sec_anchor_flop.sv
rtl/prim/prim_secded_inv_39_32_dec.sv
rtl/prim/prim_secded_inv_39_32_enc.sv
rtl/prim/prim_secded_inv_64_57_dec.sv
rtl/prim/prim_secded_inv_64_57_enc.sv
rtl/prim/prim_subreg.sv
rtl/prim/prim_subreg_arb.sv
rtl/prim/prim_subreg_ext.sv
rtl/prim/prim_sync_reqack.sv
rtl/prim/prim_usb_diff_rx.sv
rtl/prim/prim_xnor2.sv
rtl/prim/prim_alert_sender.sv

// 5. Modulos TL-UL
rtl/tlul/tlul_adapter_host.sv
rtl/tlul/tlul_adapter_reg.sv
rtl/tlul/tlul_adapter_reg_racl.sv
rtl/tlul/tlul_adapter_sram.sv
rtl/tlul/tlul_adapter_sram_racl.sv
rtl/tlul/tlul_assert.sv
rtl/tlul/tlul_cmd_intg_chk.sv
rtl/tlul/tlul_cmd_intg_gen.sv
rtl/tlul/tlul_data_integ_dec.sv
rtl/tlul/tlul_data_integ_enc.sv
rtl/tlul/tlul_err.sv
rtl/tlul/tlul_err_resp.sv
rtl/tlul/tlul_fifo_async.sv
rtl/tlul/tlul_fifo_sync.sv
rtl/tlul/tlul_lc_gate.sv
rtl/tlul/tlul_rsp_intg_chk.sv
rtl/tlul/tlul_rsp_intg_gen.sv
rtl/tlul/tlul_socket_1n.sv
rtl/tlul/tlul_socket_m1.sv
rtl/tlul/tlul_sram_byte.sv

// 6. Modulos USBDEV (RTL Top e Submodulos)
rtl/usbdev/usbdev_aon_wake.sv
rtl/usbdev/usbdev_counter.sv
rtl/usbdev/usbdev_iomux.sv
rtl/usbdev/usbdev_linkstate.sv
rtl/usbdev/usb_fs_nb_in_pe.sv
rtl/usbdev/usb_fs_nb_out_pe.sv
rtl/usbdev/usb_fs_nb_pe.sv
rtl/usbdev/usb_fs_rx.sv
rtl/usbdev/usb_fs_tx_mux.sv
rtl/usbdev/usb_fs_tx.sv
rtl/usbdev/usbdev_usbif.sv
rtl/usbdev/usbdev_reg_top.sv
rtl/usbdev/usbdev.sv
