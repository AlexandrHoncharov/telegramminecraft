# 🔄 Инструкция по обновлению Minecraft Clicker

## 📋 **Быстрое обновление (рекомендуется)**

### **1. Остановите приложение:**
```bash
systemctl stop minecraft-app
# или
systemctl stop minecraft-clicker
```

### **2. Скопируйте новый файл app.py:**
```bash
# Если файлы у вас локально, скопируйте на сервер:
scp app.py root@your-server-ip:/var/www/minecraft/

# Или если файлы уже на сервере в /root/telegramminecraft:
cp /root/telegramminecraft/app.py /var/www/minecraft/
```

### **3. Перезапустите приложение:**
```bash
systemctl start minecraft-app
# или
systemctl start minecraft-clicker
```

### **4. Проверьте статус:**
```bash
systemctl status minecraft-app
# или
systemctl status minecraft-clicker
```

---

## 🔧 **Полное обновление (если что-то сломалось)**

### **1. Остановите все сервисы:**
```bash
systemctl stop minecraft-app 2>/dev/null
systemctl stop minecraft-clicker 2>/dev/null
pkill -f "python.*app.py"
```

### **2. Скопируйте все файлы проекта:**
```bash
cd /var/www/minecraft

# Создайте резервную копию
cp app.py app.py.backup

# Скопируйте новые файлы
cp /root/telegramminecraft/app.py .
cp -r /root/telegramminecraft/templates . 2>/dev/null
```

### **3. Проверьте права доступа:**
```bash
# Если создавали пользователя minecraft:
chown -R minecraft:minecraft /var/www/minecraft

# Если работаете под root:
chmod +x /var/www/minecraft/app.py
```

### **4. Перезапустите сервис:**
```bash
systemctl daemon-reload
systemctl start minecraft-app
```

---

## 📊 **Проверка работы**

### **Проверьте логи:**
```bash
# Логи приложения
journalctl -u minecraft-app -f

# Или если сервис называется minecraft-clicker
journalctl -u minecraft-clicker -f
```

### **Проверьте доступность:**
```bash
# Проверка Flask сервера
curl http://localhost:5000

# Проверка сайта
curl https://univappschedule.ru
```

### **Проверьте процессы:**
```bash
ps aux | grep python
```

---

## 🚨 **Если ничего не работает**

### **1. Полная переустановка:**
```bash
# Остановите все
systemctl stop minecraft-app 2>/dev/null
systemctl stop minecraft-clicker 2>/dev/null
pkill -f python

# Удалите старые файлы
rm -rf /var/www/minecraft/*

# Запустите установку заново
cd /root/telegramminecraft
chmod +x quick_install.sh
./quick_install.sh
```

### **2. Ручной запуск для отладки:**
```bash
cd /var/www/minecraft
python3 app.py
```

---

## 📝 **Полезные команды**

### **Управление сервисом:**
```bash
systemctl status minecraft-app     # Статус
systemctl start minecraft-app      # Запуск
systemctl stop minecraft-app       # Остановка
systemctl restart minecraft-app    # Перезапуск
systemctl enable minecraft-app     # Автозапуск
```

### **Просмотр логов:**
```bash
journalctl -u minecraft-app -f              # В реальном времени
journalctl -u minecraft-app --since today   # За сегодня
journalctl -u minecraft-app -n 50           # Последние 50 строк
```

### **Проверка конфигурации:**
```bash
nginx -t                    # Проверка Nginx
systemctl status nginx      # Статус Nginx
certbot certificates        # SSL сертификаты
```

---

## ⚡ **Быстрые исправления**

### **Если бот не отвечает:**
```bash
# Проверьте токен в app.py
nano /var/www/minecraft/app.py
# Найдите TELEGRAM_TOKEN и убедитесь что он правильный
```

### **Если сайт не открывается:**
```bash
# Проверьте Nginx
systemctl status nginx
systemctl restart nginx

# Проверьте SSL
certbot renew --dry-run
```

### **Если ошибки в базе данных:**
```bash
cd /var/www/minecraft
rm minecraft_clicker.db  # Удалит базу, создастся новая
systemctl restart minecraft-app
```

---

## 🎯 **Что изменилось в новой версии**

✅ **Исправлено:**
- Убрана ошибка "signal only works in main thread"
- Telegram-бот теперь работает в основном потоке
- Flask запускается в отдельном потоке без signal обработки

✅ **Добавлено:**
- Стабильная работа бота и веб-приложения
- Правильная обработка потоков
- Улучшенная отладка

🔧 **Настройки остались прежними:**
- База данных SQLite
- Все API endpoints
- Веб-интерфейс
- RCON подключение к Minecraft 