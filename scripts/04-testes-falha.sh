#!/usr/bin/env bash
# 04-testes-falha.sh — Testes de falha e recuperação
# Projeto: Dá Pra Ir? — FIAP Global Solution 2026.2 · Grupo FINELT
# Uso: sudo bash 04-testes-falha.sh
set -euo pipefail

LOG="/var/log/dapraIr/testes-falha.log"
mkdir -p /var/log/dapraIr

ts()  { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(ts)] $*" | tee -a "$LOG"; }
sep() { log "──────────────────────────────────────────────────"; }

sep
log "=== INÍCIO DOS TESTES DE FALHA E RECUPERAÇÃO ==="
sep

# ── Teste 1: Auto-restart do serviço dapraIr ─────────────────────────────────
log "[TESTE 1] Simulação de falha no serviço dapraIr"
log "Estado antes: $(systemctl is-active dapraIr.service 2>/dev/null || echo 'inativo')"
log "Interrompendo serviço dapraIr..."
systemctl stop dapraIr.service
log "Serviço parado. Aguardando 8 segundos para auto-restart (RestartSec=5s)..."
sleep 8
ESTADO=$(systemctl is-active dapraIr.service 2>/dev/null || echo 'inativo')
log "Estado após 8s: $ESTADO"
if [[ "$ESTADO" == "active" ]]; then
  log "[TESTE 1] ✓ PASSOU — serviço reiniciou automaticamente via systemd."
else
  log "[TESTE 1] ✗ FALHOU — serviço não reiniciou. Verifique: journalctl -u dapraIr -n 30"
fi
sep

# ── Teste 2: Auto-restart do serviço monitor ─────────────────────────────────
log "[TESTE 2] Simulação de falha no serviço monitor"
if systemctl is-active --quiet monitor.service 2>/dev/null; then
  log "Estado antes: $(systemctl is-active monitor.service)"
  log "Interrompendo serviço monitor..."
  systemctl stop monitor.service
  sleep 12
  ESTADO_MON=$(systemctl is-active monitor.service 2>/dev/null || echo 'inativo')
  log "Estado após 12s: $ESTADO_MON"
  if [[ "$ESTADO_MON" == "active" ]]; then
    log "[TESTE 2] ✓ PASSOU — monitor reiniciou automaticamente."
  else
    log "[TESTE 2] ✗ FALHOU — monitor não reiniciou."
  fi
else
  log "[TESTE 2] PULADO — serviço monitor não está ativo (systemd pode não estar disponível no WSL)."
fi
sep

# ── Teste 3: Consumo elevado de CPU ──────────────────────────────────────────
log "[TESTE 3] Simulação de consumo elevado de CPU"
if command -v stress-ng &>/dev/null; then
  log "Iniciando stress-ng na CPU por 15 segundos..."
  stress-ng --cpu 2 --timeout 15s &
  STRESS_PID=$!
  sleep 5
  log "CPU durante stress (top -bn1):"
  top -bn1 | head -5 | tee -a "$LOG"
  wait $STRESS_PID 2>/dev/null || true
  log "[TESTE 3] ✓ stress-ng concluído. Verifique alertas.log para ver se alerta foi disparado."
else
  log "stress-ng não instalado. Simulando com loop Bash por 10 segundos..."
  timeout 10 bash -c 'while true; do :; done' &
  LOOP_PID=$!
  sleep 5
  log "CPU durante stress (top -bn1):"
  top -bn1 | head -5 | tee -a "$LOG"
  kill $LOOP_PID 2>/dev/null || true
  log "[TESTE 3] ✓ Loop de stress concluído."
fi
sep

# ── Teste 4: Falha controlada em script ──────────────────────────────────────
log "[TESTE 4] Falha controlada em script — comando inválido"
bash -c 'comando_que_nao_existe 2>&1 || echo "[$(date)] ERRO capturado: comando_que_nao_existe falhou com código $?"' | tee -a "$LOG"
log "[TESTE 4] ✓ Erro registrado no log com sucesso."
sep

# ── Resumo ───────────────────────────────────────────────────────────────────
log "=== TESTES CONCLUÍDOS ==="
log "Log completo: $LOG"
log "Alertas: /var/log/dapraIr/alertas.log"
sep
