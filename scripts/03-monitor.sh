#!/usr/bin/env bash
# 03-monitor.sh — Monitoramento de CPU, memória e disco com alertas e auto-restart
# Projeto: Dá Pra Ir? — FIAP Global Solution 2026.2 · Grupo FINELT
# Aluno: Ian Monteiro (RM 558652)
# Uso: bash 03-monitor.sh           (roda uma vez e sai)
#       bash 03-monitor.sh --daemon  (loop contínuo, intervalo definido por INTERVALO_SEG)
set -euo pipefail

# ── Configurações ────────────────────────────────────────────────────────────
LIMITE_CPU=85          # % — alerta se ultrapassar
LIMITE_MEM=90          # % — alerta se ultrapassar
LIMITE_DISCO=80        # % — alerta se ultrapassar
INTERVALO_SEG=60       # segundos entre verificações no modo --daemon
SERVICO="dapraIr"      # nome do serviço systemd a verificar
LOG_MONITOR="/var/log/dapraIr/monitor.log"
LOG_ALERTAS="/var/log/dapraIr/alertas.log"

# ── Utilitários ──────────────────────────────────────────────────────────────
ts()    { date '+%Y-%m-%d %H:%M:%S'; }
log()   { echo "[$(ts)] INFO  $*" | tee -a "$LOG_MONITOR"; }
alerta(){ echo "[$(ts)] ALERTA $*" | tee -a "$LOG_MONITOR" | tee -a "$LOG_ALERTAS"; }
erro()  { echo "[$(ts)] ERRO   $*" | tee -a "$LOG_MONITOR" >&2; }

# ── Garantir diretório de logs ───────────────────────────────────────────────
mkdir -p /var/log/dapraIr

# ────────────────────────────────────────────────────────────────────────────
verificar_cpu() {
  local cpu_idle
  cpu_idle=$(top -bn1 | awk '/^%Cpu/{print $8}')
  local cpu_uso
  cpu_uso=$(echo "100 - $cpu_idle" | bc | xargs printf "%.0f")
  log "CPU uso: ${cpu_uso}%"
  if (( cpu_uso > LIMITE_CPU )); then
    alerta "CPU acima do limite! Uso: ${cpu_uso}% (limite: ${LIMITE_CPU}%)"
    return 1
  fi
  return 0
}

verificar_memoria() {
  local total livre
  total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
  livre=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
  local uso_pct
  uso_pct=$(echo "scale=0; (($total - $livre) * 100 / $total)" | bc)
  log "Memória uso: ${uso_pct}%  (total: $((total/1024)) MB)"
  if (( uso_pct > LIMITE_MEM )); then
    alerta "Memória acima do limite! Uso: ${uso_pct}% (limite: ${LIMITE_MEM}%)"
    return 1
  fi
  return 0
}

verificar_disco() {
  local alerta_disparado=0
  while IFS= read -r linha; do
    local uso_pct ponto
    uso_pct=$(echo "$linha" | awk '{print $5}' | tr -d '%')
    ponto=$(echo "$linha" | awk '{print $6}')
    log "Disco $ponto: ${uso_pct}%"
    if (( uso_pct > LIMITE_DISCO )); then
      alerta "Disco $ponto acima do limite! Uso: ${uso_pct}% (limite: ${LIMITE_DISCO}%)"
      alerta_disparado=1
    fi
  done < <(df -h | tail -n +2 | grep -v tmpfs)
  return $alerta_disparado
}

verificar_servico() {
  if ! command -v systemctl &>/dev/null; then
    log "systemctl não disponível — pulando verificação de serviço."
    return 0
  fi
  if systemctl is-active --quiet "$SERVICO"; then
    log "Serviço $SERVICO: ATIVO"
    return 0
  else
    alerta "Serviço $SERVICO está INATIVO. Tentando reiniciar..."
    if systemctl restart "$SERVICO" 2>&1 | tee -a "$LOG_MONITOR"; then
      sleep 3
      if systemctl is-active --quiet "$SERVICO"; then
        log "Serviço $SERVICO reiniciado com sucesso."
      else
        erro "Serviço $SERVICO NÃO reiniciou. Intervenção manual necessária."
        return 1
      fi
    else
      erro "Falha ao tentar reiniciar $SERVICO."
      return 1
    fi
  fi
}

relatorio_completo() {
  log "──────────────────────────────────────────"
  log "=== RELATÓRIO DE MONITORAMENTO: $(ts) ==="
  log "Hostname: $(hostname)"
  log "Uptime:   $(uptime -p)"
  log ""
  local erros=0
  verificar_cpu    || (( erros++ ))
  verificar_memoria || (( erros++ ))
  verificar_disco  || (( erros++ ))
  verificar_servico || (( erros++ ))
  log ""
  if (( erros > 0 )); then
    alerta "Relatório concluído com $erros alerta(s)."
  else
    log "Relatório concluído — tudo dentro dos limites."
  fi
  log "──────────────────────────────────────────"
  return $erros
}

# ── Entry point ──────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--daemon" ]]; then
  log "Modo daemon iniciado. Intervalo: ${INTERVALO_SEG}s. PID: $$"
  while true; do
    relatorio_completo || true   # não sai do loop se houver alertas
    sleep "$INTERVALO_SEG"
  done
else
  relatorio_completo
fi
