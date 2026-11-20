#!/usr/bin/env bash
# 02-app.sh — Instalação do .NET 8 e deploy da aplicação Dá Pra Ir?
# Projeto: Dá Pra Ir? — FIAP Global Solution 2026.2 · Grupo FINELT
# Aluno: Ian Monteiro (RM 558652)
# Uso: sudo bash 02-app.sh [/caminho/para/publicacao]
set -euo pipefail

APP_DIR="/opt/dapraIr/app"
DATA_DIR="/opt/dapraIr/data"
SERVICE_USER="dapraIr"
LOG="/var/log/dapraIr-provisionamento.log"
PUBLISH_SRC="${1:-}"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG"; }

if [[ $EUID -ne 0 ]]; then
  echo "Execute como root: sudo bash $0" >&2
  exit 1
fi

log "=== Instalação da aplicação Dá Pra Ir? ==="

# ── 1. Instalar .NET 8 SDK ───────────────────────────────────────────────────
if ! command -v dotnet &>/dev/null; then
  log "Instalando .NET 8 SDK..."
  wget -q https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb \
    -O /tmp/packages-microsoft-prod.deb
  dpkg -i /tmp/packages-microsoft-prod.deb
  apt-get update -qq
  apt-get install -y -qq dotnet-sdk-8.0
  rm /tmp/packages-microsoft-prod.deb
  log ".NET $(dotnet --version) instalado."
else
  log ".NET já instalado: $(dotnet --version)"
fi

# ── 2. Publicar aplicação ────────────────────────────────────────────────────
if [[ -n "$PUBLISH_SRC" && -d "$PUBLISH_SRC" ]]; then
  log "Copiando publicação de $PUBLISH_SRC..."
  rsync -a --delete "$PUBLISH_SRC/" "$APP_DIR/"
  chown -R "$SERVICE_USER:$SERVICE_USER" "$APP_DIR"
  chmod 750 "$APP_DIR"
  log "Arquivos copiados."
elif [[ -f "/tmp/DaPraIr.API.zip" ]]; then
  log "Extraindo DaPraIr.API.zip..."
  unzip -qo /tmp/DaPraIr.API.zip -d "$APP_DIR"
  chown -R "$SERVICE_USER:$SERVICE_USER" "$APP_DIR"
  log "Extração concluída."
else
  log "AVISO: Nenhum fonte de publicação encontrado. Pulando cópia dos binários."
  log "Para fazer o deploy manual: dotnet publish -c Release -o $APP_DIR"
fi

# ── 3. Arquivo de configuração de ambiente ───────────────────────────────────
log "Criando arquivo de configuração de ambiente..."
cat > /etc/dapraIr.env <<'EOF'
ASPNETCORE_ENVIRONMENT=Production
ASPNETCORE_URLS=http://0.0.0.0:5000
ConnectionStrings__DefaultConnection=Data Source=/opt/dapraIr/data/dapraIr.db
Logging__LogLevel__Default=Warning
Logging__LogLevel__Microsoft.AspNetCore=Warning
EOF
chmod 640 /etc/dapraIr.env
chown root:"$SERVICE_USER" /etc/dapraIr.env
log "Arquivo de ambiente criado."

# ── 4. Copiar scripts de monitoramento ───────────────────────────────────────
log "Instalando scripts de monitoramento em /opt/dapraIr/scripts/..."
install -d -m 755 /opt/dapraIr/scripts
SCRIPTS_DIR="$(dirname "$(realpath "$0")")"
cp "$SCRIPTS_DIR/03-monitor.sh" /opt/dapraIr/scripts/03-monitor.sh
chmod 755 /opt/dapraIr/scripts/03-monitor.sh
log "Scripts instalados."

# ── 5. Instalar systemd service ──────────────────────────────────────────────
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
SERVICE_APP="$SCRIPT_DIR/../systemd/dapraIr.service"
SERVICE_MON="$SCRIPT_DIR/../systemd/monitor.service"

if [[ -f "$SERVICE_APP" ]]; then
  log "Instalando serviço dapraIr..."
  cp "$SERVICE_APP" /etc/systemd/system/dapraIr.service
  log "Serviço dapraIr instalado."
else
  log "AVISO: $SERVICE_APP não encontrado."
fi

if [[ -f "$SERVICE_MON" ]]; then
  log "Instalando serviço monitor..."
  cp "$SERVICE_MON" /etc/systemd/system/monitor.service
  log "Serviço monitor instalado."
else
  log "AVISO: $SERVICE_MON não encontrado."
fi

systemctl daemon-reload
systemctl enable dapraIr.service monitor.service
log "Serviços habilitados para iniciar com o sistema."

# ── 5. Ajustar permissões do banco ───────────────────────────────────────────
chown "$SERVICE_USER:$SERVICE_USER" "$DATA_DIR"
chmod 750 "$DATA_DIR"

# ── 7. Iniciar serviços ───────────────────────────────────────────────────────
for svc in dapraIr monitor; do
  if systemctl is-enabled "${svc}.service" &>/dev/null; then
    log "Iniciando serviço ${svc}..."
    systemctl start "${svc}.service" || true
    sleep 2
    if systemctl is-active --quiet "${svc}.service"; then
      log "Serviço ${svc} está RODANDO."
    else
      log "AVISO: Serviço ${svc} não iniciou. Verifique: journalctl -u ${svc} -n 50"
    fi
  fi
done

log "=== Deploy concluído. API disponível em: http://$(hostname -I | awk '{print $1}'):5000/swagger ==="
