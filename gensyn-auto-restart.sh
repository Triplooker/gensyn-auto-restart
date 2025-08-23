#!/bin/bash

# Автоматический перезапуск Gensyn ноды
# Этот скрипт выполняет перезапуск каждые 8 часов

set -euo pipefail

# Логирование
LOG_FILE="/var/log/gensyn-restart.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

log() {
    echo "[$DATE] $1" | tee -a "$LOG_FILE"
}

log "=== Начинаем перезапуск Gensyn ноды ==="

# Завершение существующей screen сессии gensyn
log "Завершение существующей screen сессии..."
screen -S gensyn -X quit || true
sleep 5

# Резервное копирование важных файлов
log "Создание резервной копии..."
mkdir -p /tmp/gensyn_backup
cp rl-swarm/swarm.pem /tmp/gensyn_backup/ 2>/dev/null || log "WARNING: swarm.pem не найден"
cp rl-swarm/modal-login/temp-data/userData.json /tmp/gensyn_backup/ 2>/dev/null || log "WARNING: userData.json не найден"
cp rl-swarm/modal-login/temp-data/userApiKey.json /tmp/gensyn_backup/ 2>/dev/null || log "WARNING: userApiKey.json не найден"

# Удаление старой папки и переустановка
log "Удаление старой версии..."
rm -rf rl-swarm

log "Обновление пакетов..."
apt update && apt install -y sudo
sudo apt update && sudo apt install -y python3 python3-venv python3-pip curl wget screen git lsof nano unzip iproute2 build-essential gcc g++

log "Клонирование репозитория..."
git clone https://github.com/gensyn-ai/rl-swarm.git

log "Загрузка run_rl_swarm.sh..."
wget -O rl-swarm/run_rl_swarm.sh https://raw.githubusercontent.com/Triplooker/fullgensyn/refs/heads/main/run_rl_swarm.sh
chmod +x rl-swarm/run_rl_swarm.sh

log "Создание папок..."
mkdir -p rl-swarm/modal-login/temp-data

log "Восстановление резервных файлов..."
cp /tmp/gensyn_backup/swarm.pem rl-swarm/ 2>/dev/null || log "WARNING: swarm.pem не восстановлен"
cp /tmp/gensyn_backup/userData.json rl-swarm/modal-login/temp-data/ 2>/dev/null || log "WARNING: userData.json не восстановлен"
cp /tmp/gensyn_backup/userApiKey.json rl-swarm/modal-login/temp-data/ 2>/dev/null || log "WARNING: userApiKey.json не восстановлен"

log "Очистка временных файлов..."
rm -rf /tmp/gensyn_backup

log "Настройка модели Qwen2.5-0.5B-Instruct..."
python3 -c "
import re
config_file = 'rl-swarm/rgym_exp/config/rg-swarm.yaml'
try:
    with open(config_file, 'r') as f:
        content = f.read()
    
    # Заменяем large model pool
    content = re.sub(
        r'default_large_model_pool:\s*\n(\s*- [^\n]+\n)*',
        'default_large_model_pool:\n  - Gensyn/Qwen2.5-0.5B-Instruct\n\n',
        content,
        flags=re.MULTILINE
    )
    
    # Заменяем small model pool
    content = re.sub(
        r'default_small_model_pool:\s*\n(\s*- [^\n]+\n?)*$',
        'default_small_model_pool:\n  - Gensyn/Qwen2.5-0.5B-Instruct',
        content,
        flags=re.MULTILINE
    )
    
    with open(config_file, 'w') as f:
        f.write(content)
    print('✓ Конфигурация обновлена')
except Exception as e:
    print(f'Ошибка: {e}')
"

log "Запуск ноды в screen сессии..."
cd rl-swarm
screen -S gensyn -dm bash -c "python3 -m venv .venv && source .venv/bin/activate && exec ./run_rl_swarm.sh"

# Даем немного времени для инициализации
sleep 10

# Проверяем что screen сессия запущена
if screen -list | grep -q gensyn; then
    log "✓ Screen сессия 'gensyn' успешно запущена"
    log "Для подключения используйте: screen -r gensyn"
    log "Для отключения без завершения: Ctrl+A, затем D"
else
    log "ERROR: Не удалось запустить screen сессию"
    exit 1
fi

log "=== Перезапуск Gensyn ноды завершен ==="
