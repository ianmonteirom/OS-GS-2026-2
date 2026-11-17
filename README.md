# Dá Pra Ir? — Entrega Sistemas Operacionais · Linux + Bash + systemd

**FIAP Global Solution 2026.2 · Grupo FINELT**  
Carlos Henrique (558003) · Mauricio Alves (556214) · Ian Monteiro (558652) · Bruno Silva (550416) · João Hoffmann (550763)

---

## Visão geral

Scripts Bash para provisionar, fazer o deploy e monitorar a API **Dá Pra Ir?** em servidor Linux (Ubuntu 22.04 LTS).  
Serviço systemd garante reinício automático em caso de falha.

---

## Pré-requisitos

- Ubuntu 22.04 LTS (ou derivado)
- Acesso `sudo`
- Conexão com internet (para baixar pacotes)

---

## Como usar

### 1. Provisionamento de infraestrutura

```bash
sudo bash scripts/01-infra.sh [HOSTNAME]
```

- Define hostname e `/etc/hosts`
- Instala pacotes essenciais (`curl`, `git`, `htop`, `ufw`, `fail2ban`)
- Configura timezone `America/Sao_Paulo`
- Cria usuário de serviço `dapraIr` (sem shell, sem home pública)
- Cria diretórios `/opt/dapraIr/app`, `/opt/dapraIr/data`, `/var/log/dapraIr`
- Configura firewall UFW (bloqueia tudo, libera SSH + porta 5000)
- Habilita fail2ban

### 2. Deploy da aplicação

```bash
# Publique primeiro no Windows/Mac:
dotnet publish ../csharp/DaPraIr.API -c Release -o /tmp/dapraIr-pub

# No servidor:
sudo bash scripts/02-app.sh /tmp/dapraIr-pub
```

- Instala .NET 8 SDK via repositório oficial Microsoft
- Copia binários publicados para `/opt/dapraIr/app`
- Cria `/etc/dapraIr.env` com variáveis de ambiente
- Instala e habilita o serviço systemd `dapraIr.service`
- Inicia o serviço e verifica o status

### 3. Monitoramento

```bash
# Verificação única (mostra relatório e sai)
sudo bash scripts/03-monitor.sh

# Loop contínuo (a cada 60s)
sudo bash scripts/03-monitor.sh --daemon
```

Monitoramento verifica:
- CPU (alerta acima de 85%)
- Memória RAM (alerta acima de 90%)
- Disco — todos os pontos de montagem (alerta acima de 80%)
- Status do serviço `dapraIr` — reinicia automaticamente se inativo

Logs em:
- `/var/log/dapraIr/monitor.log` — relatório completo
- `/var/log/dapraIr/alertas.log` — somente alertas

---

## Arquivos

| Arquivo | Descrição |
|---|---|
| `scripts/01-infra.sh` | Provisiona servidor — hostname, pacotes, usuário, firewall |
| `scripts/02-app.sh` | Deploy da API — .NET, binários, env, systemd |
| `scripts/03-monitor.sh` | Monitora CPU/mem/disco; auto-restart do serviço |
| `systemd/dapraIr.service` | Unit file para gerenciamento do processo pela systemd |

---

## Serviço systemd

```bash
# Verificar status
systemctl status dapraIr

# Reiniciar
sudo systemctl restart dapraIr

# Ver logs em tempo real
journalctl -u dapraIr -f

# Desabilitar na inicialização
sudo systemctl disable dapraIr
```

O service file em `systemd/dapraIr.service` configura:
- Restart automático com delay de 5s
- Variáveis de ambiente carregadas de `/etc/dapraIr.env`
- Proteções de segurança (`NoNewPrivileges`, `ProtectSystem`, `PrivateTmp`)
- Limite de memória: 512 MB

---

## Verificar funcionamento da API após deploy

```bash
curl http://localhost:5000/api/lugares?usaCadeira=true
```

Ou acesse `http://<ip-do-servidor>:5000/swagger` no navegador.

---

## Requisitos técnicos demonstrados

| Requisito | Script / Arquivo |
|---|---|
| **Provisionamento automatizado** | `01-infra.sh` |
| **Variáveis e parâmetros** | Todos os scripts |
| **Estruturas de controle** (`if`, `while`, `for`) | `03-monitor.sh` |
| **Funções** | `log()`, `alerta()`, `verificar_cpu()`, etc. em `03-monitor.sh` |
| **Redirecionamento** (`tee -a`) | `03-monitor.sh` — logs duplos |
| **Serviço systemd** | `systemd/dapraIr.service` + `02-app.sh` |
| **Monitoramento de recursos** | `/proc/meminfo`, `top`, `df` em `03-monitor.sh` |
| **Segurança** | UFW, fail2ban, usuário de serviço sem shell, `ProtectSystem` |
