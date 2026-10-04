#  Verificação do módulo USB 2.0 do projeto OpenTitan
Por Andreza Carneiro, João Navarro e Manoela Terra.

https://opentitan.org/book/hw/ip/usbdev/index.html

Ambiente de verificação UVM para o IP `usbdev` (USB 2.0 Full-Speed device) do
OpenTitan, construído sobre a **biblioteca CIP** (Comportable IP) do OpenTitan e
simulado com **Synopsys VCS** (ondas no **Verdi**).

---

## O que já foi feito

- **RTL do usbdev isolado** (`rtl/`) com as dependências mínimas do OpenTitan
  (`prim`, `tlul`, `top`) e filelist ordenado por dependência (`flist_rtl.f`).
- **Infraestrutura CIP importada** (`dv/cip_infra/`): `dv_lib`, `cip_lib`,
  `tl_agent`, `alert_esc_agent`, `csr_utils`, RAL do usbdev etc.
- **Agente USB 2.0 próprio** (`dv/agent/`), estendendo as classes base da CIP
  (`dv_base_agent`, `dv_base_driver`, `dv_base_monitor`):
  transação (`usb_transaction` com PID/addr/endp), cfg, sequencer, driver,
  monitor e uma sequência básica (`usb20_basic_seq`).
- **Env do usbdev** (`dv/env/`) estendendo `cip_base_env`: cfg, cobertura,
  scoreboard, virtual sequencer e o agente USB 2.0 instanciado e ligado ao
  virtual sequencer.
- **Testbench top** (`dv/tb/tb.sv`) com o DUT conectado ao `clk_rst_if`,
  `tl_if`, interface de alertas, interrupções e à `usb20_if`.
- **Smoke test rodando com o DUT**: `usbdev_base_test` + `usbdev_smoke_vseq`
  inicializa o DUT (reset + TL-UL via CIP) e dispara a `usb20_basic_seq` no
  agente USB → `TEST PASSED CHECKS`, 0 `UVM_ERROR` / 0 `UVM_FATAL`.

### Ainda é esqueleto / próximos passos

- Driver USB: recebe a transação mas **ainda não dirige os pinos** D+/D- (NRZI,
  bit stuffing, SYNC/EOP, CRC).
- Monitor USB: só sincroniza com o clock, **ainda não reconstrói pacotes**.
- Na `tb.sv` o barramento está fixo em idle (J state: D+ = 1, D- = 0) e VBUS
  presente; o driver deverá assumir esses sinais.
- Scoreboard: `process_tl_access` vazio; falta ligar a porta de análise do
  monitor USB e checar CSRs/pacotes.
- Cobertura (`usbdev_env_cov`) sem covergroups próprios.
- Sequências reais: SETUP/OUT/IN, configuração de endpoints via CSR, testes do
  `doc/testplan.md`.

---

## Como rodar

Os comandos são executados a partir de `dv/` (o `Makefile` de `dv/` é o atual;
ele chama o VCS a partir da raiz, onde estão os filelists).

```bash
cd dv
make            # compila + roda o smoke (usbdev_base_test + usbdev_smoke_vseq)
```

Se `vcs` não estiver no `PATH`, o Makefile faz `module load vcs/W-2024.09-SP2-3`
automaticamente.

| Comando | O que faz |
|---|---|
| `make` / `make run` | compila e simula |
| `make compile` | só compila (gera `out/simv`) |
| `make sim TEST_SEQ=<vseq>` | roda uma vseq com o binário já compilado |
| `make smoke` | atalho para o smoke test |
| `make run WAVE=1` | compila com dump FSDB (`out/sim_waves.fsdb`) |
| `make wave` | abre o Verdi com o FSDB |
| `make run GUI=1` | roda com a GUI do Verdi |
| `make clean` | apaga `out/` |
| `make help` | lista as variáveis |

Variáveis: `TEST` (padrão `usbdev_base_test`), `TEST_SEQ` (padrão
`usbdev_smoke_vseq`), `SEED` (padrão `1`), `VERBOSITY` (padrão `UVM_LOW`),
`WAVE`, `GUI`, `PLUSARGS`, `OUT_DIR` (padrão `dv/out`).

Exemplo:

```bash
make run SEED=42 VERBOSITY=UVM_HIGH WAVE=1
make wave
```

Saídas em `dv/out/`: `compile.log`, `sim_<TEST_SEQ>_<SEED>.log`, `simv`,
`sim_waves.fsdb`. Ao final o Makefile imprime `PASSED`/`FAILED` procurando
`TEST PASSED CHECKS` no log.

> Seguindo o fluxo da CIP, `TEST` escolhe a classe de teste (`+UVM_TESTNAME`) e
> `TEST_SEQ` escolhe a sequência virtual que ela executa (`+UVM_TEST_SEQ`). Para
> criar um teste novo normalmente basta escrever uma nova vseq — não é preciso
> uma nova classe de teste.

---

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

Fluxo do smoke test:

1. `tb.sv` publica as virtual interfaces no `uvm_config_db` e chama `run_test()`.
2. `cip_base_test` cria o env e, na `run_phase`, cria a vseq indicada em
   `+UVM_TEST_SEQ`.
3. `cip_base_vseq` executa `dut_init()` (reset via `clk_rst_if`, CSRs via
   `tl_agent`), depois o `body()` da vseq e por fim `dut_shutdown()`.
4. `usbdev_smoke_vseq::body()` inicia a `usb20_basic_seq` no
   `p_sequencer.usb20_sequencer_h`; o driver USB recebe e imprime a transação.

---

## Biblioteca CIP (`dv/cip_infra/`)

A CIP é a infraestrutura DV padrão do OpenTitan para "Comportable IPs" (IPs com
interface TL-UL, CSRs, interrupções e alertas). Herdar dela dá de graça reset,
acesso a registradores, checagem de interrupções/alertas e testes CSR comuns.

| Diretório | Conteúdo |
|---|---|
| `dv_utils` | macros (`dv_macros.svh`: `` `gfn ``, `` `DV_CHECK ``...), status de teste |
| `dv_lib` | classes base `dv_base_env/cfg/test/vseq/scoreboard` |
| `dv_base_agent` | `dv_base_agent/driver/monitor/sequencer/agent_cfg` — base do nosso agente |
| `dv_base_reg` | extensões da RAL do UVM (`dv_base_reg_block`) |
| `cip_lib` | `cip_base_env/test/vseq/scoreboard/env_cov` — camada usada pelo env do usbdev |
| `tl_agent` | agente TL-UL (acesso aos CSRs do DUT) |
| `alert_esc_agent` | agentes de alerta/escalonamento |
| `csr_utils` | `csr_rd`, `csr_wr`, `csr_spinwait` e testes CSR automáticos |
| `ral` | RAL gerada do usbdev (`usbdev_ral_pkg`) |
| `common_ifs` | `clk_rst_if`, `pins_if`, `prim_assert` |
| `mem_model`, `mem_bkdr_util` | modelo/acesso backdoor de memória (buffer de pacotes) |
| `push_pull_agent`, `sec_cm`, `str_utils`, `bus_params_pkg` | dependências da CIP |
| `usb20_agent_ref`, `usbdpi` | agente USB 2.0 e DPI originais do OpenTitan, usados só como referência |

Hierarquia de classes usada no projeto:

```
dv_base_test   → cip_base_test   → usbdev_base_test
dv_base_env    → cip_base_env    → usbdev_env
dv_base_env_cfg→ cip_base_env_cfg→ usbdev_env_cfg
dv_base_vseq   → cip_base_vseq   → usbdev_base_vseq → usbdev_smoke_vseq
dv_base_agent  → usb20_agent      (driver/monitor/sequencer/cfg idem)
```

Pontos de atenção ao estender a CIP:

- **Não sobrescrever `run_phase` do teste**: o `cip_base_test` já randomiza e
  inicia a vseq.
- O scoreboard **precisa** sobrescrever `process_tl_access` (a base dá fatal).
- O `usbdev_env_cfg::initialize()` define `list_of_alerts` (`fatal_fault`) e
  `num_interrupts` a partir da RAL.
- O `tl_if` deve ser publicado no caminho `*.env.m_tl_agent_usbdev_reg_block*`.

---

## Documentação

- `doc/testplan.md`, `doc/usbdev_testplan.hjson` — plano de testes
- `doc/funcionamento.md`, `doc/terms.md` — funcionamento do usbdev e termos USB
- `doc/guia_tlul_usbdev.md`, `doc/guia_endpoints_enderecamento.md`,
  `doc/guia_hub_broadcast_e_buffers.md` — guias de estudo
- `doc/guia_vnc_verdi_remoto.md` — acesso remoto ao Verdi
- `doc/usb-made-simple.pdf` — referência do protocolo
