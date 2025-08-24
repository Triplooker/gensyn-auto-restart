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

# ИСПРАВЛЯЕМ run_rl_swarm.sh для совместимости 
log "Исправляем run_rl_swarm.sh для совместимости..."
cd rl-swarm

# Создаем исправленную версию с npm вместо yarn и без strict режима
sed 's/yarn install/npm install/g; s/yarn build/npm run build/g; s/yarn start/npm start/g; s/set -euo pipefail/# set -euo pipefail (disabled for compatibility)/' run_rl_swarm.sh > run_rl_swarm_fixed.sh
chmod +x run_rl_swarm_fixed.sh

# Проверяем что файл создался
if [ ! -f "./run_rl_swarm_fixed.sh" ]; then
    log "❌ Файл run_rl_swarm_fixed.sh не создался"
    log "=== Завершение с ошибкой ==="
    exit 1
fi

# Запускаем в screen с исправленным скриптом
log "Создаем screen сессию gensyn с исправленным скриптом..."
screen -S gensyn -dm bash -c "
cd /root/rl-swarm
export PATH='/root/.nvm/versions/node/v24.1.0/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
export HOME='/root'
echo 'Начинаем настройку виртуального окружения...' >> /var/log/gensyn-restart.log 2>&1
if python3 -m venv .venv; then
    echo 'Виртуальное окружение создано' >> /var/log/gensyn-restart.log 2>&1
    if source .venv/bin/activate; then
        echo 'Виртуальное окружение активировано' >> /var/log/gensyn-restart.log 2>&1
        echo \"Node version: \$(node --version)\" >> /var/log/gensyn-restart.log 2>&1
        echo \"NPM version: \$(npm --version)\" >> /var/log/gensyn-restart.log 2>&1
        echo 'Запускаем исправленный run_rl_swarm.sh с npm...' >> /var/log/gensyn-restart.log 2>&1
        exec ./run_rl_swarm_fixed.sh
    else
        echo 'Ошибка активации venv' >> /var/log/gensyn-restart.log 2>&1
        exit 1
    fi
else
    echo 'Ошибка создания venv' >> /var/log/gensyn-restart.log 2>&1
    exit 1
fi
"

# Даем время на запуск (больше времени так как npm install может быть медленным)
log "Ожидаем запуска ноды (45 секунд)..."
sleep 45

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
        sleep 15
    else
        log "❌ Screen сессия gensyn не найдена"
        # Проверяем есть ли информация в логе
        recent_logs=$(tail -8 /var/log/gensyn-restart.log | grep -E "(создано|активировано|Запускаем|Ошибка|version)" || echo "")
        if [ -n "$recent_logs" ]; then
            log "Последние этапы: $recent_logs"
        fi
        sleep 15
    fi
done

if [ "$success" = true ]; then
    log "✅ Нода перезапущена успешно (использует npm вместо yarn)"
else
    log "❌ Ошибка запуска - screen сессия не найдена или завершилась"
    log "💡 Попробуйте: screen -r gensyn для подключения или /root/gensyn-status.sh для диагностики"
fi

log "=== Завершение перезапуска ==="
