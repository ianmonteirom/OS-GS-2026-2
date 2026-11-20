#!/usr/bin/env bash
# 01-infra.sh — Provisionamento de infraestrutura base
# Projeto: Dá Pra Ir? — FIAP Global Solution 2026.2 · Grupo FINELT
# Aluno: Ian Monteiro (RM 558652)
# Uso: sudo bash 01-infra.sh [HOSTNAME]
set -euo pipefail

HOSTNAME_NOVO="${1:-dapraIr-api}"
LOG="/var/log/dapraIr-provisionamento.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG"; }

# ── 1. Verificação de root ───────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
  echo "Execute como root: sudo bash $0" >&2
  exit 1
fi

log "=== Início do provisionamento — $HOSTNAME_NOVO ==="

# ── 2. Hostname e /etc/hosts ─────────────────────────────────────────────────
log "Configurando hostname: $HOSTNAME_NOVO"
hostnamectl set-hostname "$HOSTNAME_NOVO"
sed -i "/127.0.1.1/d" /etc/hosts
echo "127.0.1.1  $HOSTNAME_NOVO" >> /etc/hosts
log "Hostname configurado."

# ── 3. Atualização do sistema ────────────────────────────────────────────────
log "Atualizando pacotes do sistema..."
apt-get update -qq
apt-get upgrade -y -qq
apt-get install -y -qq \
  curl wget git unzip htop tree \
  net-tools ufw fail2ban \
  systemd-timesyncd
log "Pacotes instalados."

# ── 4. Configuração de rede (IP, rotas e DNS) ────────────────────────────────
log "=== Configuração de rede ==="
log "Interface e endereçamento IP:"
ip addr show | tee -a "$LOG"
log "Tabela de rotas:"
ip route show | tee -a "$LOG"
log "DNS configurado:"
cat /etc/resolv.conf | tee -a "$LOG"

# Garantir resolução de nomes funcional via systemd-resolved
if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
  log "systemd-resolved ativo."
else
  log "Habilitando systemd-resolved..."
  systemctl enable --now systemd-resolved 2>/dev/null || true
fi

# Verificar conectividade e DNS
if ping -c 1 -W 3 8.8.8.8 &>/dev/null; then
  log "Conectividade OK (ping 8.8.8.8 bem-sucedido)."
else
  log "AVISO: sem conectividade com 8.8.8.8 (pode ser restrição de rede/WSL)."
fi
if host google.com &>/dev/null 2>&1 || nslookup google.com &>/dev/null 2>&1; then
  log "Resolução de DNS OK."
else
  log "AVISO: resolução de DNS não verificada (host/nslookup não disponíveis ou sem resposta)."
fi
log "=== Rede configurada ==="

# ── 4. Timezone e NTP ────────────────────────────────────────────────────────
log "Configurando timezone e NTP..."
timedatectl set-timezone America/Sao_Paulo
systemctl enable --now systemd-timesyncd
log "Timezone: $(timedatectl show --value -p Timezone)"

# ── 5. Usuário de serviço ────────────────────────────────────────────────────
if ! id -u dapraIr &>/dev/null; then
  log "Criando usuário de serviço: dapraIr"
  useradd -r -s /bin/false -d /opt/dapraIr -m dapraIr
  log "Usuário dapraIr criado."
else
  log "Usuário dapraIr já existe — pulando."
fi

# ── 6. Diretórios da aplicação ───────────────────────────────────────────────
log "Criando estrutura de diretórios..."
install -d -o dapraIr -g dapraIr -m 750 \
  /opt/dapraIr/app \
  /opt/dapraIr/data \
  /var/log/dapraIr
log "Diretórios criados."

# ── 7. Firewall UFW ──────────────────────────────────────────────────────────
log "Configurando firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 5000/tcp comment "Dá Pra Ir? API"
ufw --force enable
ufw status verbose | tee -a "$LOG"
log "Firewall configurado."

# ── 8. Fail2ban ──────────────────────────────────────────────────────────────
log "Habilitando fail2ban..."
systemctl enable --now fail2ban
log "Fail2ban ativo."

log "=== Provisionamento de infra concluído. Execute 02-app.sh para instalar a aplicação. ==="
