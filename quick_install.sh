#!/bin/bash

# 🚀 Быстрая установка Minecraft Clicker для univappschedule.ru

DOMAIN="univappschedule.ru"

echo "🚀 Быстрая установка для $DOMAIN..."

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
elif [[ -f "/root/app.py" ]]; then
    cp /root/app.py . 2>/dev/null
    cp -r /root/templates . 2>/dev/null
    echo "✅ Файлы скопированы из /root"
else
    echo "⚠️ Файлы проекта не найдены!"
    echo "Скопируйте файлы app.py и templates/ в /var/www/minecraft"
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

# Запускаем приложение в фоне
echo "▶️ Запускаем приложение..."
cd /var/www/minecraft
nohup python3 app.py > app.log 2>&1 &

# Ждем запуска
sleep 3

# Получаем SSL
echo "🔒 Получаем SSL сертификат..."
certbot --nginx -d $DOMAIN -d www.$DOMAIN --non-interactive --agree-tos --email $EMAIL --redirect

# Создаем автозапуск
echo "🔄 Настраиваем автозапуск..."
cat > /etc/systemd/system/minecraft-app.service << 'EOF'
[Unit]
Description=Minecraft Clicker App
After=network.target

[Service]
Type=simple
WorkingDirectory=/var/www/minecraft
ExecStart=/usr/bin/python3 app.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Останавливаем старый процесс и запускаем через systemd
pkill -f "python3 app.py"
systemctl daemon-reload
systemctl enable minecraft-app
systemctl start minecraft-app

echo ""
echo "✅ Готово!"
echo "🌐 Сайт: https://$DOMAIN"
echo "📋 Логи: journalctl -u minecraft-app -f"
echo "🔄 Перезапуск: systemctl restart minecraft-app"
echo ""
echo "⚠️ Не забудьте:"
echo "1. Настроить токен бота в /var/www/minecraft/app.py"
echo "2. Настроить RCON параметры Minecraft"
echo "3. Направить DNS домена на этот сервер" 