#!/bin/bash

echo "🚀 Установка автоматического перезапуска Gensyn ноды каждые 8 часов..."

# Создаем скрипт перезапуска прямо здесь
cat > /root/gensyn-auto-restart.sh << 'SCRIPT_EOF'
#!/bin/bash
set -euo pipefail

LOG_FILE="/var/log/gensyn-restart.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')
log() { echo "[$DATE] $1" | tee -a "$LOG_FILE"; }

cd /root
log "=== Перезапуск Gensyn ноды ==="

# Завершаем screen сессию
screen -S gensyn -X quit || true
sleep 5

# Бэкапим файлы
mkdir -p /tmp/gensyn_backup
cp rl-swarm/swarm.pem /tmp/gensyn_backup/ 2>/dev/null || true
cp rl-swarm/modal-login/temp-data/userData.json /tmp/gensyn_backup/ 2>/dev/null || true
cp rl-swarm/modal-login/temp-data/userApiKey.json /tmp/gensyn_backup/ 2>/dev/null || true

# Переустанавливаем
rm -rf rl-swarm
apt update && apt install -y sudo screen git python3 python3-venv python3-pip curl wget
git clone https://github.com/gensyn-ai/rl-swarm.git
wget -O rl-swarm/run_rl_swarm.sh https://raw.githubusercontent.com/Triplooker/fullgensyn/refs/heads/main/run_rl_swarm.sh
chmod +x rl-swarm/run_rl_swarm.sh
mkdir -p rl-swarm/modal-login/temp-data

# Восстанавливаем файлы
cp /tmp/gensyn_backup/swarm.pem rl-swarm/ 2>/dev/null || true
cp /tmp/gensyn_backup/userData.json rl-swarm/modal-login/temp-data/ 2>/dev/null || true
cp /tmp/gensyn_backup/userApiKey.json rl-swarm/modal-login/temp-data/ 2>/dev/null || true
rm -rf /tmp/gensyn_backup

# Настройка модели
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

# Запускаем в screen
cd rl-swarm
screen -S gensyn -dm bash -c "python3 -m venv .venv && source .venv/bin/activate && exec ./run_rl_swarm.sh"
sleep 10

if screen -list | grep -q gensyn; then
    log "✅ Нода перезапущена успешно"
else
    log "❌ Ошибка запуска"
fi
SCRIPT_EOF

chmod +x /root/gensyn-auto-restart.sh

# Создаем cron задачу для запуска каждые 8 часов
echo "0 */8 * * * /root/gensyn-auto-restart.sh" | crontab -

# Создаем лог файл
touch /var/log/gensyn-restart.log

echo "✅ Готово!"
echo "Автоматический перезапуск настроен каждые 8 часов"
echo ""
echo "Команды:"
echo "  screen -r gensyn                     - подключиться к ноде"
echo "  tail -f /var/log/gensyn-restart.log - смотреть логи"
echo "  /root/gensyn-auto-restart.sh        - запустить сейчас"
echo "  crontab -l                          - посмотреть расписание"
