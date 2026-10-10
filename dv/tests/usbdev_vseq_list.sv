// Lista das sequencias virtuais do usbdev (incluida pelo usbdev_env_pkg).
//
// Fluxo de trabalho:
//   1. Crie sua branch a partir da main.
//   2. Crie o arquivo tests/usbdev_<nome>_vseq.sv estendendo usbdev_base_vseq.
//   3. Adicione UMA linha de include no FINAL desta lista.
//   4. Rode so o seu teste: make TEST_SEQ=usbdev_<nome>_vseq
//
// A usbdev_base_vseq precisa ser a primeira (todas as outras estendem dela).
`include "usbdev_base_vseq.sv"
