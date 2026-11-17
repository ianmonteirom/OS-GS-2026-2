# Prompts utilizados com IA — Sistemas Operacionais

**Projeto:** Dá Pra Ir?  
**Grupo:** FINELT  
**Ferramenta de IA:** Claude (Anthropic) via Claude Code

---

## Prompts principais

### 1. Scripts Bash de provisionamento

> "Crie um script Bash 01-infra.sh para provisionar um servidor Linux Ubuntu com: configuração de hostname, instalação de pacotes essenciais, criação de usuário de serviço sem shell, criação de diretórios do app, configuração de UFW (liberar SSH e porta 5000) e habilitação do fail2ban. Use funções, log com timestamp e cores no terminal."

**Resultado:** `01-infra.sh` com função `log()`, variáveis de configuração no topo, estruturas `if/for`, redirecionamento para arquivo de log.

---

### 2. Script de deploy com systemd

> "Crie 02-app.sh para instalar o .NET 8 SDK a partir do repositório oficial Microsoft, copiar os binários publicados para /opt/dapraIr/app via rsync, criar um arquivo de variáveis de ambiente em /etc/dapraIr.env, instalar o serviço systemd e iniciá-lo verificando o status."

**Resultado:** `02-app.sh` instalando .NET 8.0.428 e service unit via `systemctl enable --now`.

---

### 3. Script de monitoramento com alertas

> "Crie 03-monitor.sh que monitore CPU (alerta >85%), memória (alerta >90%) e todos os pontos de montagem de disco (alerta >80%). Se o serviço dapraIr estiver inativo, reinicie automaticamente. Grave logs separados: um completo e um só de alertas. Suporte --daemon para loop contínuo a cada 60s."

**Resultado:** `03-monitor.sh` usando `/proc/meminfo`, `top -bn1`, `df -h`, `systemctl is-active`, com saída em dois arquivos via `tee -a`.

---

### 4. Unit file systemd seguro

> "Crie o arquivo dapraIr.service com Restart=always, RestartSec=5s, carregamento de variáveis do /etc/dapraIr.env, limite de memória de 512MB e hardening de segurança: NoNewPrivileges, ProtectSystem=strict, PrivateTmp."

**Resultado:** `systemd/dapraIr.service` com todas as proteções e `WantedBy=multi-user.target`.

---

### 5. Configuração do ambiente Linux (WSL2)

> "Configure o ambiente WSL2 Ubuntu para rodar os scripts como evidência. Execute os 3 scripts em sequência e verifique que o serviço está rodando e os logs foram gerados."

**Resultado:** API Dá Pra Ir? rodando em `http://172.29.15.119:5000/swagger` no WSL2, serviço `active (running)`, logs em `/var/log/dapraIr/`.
