# Dá Pra Ir? — Entrega Sistemas Operacionais · Linux + Bash + systemd

**FIAP Global Solution 2026.2 · Grupo FINELT**  
Carlos Henrique (558003) · Mauricio Alves (556214) · Ian Monteiro (558652) · Bruno Silva (550416) · João Hoffmann (550763)

---

## Vídeo demonstrativo

[![Vídeo OS — GS 2026.2](https://img.youtube.com/vi/zRwZ7wkx_34/0.jpg)](https://youtu.be/zRwZ7wkx_34)

---

## Visão geral

Scripts Bash para provisionar, fazer o deploy e monitorar a API **Dá Pra Ir?** em servidor Linux (Ubuntu 22.04 LTS / WSL2).  
Dois serviços systemd garantem disponibilidade contínua: um para a aplicação, outro para o monitoramento de recursos.

---

## Pré-requisitos

- Ubuntu 22.04 LTS (ou WSL2 com Ubuntu)
- Acesso `sudo` / root
- Conexão com internet (para baixar pacotes)

---

## Como reproduzir o ambiente

Execute os scripts **em ordem** como root:

### 1. Provisionamento de infraestrutura

```bash
sudo bash scripts/01-infra.sh [HOSTNAME]
```

O script:
- Define hostname e `/etc/hosts`
- **Exibe e registra a configuração de rede** (IP, rotas, DNS)
- Verifica conectividade e resolução de nomes
- Instala pacotes essenciais (`curl`, `git`, `htop`, `ufw`, `fail2ban`, `net-tools`)
- Configura timezone `America/Sao_Paulo` + NTP
- Cria usuário de serviço `dapraIr` (sem shell)
- Cria diretórios `/opt/dapraIr/app`, `/opt/dapraIr/data`, `/var/log/dapraIr`
- Configura firewall UFW (bloqueia tudo, libera SSH + porta 5000)
- Habilita fail2ban

### 2. Deploy da aplicação + serviços

```bash
# Publicar o projeto C# (https://github.com/ianmonteirom/DaPraIrAPI):
dotnet publish DaPraIr.API -c Release -o /tmp/dapraIr-pub

# No servidor / WSL:
sudo bash scripts/02-app.sh /tmp/dapraIr-pub
```

O script:
- Instala .NET 8 SDK via repositório oficial Microsoft
- Copia binários para `/opt/dapraIr/app`
- Copia scripts de monitoramento para `/opt/dapraIr/scripts/`
- Cria `/etc/dapraIr.env` com variáveis de ambiente
- Instala e habilita **dois serviços systemd**: `dapraIr.service` e `monitor.service`
- Inicia ambos os serviços e verifica o status

### 3. Monitoramento manual (opcional)

```bash
# Verificação única
sudo bash scripts/03-monitor.sh

# Loop contínuo a cada 60s (também executado pelo monitor.service)
sudo bash scripts/03-monitor.sh --daemon
```

### 4. Testes de falha e recuperação

```bash
sudo bash scripts/04-testes-falha.sh
```

Executa automaticamente:
- **Teste 1:** Para o serviço `dapraIr` → aguarda 8s → verifica auto-restart
- **Teste 2:** Para o serviço `monitor` → aguarda 12s → verifica auto-restart
- **Teste 3:** Estresse de CPU (loop Bash ou `stress-ng`) → verifica geração de alerta
- **Teste 4:** Falha controlada em script → verifica registro de erro no log

---

## Arquivos

| Arquivo | Descrição |
|---|---|
| `scripts/01-infra.sh` | Provisiona servidor — hostname, rede, DNS, pacotes, usuário, firewall |
| `scripts/02-app.sh` | Deploy da API — .NET 8, binários, env, dois serviços systemd |
| `scripts/03-monitor.sh` | Monitora CPU/mem/disco; auto-restart do serviço |
| `scripts/04-testes-falha.sh` | Testes de falha e recuperação dos serviços |
| `systemd/dapraIr.service` | Serviço systemd da API com hardening de segurança |
| `systemd/monitor.service` | Serviço systemd do monitoramento (inicia com o sistema) |

---

## Serviços systemd

### dapraIr — API da aplicação

```bash
systemctl status dapraIr
sudo systemctl start dapraIr
sudo systemctl stop dapraIr
sudo systemctl restart dapraIr
journalctl -u dapraIr -f
```

### monitor — Monitoramento de recursos

```bash
systemctl status monitor
sudo systemctl start monitor
sudo systemctl stop monitor
sudo systemctl restart monitor
journalctl -u monitor -f
```

Ambos os serviços têm `Restart=always` — reiniciam automaticamente em caso de falha.

---

## Logs

| Arquivo | Conteúdo |
|---|---|
| `/var/log/dapraIr-provisionamento.log` | Log completo dos scripts 01 e 02 |
| `/var/log/dapraIr/monitor.log` | Relatórios de monitoramento (CPU, RAM, disco, serviço) |
| `/var/log/dapraIr/alertas.log` | Somente alertas de consumo elevado |
| `/var/log/dapraIr/testes-falha.log` | Resultados dos testes de falha |

---

## Requisitos técnicos demonstrados

| Requisito | Script / Arquivo |
|---|---|
| **Configuração de hostname** | `01-infra.sh` — `hostnamectl set-hostname` |
| **Configuração de rede (IP, rotas, DNS)** | `01-infra.sh` — `ip addr`, `ip route`, `resolv.conf`, conectividade |
| **Variáveis e parâmetros** | Todos os scripts — variáveis no topo |
| **Estruturas de controle** (`if`, `while`, `for`) | `03-monitor.sh`, `02-app.sh` |
| **Funções** | `log()`, `alerta()`, `erro()`, `verificar_cpu()`, `verificar_memoria()`, `verificar_disco()` |
| **Redirecionamento** (`tee -a`) | `03-monitor.sh` — logs duplos com `tee -a` |
| **Provisionamento automatizado** | `01-infra.sh` + `02-app.sh` |
| **Serviço systemd da aplicação** | `systemd/dapraIr.service` + `02-app.sh` |
| **Serviço systemd de monitoramento** | `systemd/monitor.service` — inicia com o sistema |
| **Monitoramento de recursos** | `03-monitor.sh` — `/proc/meminfo`, `top`, `df -h` |
| **Alertas de consumo elevado** | `03-monitor.sh` — CPU >85%, RAM >90%, Disco >80% |
| **Tolerância a falhas** | `Restart=always`, `RestartSec=5–10s` em ambos os serviços |
| **Testes de falha** | `04-testes-falha.sh` — 4 testes automatizados |
| **Segurança** | UFW, fail2ban, usuário de serviço sem shell, `ProtectSystem=strict` |
| **Logs de auditoria** | 4 arquivos de log separados por finalidade |

---

## Verificar funcionamento da API após deploy

```bash
curl http://localhost:5000/api/lugares?usaCadeira=true
```

Ou acesse `http://<ip-do-servidor>:5000/swagger` no navegador.

---

## Evidências

Ver pasta [`evidencias/`](evidencias/) com mapa do vídeo e lista de screenshots.
