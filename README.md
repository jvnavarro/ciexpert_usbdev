#  Verificação do módulo USB 2.0 do projeto OpenTitan
Por Andreza Carneiro, João Navarro e Manoela Terra.

https://opentitan.org/book/hw/ip/usbdev/index.html
## Estrutura do repositório

```
ciexpert_usbdev/
├── README.md
├── flist_rtl.f            # RTL do usbdev + prim/tlul/top (ordem de dependência)
├── flist_tb.f             # CIP lib + agente + env + testes + tb
├── Makefile               # Makefile antigo da raiz (use o de dv/)
├── doc/                   # testplan, guias (TL-UL, endpoints, buffers, Verdi/VNC)
├── rtl/
│   ├── usbdev/            # DUT: usbdev.sv, usbdev_usbif, usb_fs_rx/tx, PEs, regs
│   ├── prim/              # primitivas OpenTitan (fifo, flop, secded, ram...)
│   ├── tlul/              # barramento TL-UL
│   └── top/               # top_pkg, lc_ctrl_pkg
└── dv/
    ├── Makefile           # fluxo de compilação/simulação (VCS)
    ├── cip_infra/         # biblioteca CIP / DV do OpenTitan
    ├── agent/             # agente USB 2.0 do projeto
    │   ├── usb20_agent_pkg.sv
    │   ├── usb_transaction.sv   # item: pid, addr, endp
    │   ├── usb20_agent_cfg.sv
    │   ├── usb20_sequencer.sv
    │   ├── usb20_driver.sv
    │   ├── usb20_monitor.sv
    │   ├── usb20_agent.sv
    │   └── usb20_basic_seq.sv
    ├── env/
    │   ├── usbdev_env_pkg.sv    # inclui env + vseqs
    │   ├── usbdev_env_cfg.sv
    │   ├── usbdev_env_cov.sv
    │   ├── usbdev_scoreboard.sv
    │   ├── usbdev_virtual_sequencer.sv
    │   └── usbdev_env.sv
    ├── tests/
    │   ├── usbdev_test_pkg.sv
    │   ├── usbdev_base_test.sv
    │   ├── usbdev_base_vseq.sv
    │   └── usbdev_smoke_vseq.sv
    └── tb/
        ├── tb.sv          # top: DUT + interfaces + run_test()
        └── usb20_if.sv    # interface física USB (D+/D-, sense, enables)
```

`dv/tb/top_pkg.sv` e `dv/tb/usb20_base_test.sv` são da estrutura inicial e não
estão no `flist_tb.f`.

---
![Estrutura do repositório USBDEV](doc/usb_dev_repositorio.drawio.svg)

## Diagrama do ambiente

```
 usbdev_base_test  (cip_base_test)
 │   +UVM_TEST_SEQ=usbdev_smoke_vseq
 │
 └── usbdev_env  (cip_base_env)
     │
     ├── usbdev_env_cfg ──── RAL (usbdev_reg_block), usb20_agent_cfg
     ├── usbdev_env_cov
     ├── usbdev_virtual_sequencer ─────────────┐ usb20_sequencer_h
     │      ▲  usbdev_smoke_vseq               │
     │      │   └─ usb20_basic_seq ────────────┤
     ├── m_tl_agent (CIP) ───────────┐         │
     ├── alert agents (CIP)          │         │
     ├── usbdev_scoreboard           │         │
     │                               │         │
     └── m_usb20_agent (projeto)     │         │
         ├── usb20_sequencer ◄───────┼─────────┘
         ├── usb20_driver            │
         └── usb20_monitor           │
               │                     │
 ──────────────┼─────────────────────┼──────────────────────────  tb.sv
               │ usb20_if            │ tl_if        clk_rst_if (48 MHz)
               │ (D+, D-, sense)     │ (TL-UL)      clk_aon   (~200 kHz)
               ▼                     ▼              intr_if, alert_if
          ┌──────────────────────────────────────┐
          │              usbdev (DUT)            │
          │  usbdev_reg_top · usbdev_usbif ·     │
          │  usb_fs_nb_pe (rx/tx, in/out PE)     │
          └──────────────────────────────────────┘
```
![Diagrama simples para posteriomente ser modificado](esquema_simples.drawio.svg)

### Tabela de Mapeamento de Sinais e Registradores (`usbdev`)

| Categoria | Nome Oficial OpenTitan | Tipo | Descrição |
| --- | --- | --- | --- |
| **Sinais de Interface** | `clk_i` | Signal | Clock principal do sistema |
|  | `rst_ni` | Signal | Reset ativo em nível baixo |
|  | `clk_aon_i` | Signal | Clock Always-On (utilizado no wake-up) |
|  | `rst_aon_ni` | Signal | Reset Always-On |
| **Interface USB** | `cio_usb_dp_i` / `cio_usb_dp_o` | Signal | Linha Data Plus (DP) - Entrada / Saída |
|  | `cio_usb_dn_i` / `cio_usb_dn_o` | Signal | Linha Data Minus (DN) - Entrada / Saída |
|  | `cio_usb_oe_o` | Signal | Output Enable do transceptor físico |
|  | `cio_sense_i` | Signal | VBUS Sense (detecção de cabo conectado) |
| **Registradores de Controle** | `intr_state` | Register | Estado das interrupções do módulo |
|  | `intr_enable` | Register | Habilitação das interrupções |
|  | `intr_test` | Register | Teste forçado de interrupções |
|  | `usbctrl` | Register | Controle principal (`enable`, `pe_en`, `device_address`) |
|  | `usbstat` | Register | Status da conexão (`connected`, `link_state`, `frame`) |
| **Registradores do Smoke Test** | `ep_out_enable` | Register | Habilita endpoints de saída (OUT) |
|  | `ep_in_enable` | Register | Habilita endpoints de entrada (IN) |
|  | `rxenable_out` | Register | Habilita recepção nos endpoints OUT |
| **Buffers e FIFOs** | `avoutfifo` *(corrigido)* | Register | FIFO para fornecer buffers disponíveis para pacotes OUT |
|  | `avsetupfifo` *(corrigido)* | Register | FIFO para fornecer buffers disponíveis para pacotes SETUP |
|  | `rxfifo` | Register | FIFO de leitura dos pacotes recebidos |

---

### Mapeamento dos Campos Principais do Registrador `usbctrl` (Validado)

| Campo (`usbctrl`) | Descrição |
| --- | --- |
| `enable` | Liga/desliga a Posição Física do Módulo (PHY) |
| `pe_en` | Habilita o Protocol Engine (mecanismo digital do USB) |
| `device_address` | Endereço USB atribuído ao periférico (7 bits) |
