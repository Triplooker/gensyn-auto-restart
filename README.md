# Автоматический перезапуск Gensyn ноды

Этот репозиторий содержит скрипты для автоматического перезапуска Gensyn ноды каждые 8 часов.

## Файлы

- `gensyn-auto-restart.sh` - Основной скрипт перезапуска
- `gensyn-restart.service` - Systemd service файл
- `gensyn-restart.timer` - Systemd timer файл для автоматического запуска каждые 8 часов

## Установка

### 1. Скачивание файлов

```bash
# Создайте папку для скриптов (если еще не существует)
cd /root

# Скачайте все файлы
wget https://raw.githubusercontent.com/Triplooker/gensyn-auto-restart/main/gensyn-auto-restart.sh
wget https://raw.githubusercontent.com/Triplooker/gensyn-auto-restart/main/gensyn-restart.service
wget https://raw.githubusercontent.com/Triplooker/gensyn-auto-restart/main/gensyn-restart.timer

# Сделайте скрипт исполняемым
chmod +x gensyn-auto-restart.sh
```

### 2. Установка systemd сервисов

```bash
# Скопируйте файлы в systemd директорию
sudo cp gensyn-restart.service /etc/systemd/system/
sudo cp gensyn-restart.timer /etc/systemd/system/

# Перезагрузите systemd конфигурацию
sudo systemctl daemon-reload
```

### 3. Запуск автоматического перезапуска

```bash
# Включите и запустите timer
sudo systemctl enable gensyn-restart.timer
sudo systemctl start gensyn-restart.timer

# Проверьте статус timer'а
sudo systemctl status gensyn-restart.timer

# Посмотрите когда будет следующий запуск
sudo systemctl list-timers gensyn-restart.timer
```

## Управление

### Проверка статуса

```bash
# Статус timer'а
sudo systemctl status gensyn-restart.timer

# Статус service
sudo systemctl status gensyn-restart.service

# Журнал перезапусков
sudo journalctl -u gensyn-restart.service -f

# Логи скрипта
tail -f /var/log/gensyn-restart.log
```

### Ручной запуск

```bash
# Запустить перезапуск немедленно
sudo systemctl start gensyn-restart.service

# Или запустить скрипт напрямую
sudo /root/gensyn-auto-restart.sh
```

### Остановка автоматического перезапуска

```bash
# Остановить и отключить timer
sudo systemctl stop gensyn-restart.timer
sudo systemctl disable gensyn-restart.timer
```

### Изменение интервала

Чтобы изменить интервал перезапуска, отредактируйте файл `/etc/systemd/system/gensyn-restart.timer`:

```bash
sudo nano /etc/systemd/system/gensyn-restart.timer
```

Измените строку `OnUnitActiveSec=8h` на нужный интервал:
- `OnUnitActiveSec=4h` - каждые 4 часа
- `OnUnitActiveSec=12h` - каждые 12 часов
- `OnUnitActiveSec=1d` - каждый день

После изменения:
```bash
sudo systemctl daemon-reload
sudo systemctl restart gensyn-restart.timer
```

## Что делает скрипт

1. **Завершает** существующую screen сессию `gensyn`
2. **Создает резервную копию** важных файлов (`swarm.pem`, `userData.json`, `userApiKey.json`)
3. **Удаляет** старую папку `rl-swarm`
4. **Обновляет** системные пакеты
5. **Клонирует** свежую версию репозитория
6. **Загружает** актуальный `run_rl_swarm.sh`
7. **Восстанавливает** резервные файлы
8. **Настраивает** модель Qwen2.5-0.5B-Instruct
9. **Запускает** ноду в новой screen сессии `gensyn`
10. **Логирует** все действия в `/var/log/gensyn-restart.log`

## Подключение к ноде

После автоматического перезапуска нода будет работать в screen сессии:

```bash
# Подключиться к ноде
screen -r gensyn

# Отключиться БЕЗ завершения ноды (важно!)
# Нажмите Ctrl+A, затем D
```

## Устранение неполадок

### Проверка логов

```bash
# Системные логи
sudo journalctl -u gensyn-restart.service -n 50

# Логи скрипта
tail -50 /var/log/gensyn-restart.log

# Список screen сессий
screen -list
```

### Если нода не запускается

1. Проверьте что все необходимые файлы присутствуют
2. Убедитесь что у скрипта есть права на запись в `/var/log/`
3. Проверьте что `screen` установлен: `sudo apt install screen`

### Права доступа

Убедитесь что скрипт имеет правильные права:

```bash
chmod +x /root/gensyn-auto-restart.sh
sudo touch /var/log/gensyn-restart.log
sudo chown root:root /var/log/gensyn-restart.log
```

## Безопасность

- Скрипт запускается от имени root
- Все важные файлы резервируются перед перезапуском
- Логирование всех действий
- Проверка успешности запуска screen сессии

---

**Важно**: Убедитесь что у вас есть актуальные файлы `swarm.pem`, `userData.json` и `userApiKey.json` перед первым запуском!
