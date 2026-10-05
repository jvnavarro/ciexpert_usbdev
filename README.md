# Verificação do Módulo USB 2.0 (Projeto OpenTitan)

**Desenvolvedores:** Andreza Carneiro, João Navarro e Manoela Terra.

**Especificação Oficial:** [OpenTitan USBDEV](https://opentitan.org/book/hw/ip/usbdev/index.html)

---

## 1. Diagramas de Arquitetura

![Estrutura do repositório USBDEV](doc/usb_dev_repositorio.drawio.svg)
![Diagrama de Blocos](esquema_simples.drawio.svg)

### Topologia do Ambiente UVM

```text
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
                │                    │
 ───────────────┼────────────────────┼──────────────────────────  tb.sv
                │ usb20_if           │ tl_if        clk_rst_if (48 MHz)
                │ (D+, D-, sense)    │ (TL-UL)      clk_aon    (~200 kHz)
                ▼                    ▼              intr_if, alert_if
          ┌──────────────────────────────────────┐
          │              usbdev (DUT)            │
          │  usbdev_reg_top · usbdev_usbif ·     │
          │  usb_fs_nb_pe (rx/tx, in/out PE)     │
          └──────────────────────────────────────┘
```

---

## 2. Estrutura do Repositório

### `dv/agent/` (Agente USB 2.0)
*   `usb_transaction`: Item de transação com `pid`, `addr`, `endp` e payload `data[]`. Possui constraints limitando dados de 0 a 64 bytes, endpoints de 0 a 11 e restrição de payload para tokens (IN/OUT/SETUP).
*   `usb20_driver`: Converte o pacote lógico para pinos do DUT (`cio_usb_dp_i/dn_i`). Fluxo: Idle(J) -> SYNC -> PID(8b) -> ADDR/ENDP/CRC5 -> EOP.
*   `usb20_monitor`: Observa o barramento (host -> DUT) e encaminha pacotes via `analysis_port` para o scoreboard.
*   `usb20_sequencer`, `usb20_agent_cfg`, `usb20_agent`: Componentes padronizados herdados da CIP (`dv_base_agent`).
*   `usb20_basic_seq`: Sequência base que gera um pacote aleatório.

### `dv/env/` (Ambiente e Checagem)
*   `usbdev_env_cfg`: Configuração geral do ambiente, instanciação do RAL do módulo e restrição de clock fixo em 48 MHz.
*   `usbdev_env`: Estende `cip_base_env`. Instancia o agente USB e realiza as conexões TLM (sequencer ao virtual sequencer e monitor ao scoreboard).
*   `usbdev_scoreboard`: Recebe pacotes do monitor através do método `write_usb20` e realiza a checagem funcional.
*   `usbdev_virtual_sequencer`: Controla as execuções, contendo o handle do sequencer físico (`usb20_sequencer_h`).

### `dv/tests/` (Virtual Sequences e Testes)
*   `usbdev_base_test`: Teste raiz. A Virtual Sequence executada é definida por argumento de compilação (`TEST_SEQ`).
*   `usbdev_base_vseq`: Realiza inicialização (`dut_init`) via TL-UL (RAL): configura `usbctrl.enable=1`, `device_address=0x12` e `ep_out_enable[0]=1`.
*   `usbdev_smoke_vseq`: Exemplo inicial que executa a `usb20_basic_seq` diretamente no agente.

### `dv/tb/` (Testbench Top)
*   `tb.sv`: Instanciação do DUT e conexão das interfaces (clock/reset, barramento TL-UL, alertas, interrupções e `usb20_if`).
*   **Nota:** Os arquivos `top_pkg.sv` e `usb20_base_test.sv` pertencem à estrutura gerada inicialmente e não estão incluídos no `flist_tb.f`.

---

## 3. Makefile - dentro de dv

### Compilação e Simulação Básica
```bash
# 1. Compilar (gera out/simv e banco de cobertura out/simv.vdb)
make compile

# 2. Simular (a cada execução os dados são somados no banco de cobertura)
make sim SEED=1
make sim SEED=2 TEST_SEQ=usbdev_base_vseq
```
*O log de saída será gerado em: `out/sim_<vseq>_<seed>.log`*

### Análise de Cobertura (URG)
Para gerar relatórios agregando os resultados de todas as simulações executadas:
```bash
make cov
```
*   **Modo Gráfico:** Abra `out/urg_report/dashboard.html` no navegador (ex: `firefox out/urg_report/dashboard.html &`).
*   **Modo Texto:** O resumo aparece no terminal e no arquivo `out/urg_report/dashboard.txt`.

*(Comando manual alternativo, caso não utilize o Make: `urg -full64 -dir simv.vdb -report urg_report -format both`)*

### Ferramentas de Debug (Verdi)
```bash
# Abrir cobertura no Verdi
make cov_gui

# Gerar e visualizar formas de onda
make compile WAVE=1
make sim SEED=1      # Gera o arquivo out/sim_waves.fsdb
make wave            # Abre o Verdi com o arquivo gerado
```

**Variáveis do Makefile:** `TEST`, `TEST_SEQ`, `SEED`, `VERBOSITY`, `COV` (padrão = 1), `WAVE`, `GUI`, `PLUSARGS`.

*Nota de limpeza: O comando `make clean` remove todo o diretório `out/`, apagando o histórico de cobertura. Caso precise salvar um relatório definitivo, copie a pasta `out/urg_report/` para `doc/`.*

---

## 4. Desenvolvimento de Testes

**Fluxo de Dados:** Teste -> VSEQ (RAL + Sequences) -> Driver -> DUT -> Monitor -> Scoreboard.

**Como criar um novo cenário de teste:**
1. Crie o arquivo `dv/tests/usbdev_<nome>_vseq.sv` estendendo `usbdev_base_vseq`.
2. Implemente a lógica principal dentro da `task body()`.
3. Inclua o novo arquivo no pacote do ambiente (`dv/env/usbdev_env_pkg.sv`).
4. Execute passando o nome da sequência: `make compile && make sim TEST_SEQ=usbdev_<nome>_vseq`.


## 5. Mapeamento de Hardware e Registradores

### Sinais e Registradores (Geral)
| Categoria | Nome Oficial OpenTitan | Tipo | Descrição |
| --- | --- | --- | --- |
| **Sinais de Interface** | `clk_i` | Signal | Clock principal do sistema |
| | `rst_ni` | Signal | Reset ativo em nível baixo |
| | `clk_aon_i` | Signal | Clock Always-On (utilizado no wake-up) |
| | `rst_aon_ni` | Signal | Reset Always-On |
| **Interface USB** | `cio_usb_dp_i` / `cio_usb_dp_o` | Signal | Linha Data Plus (DP) - Entrada / Saída |
| | `cio_usb_dn_i` / `cio_usb_dn_o` | Signal | Linha Data Minus (DN) - Entrada / Saída |
| | `cio_usb_oe_o` | Signal | Output Enable do transceptor físico |
| | `cio_sense_i` | Signal | VBUS Sense (detecção de cabo conectado) |
| **Registradores de Controle** | `intr_state` | Register | Estado das interrupções do módulo |
| | `intr_enable` | Register | Habilitação das interrupções |
| | `intr_test` | Register | Teste forçado de interrupções |
| | `usbctrl` | Register | Controle principal (`enable`, `pe_en`, `device_address`) |
| | `usbstat` | Register | Status da conexão (`connected`, `link_state`, `frame`) |
| **Endpoints (Smoke Test)** | `ep_out_enable` | Register | Habilita endpoints de saída (OUT) |
| | `ep_in_enable` | Register | Habilita endpoints de entrada (IN) |
| | `rxenable_out` | Register | Habilita recepção nos endpoints OUT |
| **Buffers e FIFOs** | `avoutfifo` | Register | FIFO p/ fornecer buffers disponíveis p/ pacotes OUT |
| | `avsetupfifo` | Register | FIFO p/ fornecer buffers disponíveis p/ pacotes SETUP |
| | `rxfifo` | Register | FIFO de leitura dos pacotes recebidos pelo DUT |

### Estrutura do Registrador `usbctrl`
| Campo | Descrição |
| --- | --- |
| `enable` | Liga/desliga a Posição Física do Módulo (PHY) |
| `pe_en` | Habilita o Protocol Engine (mecanismo digital do USB) |
| `device_address` | Endereço USB atribuído ao periférico (7 bits) |

---
