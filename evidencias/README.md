# Evidências — Entrega Sistemas Operacionais

**Projeto:** Dá Pra Ir? · FIAP Global Solution 2026.2 · Grupo FINELT

---

## Vídeo demonstrativo

**Link:** https://youtu.be/zRwZ7wkx_34  
**Duração:** 2 minutos e 11 segundos

---

## Mapa do vídeo — o que aparece em cada momento

| Timestamp | O que é demonstrado | Requisito |
|---|---|---|
| 0:00 – 0:30 | Execução dos `grep` mostrando variáveis, funções e estruturas de controle nos scripts | Variáveis, funções, `if/while/for` |
| 0:30 – 1:10 | Execução de `01-infra.sh` — hostname, pacotes, usuário de serviço, diretórios, UFW, fail2ban | Provisionamento automatizado |
| 1:10 – 1:40 | Execução de `02-app.sh` — instalação do .NET 8, deploy dos binários, serviço systemd `active (running)`, arquivo `.service` na tela | Deploy, systemd, configuração |
| 1:40 – 1:50 | `systemctl stop dapraIr` → 6 segundos → `systemctl status` mostrando `active (running)` novamente | Auto-restart — tolerância a falhas |
| 1:50 – 2:10 | Execução de `03-monitor.sh` — CPU, RAM, disco. Logs `monitor.log` e `alertas.log` com `tee -a` | Monitoramento, redirecionamento, logs |

---

## Screenshots a adicionar aqui

> Execute os comandos abaixo no WSL e faça print de cada resultado.
> Arraste os arquivos `.png` ou `.jpg` para esta pasta antes de entregar.

| Arquivo sugerido | Comando a executar |
|---|---|
| `01-systemctl-status-dapraIr.png` | `systemctl status dapraIr` |
| `02-systemctl-status-monitor.png` | `systemctl status monitor` |
| `03-monitor-log.png` | `cat /var/log/dapraIr/monitor.log` |
| `04-alertas-log.png` | `cat /var/log/dapraIr/alertas.log` |
| `05-ufw-status.png` | `ufw status verbose` |
| `06-ip-addr.png` | `ip addr show && ip route show` |
| `07-testes-falha-log.png` | `cat /var/log/dapraIr/testes-falha.log` (após rodar `04-testes-falha.sh`) |
| `08-api-swagger.png` | Navegador em `http://localhost:5000/swagger` |
