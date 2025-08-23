# 🚀 Автоматический перезапуск Gensyn ноды

**ПРОСТАЯ УСТАНОВКА ОДНОЙ КОМАНДОЙ:**

```bash
curl -s https://raw.githubusercontent.com/Triplooker/gensyn-auto-restart/master/one-click-install.sh | bash
```

Всё! Теперь ваша нода будет автоматически перезапускаться каждые 8 часов.

## 📋 Что происходит после установки:

✅ Нода перезапускается каждые 8 часов  
✅ Все важные файлы сохраняются (`swarm.pem`, `userData.json`, `userApiKey.json`)  
✅ Screen сессия правильно завершается и создается новая  
✅ Логирование всех действий  

## 🔧 Полезные команды:

```bash
# Подключиться к ноде (отключиться: Ctrl+A затем D)
screen -r gensyn

# Посмотреть логи
tail -f /var/log/gensyn-restart.log

# Запустить перезапуск сейчас
/root/gensyn-auto-restart.sh

# Посмотреть расписание
crontab -l

# Удалить автоматический перезапуск
crontab -r
```

---

**Важно:** Убедитесь что у вас есть файлы `swarm.pem`, `userData.json` и `userApiKey.json` перед установкой!

Репозиторий: https://github.com/Triplooker/gensyn-auto-restart
