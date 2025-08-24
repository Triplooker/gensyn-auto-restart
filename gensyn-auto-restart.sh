#!/bin/bash
set -euo pipefail

LOG_FILE="/var/log/gensyn-restart.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')
log() { echo "[$DATE] $1" | tee -a "$LOG_FILE"; }

# Устанавливаем переменные окружения для cron
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export HOME="/root"

cd /root
log "=== Перезапуск Gensyn ноды ==="

# Завершаем screen сессию с дополнительными проверками
if screen -list | grep -q gensyn; then
    log "Завершаем существующую screen сессию..."
    screen -S gensyn -X quit || true
    sleep 3
    # Проверяем что сессия действительно завершилась
    for i in {1..5}; do
        if ! screen -list | grep -q gensyn; then
            break
        fi
        log "Ждем завершения screen сессии (попытка $i)..."
        sleep 2
    done
fi

# Бэкапим файлы
log "Создаем бэкап важных файлов..."
mkdir -p /tmp/gensyn_backup
cp rl-swarm/swarm.pem /tmp/gensyn_backup/ 2>/dev/null || true
cp rl-swarm/modal-login/temp-data/userData.json /tmp/gensyn_backup/ 2>/dev/null || true
cp rl-swarm/modal-login/temp-data/userApiKey.json /tmp/gensyn_backup/ 2>/dev/null || true

# Переустанавливаем
log "Переустанавливаем rl-swarm..."
rm -rf rl-swarm
apt update && apt install -y sudo screen git python3 python3-venv python3-pip curl wget >/dev/null 2>&1
git clone https://github.com/gensyn-ai/rl-swarm.git >/dev/null 2>&1
wget -q -O rl-swarm/run_rl_swarm.sh https://raw.githubusercontent.com/Triplooker/fullgensyn/refs/heads/main/run_rl_swarm.sh
chmod +x rl-swarm/run_rl_swarm.sh
mkdir -p rl-swarm/modal-login/temp-data

# Восстанавливаем файлы
log "Восстанавливаем бэкап файлов..."
cp /tmp/gensyn_backup/swarm.pem rl-swarm/ 2>/dev/null || true
cp /tmp/gensyn_backup/userData.json rl-swarm/modal-login/temp-data/ 2>/dev/null || true
cp /tmp/gensyn_backup/userApiKey.json rl-swarm/modal-login/temp-data/ 2>/dev/null || true
rm -rf /tmp/gensyn_backup

# Настройка модели
log "Настраиваем конфигурацию модели..."
python3 -c "
import re
try:
    with open('rl-swarm/rgym_exp/config/rg-swarm.yaml', 'r') as f:
        content = f.read()
    content = re.sub(r'default_large_model_pool:\s*\n(\s*- [^\n]+\n)*', 'default_large_model_pool:\n  - Gensyn/Qwen2.5-0.5B-Instruct\n\n', content, flags=re.MULTILINE)
    content = re.sub(r'default_small_model_pool:\s*\n(\s*- [^\n]+\n?)*$', 'default_small_model_pool:\n  - Gensyn/Qwen2.5-0.5B-Instruct', content, flags=re.MULTILINE)
    with open('rl-swarm/rgym_exp/config/rg-swarm.yaml', 'w') as f:
        f.write(content)
except: pass
"

# Запускаем в screen с улучшенной проверкой
log "Запускаем ноду в screen сессии..."
cd rl-swarm

# Создаем screen сессию с лучшей обработкой ошибок
screen -S gensyn -dm bash -c "
export PATH='$PATH'
export HOME='$HOME'
python3 -m venv .venv 2>/dev/null || true
source .venv/bin/activate 2>/dev/null || true
exec ./run_rl_swarm.sh 2>&1
"

# Даем больше времени на запуск
sleep 15

# Проверяем результат с улучшенной диагностикой
if screen -list | grep -q gensyn; then
    # Дополнительная проверка - смотрим что screen сессия активна
    sleep 5
    if screen -list | grep gensyn | grep -q Detached; then
        log "✅ Нода перезапущена успешно (screen сессия активна)"
    else
        log "⚠️ Screen сессия создана, но возможны проблемы"
    fi
else
    log "❌ Ошибка запуска - screen сессия не найдена"
    # Попробуем получить больше информации об ошибке
    if [ -f "/root/rl-swarm/.venv/lib/python*/site-packages/pip/pip.log" ]; then
        log "Последние строки pip лога:"
        tail -5 /root/rl-swarm/.venv/lib/python*/site-packages/pip/pip.log 2>/dev/null || true
    fi
fi

log "=== Завершение перезапуска ==="
