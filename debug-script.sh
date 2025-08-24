#!/bin/bash

echo "🔍 Диагностика проблемы с запуском Gensyn ноды..."

# Переходим в папку rl-swarm
cd /root/rl-swarm

echo "📁 Проверяем файлы в rl-swarm:"
ls -la | head -10

echo ""
echo "📄 Проверяем run_rl_swarm.sh:"
ls -la run_rl_swarm.sh
head -10 run_rl_swarm.sh

echo ""
echo "🔧 Тестируем создание виртуального окружения:"
rm -rf .venv
python3 -m venv .venv
if [ $? -eq 0 ]; then
    echo "✅ Виртуальное окружение создано успешно"
else
    echo "❌ Ошибка создания виртуального окружения"
fi

echo ""
echo "🔧 Тестируем активацию виртуального окружения:"
source .venv/bin/activate
if [ $? -eq 0 ]; then
    echo "✅ Виртуальное окружение активировано успешно"
    echo "Python path: $(which python3)"
    echo "Pip path: $(which pip)"
else
    echo "❌ Ошибка активации виртуального окружения"
fi

echo ""
echo "🔧 Пробуем запустить run_rl_swarm.sh в фоновом режиме на 10 секунд:"
timeout 10 ./run_rl_swarm.sh &
SCRIPT_PID=$!
sleep 10
kill $SCRIPT_PID 2>/dev/null || echo "Процесс уже завершился"

echo ""
echo "🔧 Проверим последние строки из логов системы:"
journalctl --no-pager -n 5 | grep -i error || echo "Критических ошибок не найдено"

echo ""
echo "🔧 Пробуем запустить в screen с детальным логированием:"
screen -S debug-gensyn -dm bash -c '
cd /root/rl-swarm
echo "=== DEBUG START ===" > /tmp/debug-gensyn.log
echo "PWD: $(pwd)" >> /tmp/debug-gensyn.log
echo "USER: $(whoami)" >> /tmp/debug-gensyn.log
echo "PATH: $PATH" >> /tmp/debug-gensyn.log
python3 -m venv .venv >> /tmp/debug-gensyn.log 2>&1
echo "VENV created with code: $?" >> /tmp/debug-gensyn.log
source .venv/bin/activate >> /tmp/debug-gensyn.log 2>&1
echo "VENV activated with code: $?" >> /tmp/debug-gensyn.log
echo "Starting run_rl_swarm.sh..." >> /tmp/debug-gensyn.log
timeout 15 ./run_rl_swarm.sh >> /tmp/debug-gensyn.log 2>&1
echo "Script finished with code: $?" >> /tmp/debug-gensyn.log
echo "=== DEBUG END ===" >> /tmp/debug-gensyn.log
'

sleep 5
echo ""
echo "📋 Результат debug screen сессии:"
if [ -f /tmp/debug-gensyn.log ]; then
    cat /tmp/debug-gensyn.log
else
    echo "❌ Лог файл не создан"
fi

echo ""
echo "🖥️ Активные screen сессии:"
screen -ls
