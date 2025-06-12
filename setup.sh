#!/bin/bash

# 🚀 Автоматическая настройка Minecraft Clicker на Linux сервере

set -e  # Остановить выполнение при ошибке

echo "🚀 Начинаем настройку Minecraft Clicker..."

# Проверка прав root
if [[ $EUID -eq 0 ]]; then
   echo "❌ Не запускайте этот скрипт под root! Используйте sudo для отдельных команд."
   exit 1
fi

# Запрос домена
read -p "🌐 Введите ваш домен (например: yourdomain.tk): " DOMAIN
if [[ -z "$DOMAIN" ]]; then
    echo "❌ Домен не может быть пустым!"
    exit 1
fi

# Обновление системы
echo "📦 Обновляем систему..."
sudo apt update
sudo apt upgrade -y

# Установка необходимых пакетов
echo "🔧 Устанавливаем необходимые пакеты..."
sudo apt install -y python3 python3-pip python3-venv nginx certbot python3-certbot-nginx git ufw

# Создание директории проекта
echo "📁 Создаем директории..."
sudo mkdir -p /var/www/minecraft-clicker
sudo chown $USER:$USER /var/www/minecraft-clicker
cd /var/www/minecraft-clicker

# Копирование файлов проекта
echo "📋 Копируем файлы проекта..."
cp ~/telegramminecraft/* . 2>/dev/null || echo "⚠️  Скопируйте файлы проекта вручную в /var/www/minecraft-clicker"

# Создание виртуального окружения
echo "🐍 Создаем виртуальное окружение Python..."
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip

# Установка зависимостей Python
echo "📦 Устанавливаем зависимости Python..."
pip install Flask python-telegram-bot mcrcon

# Обновление конфигурации в app.py
echo "⚙️  Обновляем конфигурацию..."
sed -i "s|WEBAPP_URL = \".*\"|WEBAPP_URL = \"https://$DOMAIN\"|g" app.py

# Создание конфигурации Nginx
echo "🌐 Настраиваем Nginx..."
sudo tee /etc/nginx/sites-available/minecraft-clicker > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_redirect off;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF

# Активация конфигурации Nginx
sudo ln -sf /etc/nginx/sites-available/minecraft-clicker /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx

# Создание systemd сервиса
echo "🚀 Создаем systemd сервис..."
sudo tee /etc/systemd/system/minecraft-clicker.service > /dev/null <<EOF
[Unit]
Description=Minecraft Clicker Flask App
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=/var/www/minecraft-clicker
Environment=PATH=/var/www/minecraft-clicker/venv/bin
ExecStart=/var/www/minecraft-clicker/venv/bin/python app.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Запуск сервиса
sudo systemctl daemon-reload
sudo systemctl enable minecraft-clicker
sudo systemctl start minecraft-clicker

# Настройка брандмауэра
echo "🛡️  Настраиваем брандмауэр..."
sudo ufw --force enable
sudo ufw allow ssh
sudo ufw allow 'Nginx Full'

# Получение SSL сертификата
echo "🔒 Получаем SSL сертификат..."
echo "📧 Для получения SSL сертификата нужен email:"
read -p "Введите ваш email: " EMAIL

if [[ -n "$EMAIL" ]]; then
    sudo certbot --nginx -d $DOMAIN -d www.$DOMAIN --non-interactive --agree-tos --email $EMAIL
    
    # Настройка автообновления SSL
    echo "0 12 * * * /usr/bin/certbot renew --quiet" | sudo crontab -
    echo "✅ SSL сертификат установлен и настроено автообновление!"
else
    echo "⚠️  SSL сертификат не установлен. Запустите вручную:"
    echo "sudo certbot --nginx -d $DOMAIN -d www.$DOMAIN"
fi

# Создание скрипта для логов
cat > /var/www/minecraft-clicker/logs.sh <<EOF
#!/bin/bash
echo "📊 Логи приложения:"
sudo journalctl -u minecraft-clicker -f
EOF
chmod +x /var/www/minecraft-clicker/logs.sh

# Создание скрипта для перезапуска
cat > /var/www/minecraft-clicker/restart.sh <<EOF
#!/bin/bash
echo "🔄 Перезапускаем приложение..."
sudo systemctl restart minecraft-clicker
echo "✅ Перезапуск завершен!"
sudo systemctl status minecraft-clicker
EOF
chmod +x /var/www/minecraft-clicker/restart.sh

# Проверка статуса
echo "📊 Проверяем статус сервисов..."
sleep 3
sudo systemctl status nginx --no-pager
sudo systemctl status minecraft-clicker --no-pager

echo ""
echo "🎉 Настройка завершена!"
echo ""
echo "📋 Полезная информация:"
echo "🌐 Ваш сайт: https://$DOMAIN"
echo "📁 Директория проекта: /var/www/minecraft-clicker"
echo "📊 Просмотр логов: ./logs.sh"
echo "🔄 Перезапуск: ./restart.sh"
echo ""
echo "🔧 Команды для управления:"
echo "sudo systemctl status minecraft-clicker    # Статус"
echo "sudo systemctl restart minecraft-clicker   # Перезапуск"
echo "sudo systemctl stop minecraft-clicker      # Остановка"
echo "sudo systemctl start minecraft-clicker     # Запуск"
echo ""
echo "⚠️  Не забудьте:"
echo "1. Настроить DNS записи домена на IP вашего сервера"
echo "2. Обновить токен бота и настройки RCON в app.py"
echo "3. Перезапустить сервис после изменений: ./restart.sh" 