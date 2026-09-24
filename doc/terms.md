### 1. Camada Física e Sinalização Elétrica (PHY)

* **D+ / D-**: Linhas de dados diferenciais que formam o canal bidirecional *half-duplex* do USB.


* **$V_{\text{BUS}}$**: Linha de alimentação de 5 V DC fornecida pelo Host aos dispositivos do barramento.


* **Estado J e Estado K**: Estados lógicos diferenciais do barramento. Em *Full-Speed*, o estado J ocorre quando $\text{D+} > \text{D-}$, e o estado K quando $\text{D-} > \text{D+}$.


* **SE0 (Single-Ended Zero)**: Condição elétrica em que ambas as linhas ($\text{D+}$ e $\text{D-}$) são mantidas em nível lógico baixo ($< 0{,}8\text{ V}$). Sinaliza eventos de controle como Reset e delimita pacotes.


* **SE1 (Single-Ended One)**: Condição em que ambas as linhas estão em nível alto; é um estado proibido e considerado inválido pela especificação USB 2.0.


* **NRZI (Non-Return-to-Zero Inverted)**: Método de codificação serial em que o bit `0` provoca uma transição de nível no barramento e o bit `1` mantém o nível anterior sem transição.


* **Bit Stuffing**: Inserção automática de um bit `0` após seis bits `1` consecutivos na transmissão serial para forçar transições de sinal e manter o PLL/clock do receptor sincronizado.


* **Squelch**: Condição detectada pelo receptor quando a amplitude do sinal diferencial cai abaixo de um limiar mínimo, indicando ausência de sinal válido ou repouso da linha.


* **Chirp J / Chirp K**: Tons de sinalização diferencial contínua utilizados no aperto de mão (*handshake*) durante o Reset para negociar a transição de Full-Speed para High-Speed.


* **$R_{\text{PU}}$ (Pull-Up Resistor)**: Resistor conectado em D+ (para Full-Speed) ou D- (para Low-Speed) pelo periférico para anunciar sua conexão e indicar sua velocidade ao Host.


* **$R_{\text{PD}}$ (Pull-Down Resistor)**: Resistores de terminação para o terra (GND) presentes nas portas downstream do Host/Hub nas linhas D+ e D-.



---

### 2. Pacotes e Protocolo de Baixo Nível

* **PID (Packet Identifier)**: Byte que abre o pacote (composto por 4 bits de tipo e 4 bits de checagem complementar invertida) definindo a função do pacote.


* **SYNC**: Sequência inicial de sincronização transmitida para permitir que o receptor trave seu circuito de recuperação de clock.


* **EOP (End of Packet)**: Delimitador de fim de pacote composto por um padrão SE0 de 2 bit times seguido pelo estado J.


* **CRC5 e CRC16 (Cyclic Redundancy Check)**: Códigos de redundância cíclica de 5 bits (usados em Tokens) e 16 bits (usados em pacotes de Dados) para detecção de erros de transmissão.


* **Data Toggle Synchronization**: Alternância do identificador de pacotes de dados entre `DATA0` e `DATA1` para garantir sincronismo e descarte de duplicatas em caso de falha de confirmação.


* **Turn-around Time**: Intervalo de tempo necessário para que o transmissor libere a linha e o receptor passe a transmitir sem colisões.


* **Inter-packet Gap**: Intervalo mínimo de repouso exigido entre o término de um pacote (EOP) e o início do próximo pacote (SYNC).



---

### 3. Tipos de Pacotes (PIDs Principais)

* **Tokens (Emitidos pelo Host)**:


* **SETUP**: Inicia uma transferência de controle para configuração e envio de comandos ao dispositivo.


* **OUT**: Indica que o Host transmitirá dados para o dispositivo na fase seguinte.


* **IN**: Solicita que o dispositivo transmita dados de volta ao Host.


* **SOF (Start of Frame)**: Marcador temporal periódico (a cada 1 ms em Full-Speed) transmitido para sincronizar a cadência do barramento.


* **PING**: Token de sondagem de alta velocidade para checar se o endpoint possui buffer livre antes do envio de dados.




* **Data (Carga Útil)**:


* **DATA0 / DATA1**: Pacotes de dados com alternância de toggle.


* **DATA2 / MDATA**: Pacotes de dados usados em transações de alta largura de banda e transações divididas (*split*).




* **Handshake (Confirmação de Recepção)**:


* **ACK**: Confirmação positiva de recebimento sem erros de CRC.


* **NAK**: Resposta indicando que o endpoint está temporariamente ocupado, sem buffer disponível ou sem dados para enviar.


* **STALL**: Indica que o endpoint está travado em falha (*halted*) ou que a requisição recebida não é suportada pelo firmware.


* **NYET**: Resposta indicando que o dado foi aceito, mas o endpoint ainda não está pronto para a transação seguinte.





---

### 4. Arquitetura Lógica e Fluxo de Dados

* **Endpoint (EP)**: Ponto de terminação lógico e individual dentro do chip periférico que atua como produtor ou consumidor de dados.


* **Endpoint 0 (EP0)**: Ponto de terminação bidirecional padrão obrigatório em todo dispositivo USB, dedicado à enumeração e configuração.


* **Pipe**: Abstração de conexão lógica entre o software cliente no Host e um Endpoint específico no dispositivo.


* **Transfer Types (Tipos de Transferência)**:


* **Control Transfer**: Transferência estruturada em três fases (*Setup*, *Data*, *Status*) para comandos e configuração de descritores.


* **Bulk Transfer**: Transferência não periódica de grandes volumes de dados com garantia de integridade (CRC e retransmissão), mas sem garantia de banda ou latência.


* **Interrupt Transfer**: Transferência periódica de pequenas mensagens com garantia de latência máxima delimitada por polling.


* **Isochronous Transfer**: Transferência contínua em tempo real com largura de banda fixa pré-alocada, sem confirmação (Handshake) nem retransmissões.




* **Frame e Microframe**: Base de tempo periódica de 1 ms no barramento Full-Speed/Low-Speed (*Frame*) e de 125 µs no barramento High-Speed (*Microframe*).


* **IRP (I/O Request Packet)**: Estrutura abstrata de software pela qual o sistema operacional solicita uma transferência completa de dados para um Pipe.


* **Split Transaction**: Mecanismo que permite que pacotes Full-Speed e Low-Speed trafeguem por hubs High-Speed através de tokens especiais (*SSPLIT* e *CSPLIT*).



---

### 5. Configuração e Descritores (Device Framework)

* **Enumeração (Bus Enumeration)**: Processo contínuo em que o Host detecta a inserção física, atribui um endereço exclusivo (1 a 127) e lê os descritores do periférico.


* **Standard Requests**: Comandos padrão do protocolo enviados via EP0, incluindo `GET_DESCRIPTOR`, `SET_ADDRESS`, `SET_CONFIGURATION` e `CLEAR_FEATURE`.


* **Descritores Principais**:


* **Device Descriptor**: Informações gerais do hardware (IDs de Fabricante `idVendor`, Produto `idProduct` e versão `bcdUSB`).


* **Configuration Descriptor**: Parâmetros de consumo energético (`bMaxPower`) e número de interfaces.


* **Interface Descriptor**: Coleção de endpoints agrupados para executar uma função específica do dispositivo.


* **Endpoint Descriptor**: Propriedades do canal (número, direção IN/OUT, tipo de transferência, tamanho máximo de pacote `wMaxPacketSize` e intervalo `bInterval`).


* **String Descriptor**: Textos legíveis codificados obrigatoriamente em UNICODE UTF-16LE.




* **IAD (Interface Association Descriptor)**: Descritor especial que associa múltiplos descritores de interface a uma única função do dispositivo.


* **LPM (Link Power Management)**: Extensão de protocolo que implementa transições rápidas para o estado L1 (Sleep) com controle de latência de retomada (*BESL* e *HIRD*).



---

### 6. Jargões de Hardware OpenTitan e Metodologia de Verificação (UVM)

* **`usbdev`**: Designação do controlador de dispositivo periférico USB 2.0 Full-Speed na árvore de IPs do OpenTitan.


* **DUT (Design Under Test)**: O bloco RTL que está sendo instanciado no módulo estático para verificação funcional.


* **TL-UL (TileLink Uncached Lightweight)**: Barramento interno síncrono da OpenTitan usado pelo processador para ler/escrever nos registradores CSR e na memória SRAM do `usbdev`.
* **CSR (Control and Status Register)**: Registradores mapeados em memória que configuram endpoints, habilitam transmissões e indicam eventos e interrupções.


* **RAL (Register Abstraction Layer)**: Camada de abstração UVM (`uvm_reg_block`, `uvm_reg`) que espelha os registradores físicos do hardware no testbench.


* **`uvm_reg_adapter`**: Classe responsável por traduzir operações de registradores (`read`/`write`) em transações de barramento (`reg2bus`) e vice-versa (`bus2reg`).


* **`uvm_sequence_item`**: Classe base usada para encapsular as variáveis que representam os pacotes ou transações simuladas (campos de PID, endereço, payload, CRC).


* **`uvm_driver`**: Componente UVM responsável por receber o `sequence_item` do sequenciador e manusear os sinais físicos/virtuais do barramento do DUT.


* **`uvm_monitor`**: Componente passivo que amostra as linhas de sinal, decodifica o protocolo (detectando SYNC, PID, dados, EOP) e transmite as transações via porta de análise.


* **`uvm_scoreboard`**: Módulo de checagem que compara as transações enviadas pelo barramento serial com as respostas observadas na memória interna ou barramento de CSRs.