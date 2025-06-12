#!/bin/bash

# 🚀 Установка Minecraft Clicker для 1 ядра (отдельные процессы)

DOMAIN="univappschedule.ru"

echo "🚀 Установка для $DOMAIN (оптимизация для 1 ядра)..."

# Email для SSL
read -p "📧 Введите email для SSL: " EMAIL

# Обновляем систему
echo "📦 Обновляем пакеты..."
apt update && apt install -y python3 python3-pip nginx certbot python3-certbot-nginx

# Устанавливаем Python зависимости
echo "🐍 Устанавливаем Python зависимости..."
pip3 install Flask python-telegram-bot mcrcon

# Создаем директорию
mkdir -p /var/www/minecraft
cd /var/www/minecraft

# Копируем файлы проекта
echo "📋 Копируем файлы..."
if [[ -d "/root/telegramminecraft" ]]; then
    cp -r /root/telegramminecraft/* . 2>/dev/null
    echo "✅ Файлы скопированы из /root/telegramminecraft"
elif [[ -f "/root/flask_app.py" ]]; then
    cp /root/flask_app.py . 2>/dev/null
    cp /root/telegram_bot.py . 2>/dev/null
    cp -r /root/templates . 2>/dev/null
    echo "✅ Файлы скопированы из /root"
else
    echo "⚠️ Файлы проекта не найдены!"
    echo "Скопируйте файлы flask_app.py, telegram_bot.py и templates/ в /var/www/minecraft"
    echo "Нажмите Enter когда файлы будут готовы..."
    read
fi

# Настраиваем Nginx
echo "🌐 Настраиваем Nginx..."
cat > /etc/nginx/sites-available/default << 'EOF'
server {
    listen 80;
    server_name univappschedule.ru www.univappschedule.ru;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# Перезапускаем Nginx
systemctl restart nginx

# Создаем сервис для Flask
echo "🌐 Создаем сервис Flask..."
cat > /etc/systemd/system/minecraft-flask.service << 'EOF'
[Unit]
Description=Minecraft Clicker Flask App
After=network.target

[Service]
Type=simple
WorkingDirectory=/var/www/minecraft
ExecStart=/usr/bin/python3 flask_app.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Создаем сервис для Telegram бота
echo "🤖 Создаем сервис Telegram бота..."
cat > /etc/systemd/system/minecraft-bot.service << 'EOF'
[Unit]
Description=Minecraft Clicker Telegram Bot
After=network.target

[Service]
Type=simple
WorkingDirectory=/var/www/minecraft
ExecStart=/usr/bin/python3 telegram_bot.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Запускаем сервисы
echo "▶️ Запускаем сервисы..."
systemctl daemon-reload
systemctl enable minecraft-flask
systemctl enable minecraft-bot
systemctl start minecraft-flask
systemctl start minecraft-bot

# Ждем запуска
sleep 3

# Получаем SSL
echo "🔒 Получаем SSL сертификат..."
certbot --nginx -d $DOMAIN -d www.$DOMAIN --non-interactive --agree-tos --email $EMAIL --redirect

echo ""
echo "✅ Готово!"
echo "🌐 Сайт: https://$DOMAIN"
echo ""
echo "📋 Управление сервисами:"
echo "systemctl status minecraft-flask    # Статус веб-сервера"
echo "systemctl status minecraft-bot      # Статус бота"
echo "systemctl restart minecraft-flask   # Перезапуск веб-сервера"
echo "systemctl restart minecraft-bot     # Перезапуск бота"
echo ""
echo "📊 Логи:"
echo "journalctl -u minecraft-flask -f    # Логи веб-сервера"
echo "journalctl -u minecraft-bot -f      # Логи бота"
echo ""
echo "⚠️ Не забудьте:"
echo "1. Настроить токен бота в /var/www/minecraft/telegram_bot.py"
echo "2. Настроить RCON параметры в /var/www/minecraft/flask_app.py"
echo "3. Направить DNS домена на этот сервер" 