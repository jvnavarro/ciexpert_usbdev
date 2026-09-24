O **USB 2.0** opera sob uma arquitetura mestre-escravo estrita (*Host-centric*), onde nenhuma comunicação ocorre sem que o **Host** inicie o processo por meio de *polling*. Para o seu projeto com o módulo `usbdev` da OpenTitan (que é um periférico *Full-Speed* de 12 Mb/s operando com clock de 48 MHz), o funcionamento divide-se em quatro pilares principais:

---

### 1. Camada Física e Sinalização Elétrica (PHY)

A transmissão física de dados ocorre de maneira diferencial e half-duplex através de duas linhas, **D+** e **D-**, além da alimentação ($V_{\text{BUS}}$ de 5 V nominal) e Terra (GND).

* **Diferenciação de Velocidades por Biasing:**
* **Full-Speed (12 Mb/s):** O dispositivo conecta um resistor de *pull-up* $R_{\text{PU}}$ (nominalmente de $1{,}5\text{ k}\Omega$) na linha **D+**.


* **Low-Speed (15 Mb/s):** O *pull-up* fica na linha **D-**.


* **High-Speed (480 Mb/s):** Inicializa obrigatoriamente como Full-Speed e realiza um aperto de mão de *chirps* (Chirp K/J) durante o Reset para negociar a comutação para 480 Mb/s, desconectando o *pull-up* e ligando terminações de $45\,\Omega$ para terra em ambas as linhas.




* **Estados de Linha Essenciais:**
* **Differential 1 (Estado J em Full-Speed):** $\text{D+} > \text{D-}$.


* **Differential 0 (Estado K em Full-Speed):** $\text{D-} > \text{D+}$.


* **SE0 (Single-Ended Zero):** Ambas as linhas em nível lógico baixo ($\text{D+} < 0{,}8\text{ V}$ e $\text{D-} < 0{,}8\text{ V}$). Utilizado para sinalizar **Reset** (quando mantido por $> 10\text{ ms}$) e delimitador de fim de pacote (**EOP - End of Packet**) com 2 bit times.




* **Codificação e Integridade de Clock:**
* **NRZI (Non-Return-to-Zero Inverted):** Um bit `0` provoca transição de estado na linha; um bit `1` mantém o estado atual.


* **Bit Stuffing:** Como sequências longas de `1`s não gerariam transições elétricas (causando perda de sincronismo do receptor), a cada **seis bits `1` consecutivos**, o transmissor força a inserção de um bit `0` adicional. O receptor extrai esse bit automaticamente.





---

### 2. Formato e Estrutura dos Pacotes USB

Toda transmissão no cabo é empacotada e delimitada. Cada pacote possui a estrutura:
`[ SYNC ] + [ PID ] + [ Campos de Dados/Controle ] + [ CRC ] + [ EOP ]`

| Campo | Descrição |
| --- | --- |
| **SYNC** | Padrão alternado para travamento de clock do receptor (`00000001` em Full-Speed).

 |
| **PID (Packet ID)** | 8 bits (4 bits de identificador + 4 bits de checagem invertida de redundância) indicando o tipo do pacote.

 |
| **Payload/Campos** | Endereço (7 bits), Endpoint (4 bits), Frame Number ou dados úteis.

 |
| **CRC** | Polinômio de 5 bits (**CRC5**) para pacotes de controle/token e de 16 bits (**CRC16**) para pacotes de dados.

 |
| **EOP** | Single-Ended Zero (SE0) por 2 bit times seguido por 1 bit em estado J.

 |

**Principais Grupos de PID:**

1. **Token (enviados exclusivamente pelo Host):**
* `OUT`: O Host vai enviar dados para o periférico.


* `IN`: O Host requisita que o periférico transmita dados.


* `SETUP`: Inicia uma transferência de controle (configuração).


* `SOF (Start of Frame)`: Emitido a cada $1\text{ ms}$ (em Full-Speed) para sincronização temporal do barramento.




2. **Data:**
* `DATA0` e `DATA1`: Pacotes de carga útil que alternam o PID a cada transação bem-sucedida (*Data Toggle Synchronization*), permitindo descartar pacotes duplicados se um ACK for corrompido.




3. **Handshake:**
* `ACK`: Confirmação de recebimento sem erros de CRC.


* `NAK`: O periférico está ocupado, o buffer está cheio ou não há dados prontos (o Host deve tentar novamente mais tarde).


* `STALL`: O endpoint encontrou um erro funcional ou a requisição não é suportada (requer intervenção de software).





---

### 3. A Hierarquia do Protocolo: *Transfer $\rightarrow$ Transaction $\rightarrow$ Packet*

Na modelagem USB, as informações trafegam em três níveis de abstração:

```
Transferência (Transfer)
 └── Transação (Transaction)
      └── Pacote (Packet: Token + Data + Handshake)

```

1. **Pacote (Packet):** A menor unidade indivisível transmitida nos fios (ex.: apenas o pacote `IN` ou o pacote `DATA0`).


2. **Transação (Transaction):** O ciclo completo de serviço a um endpoint, tipicamente composto por 3 pacotes:


* *Fase de Token* (Host $\rightarrow$ Device)


* *Fase de Dados* (Host $\rightarrow$ Device ou Device $\rightarrow$ Host)


* *Fase de Handshake* (Receptor $\rightarrow$ Transmissor)




3. **Transferência (Transfer):** Uma operação completa de software (uma mensagem ou fluxo contínuo de buffer) composta por uma ou mais transações.



---

### 4. Os 4 Tipos de Transferência

Cada endpoint (*ponto de terminação lógico no periférico*) é configurado para um tipo específico de fluxo de dados:

* **Control Transfer:**
* Usada para enumeração, configuração e comandos da máquina de estados do dispositivo.


* Estrutura obrigatória em 3 estágios: **Setup Stage** (token SETUP + dados de 8 bytes com estrutura `bmRequestType`, `bRequest`, etc.), **Data Stage** opcional (leitura ou escrita) e **Status Stage** (confirmação em direção oposta).


* O endpoint 0 (`EP0`) é bidirecional e reservado exclusivamente para transferências de controle em todos os dispositivos.




* **Bulk Transfer:**
* Indicada para grandes volumes de dados não periódicos (ex.: pen drives, leitura/escrita em memórias).


* Garante integridade absoluta dos dados com detecção por CRC16 e retransmissões automáticas em caso de erro, mas sem garantia de latência ou largura de banda fixa.




* **Interrupt Transfer:**
* Destinada a dispositivos que enviam pequenas mensagens com limites garantidos de latência máxima (ex.: teclados, mouses, sensores).


* O Host pesquisa (*polls*) o endpoint em intervalos regulares definidos pelo descritor (`bInterval`).




* **Isochronous Transfer:**
* Para transmissões contínuas em tempo real (ex.: streaming de áudio e vídeo) com largura de banda pré-alocada.


* Prioriza a pontualidade: **não há fase de Handshake nem retransmissão**; pacotes corrompidos são simplesmente descartados pelo receptor.





---

### 5. Enumeração e Configuração do Dispositivo

Quando um dispositivo USB é conectado, o Host executa a **enumeração** através do `EP0`:

```
[Attach] 
   │ Detecção de pull-up em D+ (Full-Speed)
   ▼
[Reset do Barramento] 
   │ Host força SE0 por > 10 ms; Device assume Endereço 0x00
   ▼
[Get Descriptor (Device)] 
   │ Host lê os primeiros 8 bytes para descobrir o wMaxPacketSize do EP0
   ▼
[Set Address] 
   │ Host atribui um endereço exclusivo (1 a 127) ao dispositivo
   ▼
[Get Descriptors Completos] 
   │ Host lê Device, Configuration, Interface e Endpoint Descriptors
   ▼
[Set Configuration] 
   │ Host ativa a configuração desejada; endpoints adicionais tornam-se operacionais

```

---

### 6. Como isso se conecta ao seu Testbench UVM

No contexto do IP `usbdev` da OpenTitan:

* O seu **`uvm_driver`** assume o papel do **Host USB**, gerando as transições nos fios virtuais D+/D- ou nos sinais diferenciais da PHY (emitindo tokens, checando turn-around times e enviando/recebendo handshakes).


* O seu **agente de barramento de registros (TileLink-UL)** atua como o **processador/firmware**, configurando os CSRs do `usbdev`, alocando buffers na SRAM interna e lendo as interrupções de eventos recebidos.


* O **`uvm_scoreboard`** correlaciona os pacotes USB que entraram pelo barramento serial com os dados que o `usbdev` armazenou na memória interna via TileLink.