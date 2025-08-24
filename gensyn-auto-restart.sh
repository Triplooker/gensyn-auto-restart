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

# Проверяем есть ли папка rl-swarm и важные файлы
if [ ! -d "rl-swarm" ]; then
    log "⚠️ Папка rl-swarm не найдена, создаем с нуля..."
else
    # Бэкапим файлы только если папка существует
    log "Создаем бэкап важных файлов..."
    mkdir -p /tmp/gensyn_backup
    cp rl-swarm/swarm.pem /tmp/gensyn_backup/ 2>/dev/null || log "⚠️ swarm.pem не найден"
    cp rl-swarm/modal-login/temp-data/userData.json /tmp/gensyn_backup/ 2>/dev/null || log "⚠️ userData.json не найден"
    cp rl-swarm/modal-login/temp-data/userApiKey.json /tmp/gensyn_backup/ 2>/dev/null || log "⚠️ userApiKey.json не найден"
fi

# Переустанавливаем
log "Переустанавливаем rl-swarm..."
rm -rf rl-swarm

# Обновляем пакеты более тихо
log "Обновляем пакеты системы..."
apt update >/dev/null 2>&1 || log "⚠️ Ошибка обновления пакетов"
apt install -y sudo screen git python3 python3-venv python3-pip curl wget >/dev/null 2>&1 || log "⚠️ Ошибка установки пакетов"

# Клонируем репозиторий с проверкой
log "Клонируем репозиторий rl-swarm..."
if ! git clone https://github.com/gensyn-ai/rl-swarm.git >/dev/null 2>&1; then
    log "❌ Ошибка клонирования репозитория rl-swarm"
    log "=== Завершение с ошибкой ==="
    exit 1
fi

# Загружаем скрипт запуска
log "Загружаем скрипт запуска..."
if ! wget -q -O rl-swarm/run_rl_swarm.sh https://raw.githubusercontent.com/Triplooker/fullgensyn/refs/heads/main/run_rl_swarm.sh; then
    log "❌ Ошибка загрузки run_rl_swarm.sh"
    log "=== Завершение с ошибкой ==="
    exit 1
fi

chmod +x rl-swarm/run_rl_swarm.sh
mkdir -p rl-swarm/modal-login/temp-data

# Восстанавливаем файлы если есть бэкап
if [ -d "/tmp/gensyn_backup" ]; then
    log "Восстанавливаем бэкап файлов..."
    cp /tmp/gensyn_backup/swarm.pem rl-swarm/ 2>/dev/null && log "✅ swarm.pem восстановлен" || log "⚠️ swarm.pem не восстановлен"
    cp /tmp/gensyn_backup/userData.json rl-swarm/modal-login/temp-data/ 2>/dev/null && log "✅ userData.json восстановлен" || log "⚠️ userData.json не восстановлен"
    cp /tmp/gensyn_backup/userApiKey.json rl-swarm/modal-login/temp-data/ 2>/dev/null && log "✅ userApiKey.json восстановлен" || log "⚠️ userApiKey.json не восстановлен"
    rm -rf /tmp/gensyn_backup
fi

# Проверяем наличие swarm.pem
if [ ! -f "rl-swarm/swarm.pem" ]; then
    log "❌ Файл swarm.pem отсутствует! Нода не может быть запущена без него."
    log "📝 Поместите файл swarm.pem в /root/rl-swarm/ и запустите скрипт снова"
    log "=== Завершение с ошибкой ==="
    exit 1
fi

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
    print('Конфигурация модели обновлена')
except Exception as e:
    print(f'Ошибка настройки модели: {e}')
" 2>&1 | while read line; do log "$line"; done

# Запускаем в screen с улучшенной проверкой
log "Запускаем ноду в screen сессии..."
cd rl-swarm

# Проверяем что мы находимся в правильной директории
if [ ! -f "./run_rl_swarm.sh" ]; then
    log "❌ Файл run_rl_swarm.sh не найден в $(pwd)"
    log "=== Завершение с ошибкой ==="
    exit 1
fi

# Создаем screen сессию с детальным логированием
log "Создаем screen сессию gensyn..."
screen -S gensyn -dm bash -c "
set -e
export PATH='$PATH'
export HOME='$HOME'
echo 'Начинаем настройку виртуального окружения...' >> /var/log/gensyn-restart.log 2>&1
python3 -m venv .venv 2>&1 || echo 'Ошибка создания venv' >> /var/log/gensyn-restart.log
echo 'Активируем виртуальное окружение...' >> /var/log/gensyn-restart.log 2>&1
source .venv/bin/activate 2>&1 || echo 'Ошибка активации venv' >> /var/log/gensyn-restart.log
echo 'Запускаем run_rl_swarm.sh...' >> /var/log/gensyn-restart.log 2>&1
exec ./run_rl_swarm.sh 2>&1
"

# Даем время на запуск
log "Ожидаем запуска ноды (20 секунд)..."
sleep 20

# Проверяем результат с несколькими попытками
success=false
for attempt in 1 2 3; do
    log "Проверка запуска (попытка $attempt)..."
    
    if screen -list | grep -q "gensyn.*Detached"; then
        log "✅ Screen сессия gensyn активна"
        success=true
        break
    elif screen -list | grep -q gensyn; then
        log "⚠️ Screen сессия найдена, но возможно не полностью запущена"
        sleep 5
    else
        log "❌ Screen сессия gensyn не найдена"
        sleep 5
    fi
done

if [ "$success" = true ]; then
    log "✅ Нода перезапущена успешно"
else
    log "❌ Ошибка запуска - проверьте логи screen сессии"
    # Пытаемся получить дополнительную информацию
    if screen -list | grep -q gensyn; then
        log "Screen сессия существует, но возможны проблемы с запуском процесса"
    fi
fi

log "=== Завершение перезапуска ==="
