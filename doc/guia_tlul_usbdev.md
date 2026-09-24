# Guia Técnico: Barramento TileLink (TL-UL) Aplicado ao `usbdev` (OpenTitan)

Este documento detalha tudo o que é relevante sobre o barramento **TileLink Uncached-Lite (TL-UL)** para o entendimento, operação em firmware e verificação em UVM do controlador periférico USB 2.0 (**`usbdev`**) no projeto **`ciexpert_usbdev`**.

---

## 1. O que é o TL-UL e por que ele é usado?

O **TileLink Uncached-Lite (TL-UL)** é o barramento de interconexão síncrono *on-chip* adotado pelo OpenTitan. Ele é o equivalente direto ao **AXI4-Lite** ou **APB** da ARM, servindo como a ponte pela qual o processador (CPU / SoC) lê e escreve nos periféricos.

### Características Centrais
* **Uncached-Lite:** Não implementa coerência de cache nem transferências complexas em burst. Opera puramente no modelo **Requisição $\rightarrow$ Resposta** palavra a palavra (32 bits).
* **Dois Canais Independentes e Desacoplados:**

```
CPU (Host TL-UL)                               Periférico (usbdev)
       │                                                │
       │─────── Canal A: Requisição (a_valid / a_ready) ──────>│
       │        [a_opcode, a_address, a_data, a_mask]   │
       │                                                │
       │<────── Canal D: Resposta (d_valid / d_ready) ─────────│
       │        [d_opcode, d_data, d_error]             │
```

#### Sinais Relevantes do Canal A (Requisições da CPU):
* **`a_opcode`**: Tipo da operação:
  - `PutFullData` (`3'h0`): Escrita completa de 32 bits.
  - `PutPartialData` (`3'h1`): Escrita com máscara de bytes (`a_mask`).
  - `Get` (`3'h4`): Leitura de dados.
* **`a_address`**: Endereço acessado de 32 bits.
* **`a_data`**: Dados gravados pela CPU.
* **`a_valid` / `a_ready`**: Handshake. A transferência só ocorre no ciclo de clock em que ambos são `1` simultaneamente.

#### Sinais Relevantes do Canal D (Respostas do `usbdev`):
* **`d_opcode`**: Tipo de confirmação:
  - `AccessAck` (`3'h0`): Confirmação de que uma escrita foi concluída.
  - `AccessAckData` (`3'h1`): Resposta de leitura acompanhada dos dados em `d_data`.
* **`d_data`**: Dados lidos de registradores ou da memória SRAM.
* **`d_error`**: Sinalizador de erro de barramento (acesso a endereço inválido ou violação de integridade).

---

## 2. A Divisão dos 4 kB do `usbdev` (Roteamento Interno)

O `usbdev` é instanciado no chip com apenas uma interface escrava TL-UL (`tl_i` e `tl_o`), mas possui **duas entidades de hardware totalmente diferentes dentro de si**:
1. Os **Registradores de Controle e Estado (CSRs)**.
2. A **Memória SRAM de 2 kB** dos Buffers de Pacotes.

Para separar o tráfego, o arquivo [`rtl/usbdev/usbdev_reg_top.sv`](file:///home/jvnavarro/Área%20de%20trabalho/projects/handson/ciexpert_usbdev/rtl/usbdev/usbdev_reg_top.sv#L108-L141) implementa uma chave de roteamento 1:2 com o módulo `tlul_socket_1n` e a lógica combinacional `reg_steer`:

```systemverilog
// Trecho de rtl/usbdev/usbdev_reg_top.sv
always_comb begin
  reg_steer =
      tl_i.a_address[AW-1:0] inside {[2048:4095]} ? 1'd0 : // 0x800 a 0xFFF: Janela de SRAM
      1'd1;                                               // 0x000 a 0x7FF: Registradores CSR
```

```
                        Barramento TL-UL vindo da CPU
                                      │
                              [ tlul_socket_1n ]
                            (Lógica reg_steer)
                                      │
            ┌─────────────────────────┴─────────────────────────┐
            │ Se endereço for 0x000 a 0x7FF                     │ Se endereço for 0x800 a 0xFFF
            ▼                                                   ▼
   [ tlul_adapter_reg ]                               [ tlul_adapter_sram ]
   Registradores CSR do USB                          Janela da SRAM de Pacotes (2 kB)
   • USBCTRL, INTR_ENABLE                            • Buffer 0  (0x800 - 0x83F)
   • EP_IN_ENABLE, RXFIFO                            • Buffer 1  (0x840 - 0x87F)
   • CONFIGIN_0..11, etc.                            • ...
                                                     • Buffer 31 (0xFC0 - 0xFFF)
```

### Mapeamento dos 32 Buffers de Pacotes na Janela TL-UL

Cada buffer possui **64 bytes** ($0x40$ em hexadecimal). A CPU acessa os buffers diretamente no espaço de memória:

$$\text{Endereço Base do Buffer } N = 0x800 + (N \times 0x40)$$

| Buffer ID | Faixa de Endereços TL-UL | Capacidade | Uso Típico |
| :---: | :---: | :---: | :--- |
| **Buffer 0** | `0x800` a `0x83F` | 64 Bytes | Dados recebidos ou a transmitir |
| **Buffer 1** | `0x840` a `0x87F` | 64 Bytes | Dados recebidos ou a transmitir |
| **Buffer 2** | `0x880` a `0x8BF` | 64 Bytes | Dados recebidos ou a transmitir |
| ... | ... | ... | ... |
| **Buffer 31**| `0xFC0` a `0xFFF` | 64 Bytes | Último buffer da SRAM de 2 kB |

---

## 3. Disputa pela Memória: Arbitragem e Prioridade no Silício

A memória SRAM de pacotes do `usbdev` ([`prim_ram_1p_adv`](file:///home/jvnavarro/Área%20de%20trabalho/projects/handson/ciexpert_usbdev/rtl/usbdev/usbdev.sv#L863)) é uma memória de **Porta Única (Single-Port - 1P)**. Isso significa que fisicamente ela só executa **uma leitura OU uma escrita por ciclo de clock de 48 MHz**.

Dois mestres disputam essa memória:
1. **O Motor Serial USB (`usb_mem_b`):** Gravando bytes recebidos da linha serial ou lendo bytes para transmitir via TX.
2. **O Software / CPU via TL-UL (`sw_mem_a`):** Lendo os dados que chegaram ou gravando os dados que deseja enviar.

### A Regra de Ouro da Arbitragem
No arquivo [`rtl/usbdev/usbdev.sv`](file:///home/jvnavarro/Área%20de%20trabalho/projects/handson/ciexpert_usbdev/rtl/usbdev/usbdev.sv#L831-L833):

```systemverilog
// Concede acesso ao software SOMENTE quando não há requisição do hardware USB
assign sw_mem_a_gnt = !usb_mem_b_req;
```

* **O Hardware USB tem prioridade absoluta:** O sinal serial que vem pelo cabo não pode ser pausado (o Host manda dados em fluxo contínuo). Se o periférico atrasar a gravação na SRAM, haverá perda irreparável de dados (*buffer overrun*).
* **O que acontece se a CPU tentar acessar no mesmo ciclo?**  
  O adaptador TL-UL segura o handshake, mantendo `a_ready = 0` para o barramento por 1 ciclo. A CPU espera de forma imperceptível e o acesso é concluído no ciclo seguinte.
* **Por que isso quase nunca gera atraso para a CPU?**  
  O USB opera em Full-Speed a 12 Mbps, enquanto o clock interno é de 48 MHz. Como as transferências na SRAM ocorrem em palavras de 32 bits, o motor USB só precisa acessar a memória a cada $\approx 128$ ciclos de clock. A probabilidade matemática de colisão simultânea é inferior a **1%**.

---

## 4. Segurança e Integridade de Barramento (Bus Integrity)

Por se tratar de um IP projetado para segurança e resistência contra ataques físicos de injeção de falhas (*Fault Injection*):
* O barramento TL-UL no OpenTitan inclui bits de redundância e checagem: `a_user.cmd_intg` e `a_user.data_intg`.
* O decodificador [`usbdev_reg_top.sv`](file:///home/jvnavarro/Área%20de%20trabalho/projects/handson/ciexpert_usbdev/rtl/usbdev/usbdev_reg_top.sv#L908-L910) valida a paridade de cada comando recebido.
* Se um ataque ou falha de integridade for detectado no barramento TL-UL:
  1. O hardware bloqueia o comando.
  2. O IP dispara imediatamente um alerta de segurança fatal:
     ```systemverilog
     .intg_err_o (alerts[0]) // Conectado a alert_tx_o[0]
     ```

---

## 5. Como Isso se Aplica na Prática no Testbench UVM (`ciexpert_usbdev`)

No ambiente de verificação do projeto ([`flist_tb.f`](file:///home/jvnavarro/Área%20de%20trabalho/projects/handson/ciexpert_usbdev/flist_tb.f)):

### A. Para Acessar Registradores CSR (`0x000` a `0x7FF`)
Você **não** precisa instanciar comandos TL-UL brutos. Utiliza-se o modelo **RAL (Register Abstraction Layer)**:
```systemverilog
// Liga o dispositivo e configura o endereço via RAL
ral.usbctrl.enable.set(1'b1);
ral.usbctrl.device_address.set(7'd2);
ral.usbctrl.update(status); // O RAL converte isso em Canal A / Canal D do TL-UL automaticamente
```

### B. Para Acessar a SRAM de Pacotes (`0x800` a `0xFFF`)
Acessos à memória de dados são feitos direcionando transações TL-UL do tipo *Get* ou *PutFullData* diretamente para os endereços dos buffers:
```systemverilog
// Exemplo: Escrevendo 4 bytes (1 palavra) no início do Buffer 5 (endereço 0x800 + 5*64 = 0x940)
tl_access(
  .addr('h940),
  .write(1'b1),
  .data(32'hAABBCCDD),
  .mask(4'hF)
);

// Exemplo: Lendo a primeira palavra do Buffer 5
tl_access(
  .addr('h940),
  .write(1'b0),
  .data(rdata)
);
```

### C. O Ciclo do Software e a Interação TL-UL
```
1. (TL-UL Escrita)   -> Grava dados na SRAM (0x800 + N*64)
2. (TL-UL Escrita)   -> Arma o endpoint: CONFIGIN_x = {size, buffer=N, rdy=1}
3. [Linha USB]       -> Host envia Token IN e recebe dados do Buffer N
4. [Hardware USB]    -> Gera interrupção intr_pkt_sent_o
5. (TL-UL Leitura)   -> CPU lê IN_SENT para confirmar transmissão
6. (TL-UL Escrita)   -> CPU limpa flag em IN_SENT
```

---

## 6. Resumo Executivo

| Conceito | Comportamento no `usbdev` |
| :--- | :--- |
| **Interface TL-UL** | 1 porta escrava TL-UL (Canal A para requisições, Canal D para respostas). |
| **Divisão de Endereços** | `< 0x800`: Registradores CSR.<br>`>= 0x800` e `< 0x1000`: Janela de 2 kB da SRAM de Pacotes. |
| **Prioridade de Memória**| **O Hardware USB tem prioridade máxima** sobre a CPU em caso de colisão de acesso à SRAM. |
| **Acesso em Verificação**| Registradores são acessados via **RAL**; buffers da SRAM são acessados via leituras/escritas diretas com o `tl_agent`. |
