#!/bin/bash

echo "🚀 Установка автоматического перезапуска Gensyn ноды каждые 8 часов..."

# Скачиваем обновленные скрипты
echo "📥 Скачиваем последние версии скриптов..."
wget -q -O /root/gensyn-auto-restart.sh https://raw.githubusercontent.com/Triplooker/gensyn-auto-restart/master/gensyn-auto-restart.sh
wget -q -O /root/gensyn-status.sh https://raw.githubusercontent.com/Triplooker/gensyn-auto-restart/master/gensyn-status.sh

chmod +x /root/gensyn-auto-restart.sh
chmod +x /root/gensyn-status.sh

# Создаем cron задачу для запуска каждые 8 часов
echo "⏰ Настраиваем автоматический перезапуск каждые 8 часов..."
echo "0 */8 * * * /root/gensyn-auto-restart.sh >/dev/null 2>&1" | crontab -

# Создаем лог файл
touch /var/log/gensyn-restart.log

echo "✅ Настройка завершена!"
echo ""
echo "🔄 Запускаем первый перезапуск прямо сейчас..."
echo ""

# ЗАПУСКАЕМ СРАЗУ ПЕРВЫЙ ПЕРЕЗАПУСК
/root/gensyn-auto-restart.sh

echo ""
echo "🎉 Готово! Автоматический перезапуск каждые 8 часов активен"
echo ""
echo "📋 Полезные команды:"
echo "  /root/gensyn-status.sh               - проверить статус ноды"
echo "  screen -r gensyn                     - подключиться к ноде"
echo "  tail -f /var/log/gensyn-restart.log - смотреть логи"
echo "  /root/gensyn-auto-restart.sh        - запустить перезапуск сейчас"
echo "  crontab -l                          - посмотреть расписание"
echo ""
echo "⏰ Следующие автоматические перезапуски: 00:00, 08:00, 16:00 каждый день"
