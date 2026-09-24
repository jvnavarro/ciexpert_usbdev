# Guia Prático: Acesso Remoto de Alta Performance ao Verdi via VNC + Túnel SSH (CADMicro UFRGS)

Este documento descreve o passo a passo completo para executar ferramentas de EDA gráficas e pesadas (**Verdi, VCS, Vivado, Cadence Virtuoso**) nos servidores **CADMicro da UFRGS** com alta taxa de quadros (60 FPS), sem travamentos e com resposta imediata do mouse, utilizando **TigerVNC** encapsulado em um **túnel SSH seguro**.

---

## 1. Por que usar VNC em vez de `ssh -X`?

| Característica | `ssh -X` / `ssh -Y` (X11 Forwarding) | VNC + Túnel SSH (Recomendado) |
| :--- | :--- | :--- |
| **Renderização** | O servidor envia comandos X11 crus para o seu PC desenhar localmente. | O servidor renderiza tudo em um display virtual na memória do próprio servidor. |
| **Sensibilidade à Latência**| **Altíssima.** Cada clique, menu ou onda no Verdi exige centenas de *round-trips* de rede síncronos (gerando congelamentos de tela). | **Quase nula.** O servidor compacta a imagem em tempo real e transmite apenas os pixels alterados. |
| **Persistência de Sessão**| Se a VPN oscilar ou o SSH cair, **o Verdi fecha e você perde simulações não salvas**. | **100% persistente.** Se a conexão cair, o Verdi continua aberto e rodando no servidor. Basta reconectar o VNC! |

---

## ⚡ Automação com 1 Clique (Script Atualizado)

O script [`2_mount_cadmicro_projects_folder.sh`](file:///home/jvnavarro/.local/share/nemo/scripts/vpn_ufrgs/2_mount_cadmicro_projects_folder.sh) foi configurado para fazer **tudo automaticamente**:
1. Conecta na pasta remota (`sshfs`).
2. Verifica se já existe uma sessão VNC sua aberta no servidor (se não existir, ele cria uma automaticamente).
3. Abre o túnel SSH seguro na porta correta (`59XX`).
4. Abre a janela do **TigerVNC Viewer** automaticamente.
5. Abre o terminal SSH interativo.

Basta rodar o script e digitar sua senha da UFRGS uma única vez!

---

---

## 2. Passo a Passo de Conexão

### Pré-requisito: Conectar na VPN
Antes de iniciar, certifique-se de que a VPN da UFRGS está ativa (via script [`1_start_vpn.sh`](file:///home/jvnavarro/.local/share/nemo/scripts/vpn_ufrgs/1_start_vpn.sh) ou interface do sistema).

---

### Passo 1: No Servidor Remoto (`cadmicro-el8-XX`)
No terminal remoto SSH onde você trabalha:

1. **Inicie o servidor VNC com a sua resolução de tela:**
   ```bash
   vncserver -geometry 1920x1080 -localhost yes
   ```
   * *Nota 1:* A flag `-localhost yes` garante segurança total, impedindo que pessoas de fora acessem a sua tela sem passar pelo seu túnel SSH.
   * *Nota 2:* Se for a sua primeira vez, ele pedirá uma senha de 6 a 8 dígitos para o VNC e perguntará se quer criar uma "view-only password" (digite `n`).

2. **Identifique o número do display gerado:**  
   O terminal retornará uma linha como esta:
   > `New 'cadmicro-el8-08.inf.ufrgs.br:22 (joao.costa)' desktop is cadmicro-el8-08.inf.ufrgs.br:22`

3. **Calcule a porta do seu VNC:**
   $$\mathbf{Porta} = 5900 + \mathbf{Display}$$
   * Display `:1` $\rightarrow$ Porta **`5901`**
   * Display `:2` $\rightarrow$ Porta **`5902`**
   * Display `:22` $\rightarrow$ Porta **`5922`**

---

### Passo 2: No seu Computador Local (Abrir o Túnel SSH)
Abra uma janela de terminal no seu computador e crie o túnel criptografado apontando para a porta obtida no Passo 1:

```bash
# Exemplo para a porta 5922 (Display :22):
ssh -L 5922:localhost:5922 joao.costa@cadmicro-el8-08.inf.ufrgs.br
```
> **Importante:** Mantenha esse terminal aberto enquanto estiver usando o VNC. Ele é o "túnel" por onde os dados de vídeo passam.

---

### Passo 3: No seu Computador Local (Abrir o Visualizador)
Abra um novo terminal (ou execute via `Alt + F2`) e inicie o cliente local:

```bash
# Exemplo para a porta 5922:
vncviewer localhost:5922
```

1. Uma janela pedirá a sua senha do VNC criada no Passo 1.
2. A área de trabalho gráfica do servidor se abrirá em tela cheia ou janela.
3. Abra um terminal dentro da tela do VNC e execute o Verdi:
   ```bash
   verdi &
   ```

---

## 3. Como Encerrar a Sessão quando Terminar de Trabalhar

Quando você terminar de usar o ambiente e quiser liberar a memória do servidor:

1. No terminal do servidor remoto (`cadmicro`), mate a tela específica:
   ```bash
   # Substitua pelo número do seu display (exemplo: :22):
   vncserver -kill :22
   ```
2. Feche a janela do `vncviewer`.
3. Feche o terminal do túnel SSH local (`Ctrl + C` ou `exit`).

---

## 4. Dicas Úteis e Solução de Problemas

### Como listar quais telas VNC suas estão abertas no servidor?
No terminal do servidor remoto:
```bash
vncserver -list
```
Isso mostra todas as instâncias ativas, o PID e o número da tela.

### E se a conexão da VPN cair ou meu computador descarregar?
**Você não perde nada!**
O servidor continua rodando a sessão normalmente. Quando voltar:
1. Conecte na VPN.
2. Refaça apenas o túnel SSH local (**Passo 2**).
3. Abra o `vncviewer localhost:59XX` (**Passo 3**).
4. O Verdi estará exatamente no mesmo estado e na mesma tela em que você parou.

### Como alterar a senha do VNC?
No terminal do servidor remoto:
```bash
vncpasswd
```

### Como mudar a resolução para um monitor ultrawide ou 2K?
Ao criar a sessão no servidor, ajuste a flag `-geometry`:
```bash
vncserver -geometry 2560x1440 -localhost yes
```
