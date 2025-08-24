#!/bin/bash

echo "=== GENSYN NODE STATUS ==="
echo "Дата/время: $(date)"
echo

echo "🖥️  Screen сессии:"
screen -ls | grep -E "(gensyn|No Sockets)" || echo "Нет активных screen сессий"
echo

echo "🔄 Процессы Gensyn:"
ps aux | grep -v grep | grep -i gensyn || echo "Процессы Gensyn не найдены"
echo

echo "⏰ Cron задачи:"
crontab -l | grep gensyn || echo "Cron задачи не настроены"
echo

echo "📋 Последние логи перезапуска:"
if [ -f /var/log/gensyn-restart.log ]; then
    tail -10 /var/log/gensyn-restart.log
else
    echo "Лог файл не найден"
fi
echo

echo "📁 Файлы Gensyn:"
if [ -d /root/rl-swarm ]; then
    echo "✅ Папка rl-swarm существует"
    ls -la /root/rl-swarm/ | head -5
    echo "..."
else
    echo "❌ Папка rl-swarm не найдена"
fi

echo
echo "=== END STATUS ==="
