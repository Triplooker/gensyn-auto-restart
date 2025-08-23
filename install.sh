#!/bin/bash

echo "🚀 Устанавливаем автоматический перезапуск Gensyn ноды..."

# Переходим в директорию root
cd /root

# Скачиваем файлы
echo "📥 Скачиваем файлы..."
wget -O gensyn-auto-restart.sh https://raw.githubusercontent.com/Triplooker/gensyn-auto-restart/master/gensyn-auto-restart.sh
wget -O gensyn-restart.service https://raw.githubusercontent.com/Triplooker/gensyn-auto-restart/master/gensyn-restart.service
wget -O gensyn-restart.timer https://raw.githubusercontent.com/Triplooker/gensyn-auto-restart/master/gensyn-restart.timer

# Делаем скрипт исполняемым
chmod +x gensyn-auto-restart.sh

# Копируем systemd файлы
echo "⚙️ Настраиваем systemd..."
sudo cp gensyn-restart.service /etc/systemd/system/
sudo cp gensyn-restart.timer /etc/systemd/system/

# Перезагружаем systemd
sudo systemctl daemon-reload

# Включаем и запускаем timer
echo "⏰ Запускаем автоматический перезапуск..."
sudo systemctl enable gensyn-restart.timer
sudo systemctl start gensyn-restart.timer

# Создаем лог файл
sudo touch /var/log/gensyn-restart.log
sudo chown root:root /var/log/gensyn-restart.log

echo "✅ Установка завершена!"
echo ""
echo "Автоматический перезапуск настроен каждые 8 часов."
echo "Следующий запуск будет через 1 час после загрузки системы."
echo ""
echo "Команды для управления:"
echo "  sudo systemctl status gensyn-restart.timer  - статус timer'а"
echo "  sudo systemctl start gensyn-restart.service - запустить сейчас"
echo "  tail -f /var/log/gensyn-restart.log         - просмотр логов"
echo "  screen -r gensyn                            - подключиться к ноде"
echo ""
sudo systemctl list-timers gensyn-restart.timer
