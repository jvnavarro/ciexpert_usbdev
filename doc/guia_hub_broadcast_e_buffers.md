# Guia Complementar: Hubs USB, Barramento Compartilhado (Broadcast) e Buffers SRAM (OpenTitan `usbdev`)

Este documento complementa o [`guia_endpoints_enderecamento.md`](file:///home/jvnavarro/Área%20de%20trabalho/projects/handson/ciexpert_usbdev/doc/guia_endpoints_enderecamento.md), aprofundando as dúvidas essenciais sobre o funcionamento interno de **Hubs USB**, a recepção por **Broadcast em Barramento Compartilhado**, o dimensionamento de **Buffers de 64 Bytes** e o mapeamento da **SRAM de 2 kB no barramento TileLink (TL-UL)**.

---

## 1. Como Funciona um Hub USB: Ele Tem Vários Endpoints?

**Não! Um Hub USB geralmente possui apenas DOIS endpoints: `EP0` e `EP1 IN`.**

Existe um mito comum de que, ao conectar 4 periféricos em um Hub de 4 portas, o Hub precisaria "acumular" ou "gerenciar" dezenas de endpoints. No protocolo USB 2.0, a arquitetura foi desenhada para que o Hub seja **transparente para o tráfego dos periféricos**.

```
                  Cabo vindo do Host (PC)
                             │
            ┌────────────────┴────────────────┐
            │             HUB USB             │
            │                                 │
            │   ┌─────────────────────────┐   │
            │   │      Hub Controller     │   │
            │   │ (Seu próprio periférico)│   │
            │   │   • EP0 (Controle)      │   │
            │   │   • EP1 IN (Status)     │   │
            │   └────────────┬────────────┘   │
            │                │                │
            │   ┌────────────┴────────────┐   │
            │   │  Hub Repeater / Roteador│   │
            │   │    (Hardware Elétrico)  │   │
            │   └──────┬──────┬─────┬─────┘   │
            └──────────┼──────┼─────┼─────┼───┘
                       │      │     │     │
                    Porta 1 Porta 2 ... Porta 4
                       │      │
                   [Mouse] [Teclado]
```

Um Hub é dividido internamente em dois blocos totalmente distintos:

### A. Repetidor de Hardware (Hub Repeater / Forwarder)
* É uma ponte de hardware elétrica quase puramente combinacional.
* Quando o Host envia pacotes para um dispositivo downstream (ex.: o Mouse na Porta 1), esse tráfego **NÃO passa por nenhum endpoint do Hub**.
* O repetidor simplesmente **retransmite os pulsos elétricos** de $D^+$ e $D^-$ do cabo principal (*upstream*) para as portas ativas (*downstream*), e devolve a resposta do periférico diretamente para o Host.

### B. Controlador do Hub (Hub Controller)
O próprio Hub é um periférico USB com seu próprio endereço (`ADDR = 1`), mas ele só executa funções de gerência básica:
* **`EP0` (Control Pipe):** O Host usa para ligar energia nas portas individuais, desligar energia ou forçar o sinal elétrico de Reset (`SE0`) em uma porta específica quando um novo dispositivo é plugado.
* **`EP1 IN` (Interrupt Pipe - Notificação de Status):** O Host consulta esse endpoint periodicamente. Se o usuário espetar um pendrive na Porta 2, o Hub responde no `EP1 IN` com um bitmap de status: *"Houve evento de conexão na Porta 2!"*. O Host então lê o aviso e inicia a enumeração daquela porta.

---

## 2. A Ilusão do "Cabo Único": Como o Dispositivo Sabe que o Pacote é para Ele?

Se o repetidor do Hub joga o mesmo sinal elétrico para todas as portas ao mesmo tempo, como o Mouse e o Teclado não se confundem?

### O Princípio do Walkie-Talkie (Broadcasting com Filtragem em Silício)
O barramento USB é um meio compartilhado (*broadcast*). Todos os dispositivos escutam as mesmas transições de tensão nas linhas $D^+$ e $D^-$. A diferenciação ocorre através do cabeçalho do pacote **TOKEN**:

$$\mathbf{[SYNC]}\ +\ \mathbf{[PID:\ OUT/IN/SETUP]}\ +\ \mathbf{[ADDR:\ 7\ bits]}\ +\ \mathbf{[ENDP:\ 4\ bits]}\ +\ \mathbf{[CRC5]}\ +\ \mathbf{[EOP]}$$

```
        Host envia Token na linha: [PID = IN, ADDR = 2, ENDP = 1]
                                     │
                             (Repetidor do Hub)
                                     │
           ┌─────────────────────────┴─────────────────────────┐
           │ (mesmo sinal elétrico)                            │ (mesmo sinal elétrico)
           ▼                                                   ▼
     [ MOUSE (ADDR = 2) ]                                [ TECLADO (ADDR = 3) ]
  Compara: ADDR recebido (2)                          Compara: ADDR recebido (2)
           == meu endereço (2)?                                == meu endereço (3)?
             SIM! (É para mim!)                                  NÃO! (Não é comigo!)
                  │                                                   │
  O hardware processa o pacote e                      O hardware simplesmente DESCARTA
  transmite os dados para o cabo.                     e mantém as linhas em silêncio.
```

### O Filtro no RTL da OpenTitan
No circuito do nosso projeto ([`rtl/usbdev/usb_fs_nb_in_pe.sv`](file:///home/jvnavarro/Área%20de%20trabalho/projects/handson/ciexpert_usbdev/rtl/usbdev/usb_fs_nb_in_pe.sv#L135-L140) e [`rtl/usbdev/usb_fs_nb_out_pe.sv`](file:///home/jvnavarro/Área%20de%20trabalho/projects/handson/ciexpert_usbdev/rtl/usbdev/usb_fs_nb_out_pe.sv#L134-L139)):

```systemverilog
assign token_received =
  rx_pkt_end_i &&
  rx_pkt_valid_i &&
  rx_pid_type == UsbPidTypeToken &&
  rx_addr_i == dev_addr_i;  // Se rx_addr_i != dev_addr_i, token_received = 0!
```

Se o endereço não for dele:
* O hardware não gera interrupções.
* O hardware não altera nenhum registrador.
* **Os drivers de saída elétricos ($D^+, D^-$) permanecem desabilitados (alta impedância / Tri-state).**
* Como apenas **um** dispositivo no barramento reconhece o `ADDR`, apenas ele aciona os transistores de transmissão para responder. **Resultado:** zero colisão no cabo.

---

## 3. Dimensionamento de Buffers: Quantos Pacotes Cabem em 64 Bytes?

**Exatamente 1 pacote (ou o payload de 1 pacote)!**

A relação na arquitetura da OpenTitan é estritamente:
$$\mathbf{1\ Buffer\ de\ 64\ Bytes} = \mathbf{1\ Pacote\ de\ Dados}$$

### Por que os pacotes não são agrupados no mesmo buffer?
1. **Tamanho Máximo da Norma (Max Packet Size):** Em USB 2.0 Full-Speed (12 Mbps), o tamanho máximo de payload para transferências de Controle, Bulk e Interrupção é de **64 bytes**. Um pacote de 64 bytes ocupa o buffer completo.
2. **Pacotes Menores Consomem 1 Buffer Inteiro:**
   - Um pacote `SETUP` de 8 bytes consome **1 buffer inteiro de 64B** (os 56 bytes restantes ficam vazios).
   - Um pacote de mouse de 4 bytes consome **1 buffer inteiro de 64B**.
   - Um pacote de tamanho zero (ZLP - *Zero-Length Packet*, 0 bytes) consome **1 buffer** (ou entrada na FIFO) para registrar que a transferência foi concluída.
3. **Simplicidade de Endereçamento em Silício:**
   Ao fixar cada slot em exatamente $64\text{ bytes} = 2^6\text{ bytes}$, o cálculo de endereço de memória na SRAM não precisa de multiplicadores ou somadores complexos. É uma simples concatenação de fios no RTL ([`usbdev_usbif.sv`](file:///home/jvnavarro/Área%20de%20trabalho/projects/handson/ciexpert_usbdev/rtl/usbdev/usbdev_usbif.sv#L229)):
   ```systemverilog
   assign mem_waddr = {av_rdata, out_max_used_q[PktW-1:2]};
   // av_rdata: ID do buffer (0 a 31 -> 5 bits)
   // out_max_used_q[5:2]: endereço da palavra de 32 bits dentro do buffer de 64 bytes (4 bits)
   // Endereço total na SRAM: 9 bits (512 palavras de 32 bits)
   ```

### E como transferir arquivos grandes (ex.: 1.000 Bytes)?
O software e a pilha USB dividem a transferência em múltiplos pacotes de até 64B:
$$\text{Transferência de 1.000 Bytes} \rightarrow 15\text{ pacotes de }64\text{ B} + 1\text{ pacote residual de }40\text{ B} = \mathbf{16\ pacotes}$$
Cada pacote recebido consome um ID da fila `AVOUT_FIFO` e é gravado em um buffer de 64B diferente na SRAM.

---

## 4. O Mapeamento da SRAM no Barramento do SoC (TileLink TL-UL)

No módulo top-level de registradores ([`rtl/usbdev/usbdev_reg_top.sv`](file:///home/jvnavarro/Área%20de%20trabalho/projects/handson/ciexpert_usbdev/rtl/usbdev/usbdev_reg_top.sv#L131-L141)), podemos ver com extrema clareza a divisão entre os registradores de controle (CSRs) e a memória SRAM de pacotes:

```systemverilog
// Roteamento inteligente de endereços no TileLink (TL-UL)
always_comb begin
  reg_steer =
      tl_i.a_address[AW-1:0] inside {[2048:4095]} ? 1'd0 : // 0x800 a 0xFFF: Memória SRAM de Pacotes (2 kB)
      1'd1;                                               // 0x000 a 0x7FF: Registradores CSR de Controle
```

```
Espaço de Endereçamento do usbdev (TileLink):
┌────────────────────────────────────────────────────────┐
│ 0x0000 - 0x07FF: Registradores CSR                    │
│   • USBCTRL, INTR_ENABLE, EP_IN_ENABLE, RXFIFO, etc.   │
├────────────────────────────────────────────────────────┤
│ 0x0800 - 0x0FFF: Janela da SRAM de Pacotes (2 kB)      │
│   • Buffer 0:  0x800 - 0x83F  (64 bytes)              │
│   • Buffer 1:  0x840 - 0x87F  (64 bytes)              │
│   • ...                                                │
│   • Buffer 31: 0xFC0 - 0xFFF  (64 bytes)              │
└────────────────────────────────────────────────────────┘
```

### Por que essa separação é importante?
1. **Acesso Direto da CPU sem Cópias Intermediárias:** A CPU lê os dados recebidos ou grava os dados a transmitir diretamente nos endereços de `0x800` a `0xFFF` usando instruções normais de *Load/Store* do processador.
2. **Arbitragem sem Bloqueios:** O socket TileLink (`tlul_socket_1n`) direciona os acessos de configuração para o adaptador de registradores (`tlul_adapter_reg`) e os acessos de dados para a janela de SRAM (`tl_win_o`), garantindo alto throughput para o subsistema USB.

---

## 5. Resumo Comparativo Rápido

| Pergunta / Dúvida | Resposta Técnica Curta | Detalhe no Hardware |
| :--- | :--- | :--- |
| **O Hub tem muitos endpoints?** | **Não**, tem quase sempre apenas `EP0` e `EP1 IN`. | O tráfego dos periféricos passa direto pelo repetidor elétrico do Hub sem consumir endpoints. |
| **Como o dispositivo sabe que o pacote é para ele?** | Pelo campo **`ADDR`** (7 bits) dentro do Token transmitido no barramento. | A SIE só aceita o pacote se `rx_addr_i == dev_addr_i`. Demais dispositivos ficam em silêncio elétrico. |
| **Quantos pacotes cabem em um buffer de 64B?** | **Exatamente 1 pacote**. | A OpenTitan gerencia a SRAM em slots fixos de 64 bytes (`32 buffers x 64B = 2 kB`). |
| **Onde a CPU acessa esses buffers?** | Na janela de memória de `0x800` a `0xFFF`. | Roteado pela lógica `reg_steer` do decodificador TileLink `usbdev_reg_top.sv`. |
