#!/bin/bash

# 🚀 Установка Minecraft Clicker для univappschedule.ru (версия для root)

set -e  # Остановить выполнение при ошибке

DOMAIN="univappschedule.ru"
PROJECT_DIR="/var/www/minecraft-clicker"
APP_USER="minecraft"

echo "🚀 Начинаем установку Minecraft Clicker для $DOMAIN..."

# Проверка что мы под root
if [[ $EUID -ne 0 ]]; then
   echo "❌ Этот скрипт должен запускаться под root!"
   echo "Используйте: sudo ./install_as_root.sh"
   exit 1
fi

echo "📧 Для SSL сертификата введите ваш email:"
read -p "Email: " EMAIL
if [[ -z "$EMAIL" ]]; then
    echo "❌ Email обязателен для SSL сертификата!"
    exit 1
fi

# Обновление системы
echo "📦 Обновляем систему..."
apt update
apt upgrade -y

# Установка необходимых пакетов
echo "🔧 Устанавливаем необходимые пакеты..."
apt install -y python3 python3-pip python3-venv nginx certbot python3-certbot-nginx git ufw curl

# Создание пользователя для приложения
echo "👤 Создаем пользователя для приложения..."
if ! id "$APP_USER" &>/dev/null; then
    useradd -r -m -s /bin/bash $APP_USER
    echo "✅ Пользователь $APP_USER создан"
else
    echo "✅ Пользователь $APP_USER уже существует"
fi

# Создание директории проекта
echo "📁 Создаем директории..."
mkdir -p $PROJECT_DIR
cd $PROJECT_DIR

# Копирование файлов проекта
echo "📋 Копируем файлы проекта..."
if [[ -d "/root/telegramminecraft" ]]; then
    cp -r /root/telegramminecraft/* .
    echo "✅ Файлы скопированы из /root/telegramminecraft"
elif [[ -f "/root/app.py" ]]; then
    cp /root/* .
    echo "✅ Файлы скопированы из /root"
else
    echo "⚠️  Файлы проекта не найдены в /root"
    echo "Необходимые файлы: app.py, templates/, requirements.txt"
    read -p "Нажмите Enter когда файлы будут скопированы в $PROJECT_DIR..."
fi

# Установка прав на файлы
chown -R $APP_USER:$APP_USER $PROJECT_DIR

# Создание виртуального окружения от имени пользователя
echo "🐍 Создаем виртуальное окружение Python..."
sudo -u $APP_USER python3 -m venv $PROJECT_DIR/venv
sudo -u $APP_USER $PROJECT_DIR/venv/bin/pip install --upgrade pip

# Установка зависимостей Python
echo "📦 Устанавливаем зависимости Python..."
if [[ -f "requirements.txt" ]]; then
    sudo -u $APP_USER $PROJECT_DIR/venv/bin/pip install -r requirements.txt
else
    sudo -u $APP_USER $PROJECT_DIR/venv/bin/pip install Flask==2.3.3 python-telegram-bot==20.6 mcrcon==1.0.0
fi

# Создание директории для базы данных
sudo -u $APP_USER mkdir -p $PROJECT_DIR/data
chmod 755 $PROJECT_DIR/data

# Создание конфигурации Nginx
echo "🌐 Настраиваем Nginx..."
tee /etc/nginx/sites-available/minecraft-clicker > /dev/null <<EOF
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
        
        # Таймауты
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Размер буфера
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
    
    # Кэширование статических файлов
    location ~* \.(css|js|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
    }
}
EOF

# Активация конфигурации Nginx
ln -sf /etc/nginx/sites-available/minecraft-clicker /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl restart nginx

# Создание systemd сервиса
echo "🚀 Создаем systemd сервис..."
tee /etc/systemd/system/minecraft-clicker.service > /dev/null <<EOF
[Unit]
Description=Minecraft Clicker Flask App for univappschedule.ru
After=network.target nginx.service
Wants=nginx.service

[Service]
Type=simple
User=$APP_USER
Group=$APP_USER
WorkingDirectory=$PROJECT_DIR
Environment=PATH=$PROJECT_DIR/venv/bin
Environment=FLASK_ENV=production
Environment=PYTHONPATH=$PROJECT_DIR
ExecStart=$PROJECT_DIR/venv/bin/python app.py
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=10
KillMode=mixed
TimeoutStopSec=30

# Безопасность
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$PROJECT_DIR
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

# Запуск сервиса
systemctl daemon-reload
systemctl enable minecraft-clicker

# Настройка брандмауэра
echo "🛡️  Настраиваем брандмауэр..."
ufw --force enable
ufw allow ssh
ufw allow 'Nginx Full'
ufw allow 80
ufw allow 443

# Запуск приложения
echo "▶️  Запускаем приложение..."
systemctl start minecraft-clicker

# Ожидание запуска приложения
echo "⏳ Ожидаем запуска приложения..."
sleep 5

# Проверка что приложение запустилось
if systemctl is-active --quiet minecraft-clicker; then
    echo "✅ Приложение успешно запущено!"
else
    echo "❌ Ошибка запуска приложения. Проверьте логи:"
    journalctl -u minecraft-clicker --no-pager -n 20
    echo ""
    echo "Проверьте конфигурацию в app.py и попробуйте снова."
fi

# Получение SSL сертификата
echo "🔒 Получаем SSL сертификат для $DOMAIN..."

# Проверка доступности домена
echo "🌐 Проверяем доступность домена..."
if curl -s --connect-timeout 10 http://$DOMAIN > /dev/null; then
    echo "✅ Домен доступен, получаем SSL сертификат..."
    
    certbot --nginx -d $DOMAIN -d www.$DOMAIN \
        --non-interactive \
        --agree-tos \
        --email $EMAIL \
        --redirect
    
    if [[ $? -eq 0 ]]; then
        # Настройка автообновления SSL
        echo "0 12 * * * /usr/bin/certbot renew --quiet && /usr/bin/systemctl reload nginx" | crontab -
        echo "✅ SSL сертификат установлен и настроено автообновление!"
    else
        echo "❌ Ошибка получения SSL сертификата."
        echo "Возможные причины:"
        echo "1. Домен не направлен на этот сервер"
        echo "2. Порты 80/443 заблокированы"
        echo "3. Nginx не работает"
    fi
else
    echo "⚠️  Домен недоступен. SSL сертификат не установлен."
    echo "Убедитесь что DNS записи домена направлены на IP этого сервера"
    echo "Затем запустите: certbot --nginx -d $DOMAIN -d www.$DOMAIN"
fi

# Создание полезных скриптов
echo "📝 Создаем полезные скрипты..."

# Скрипт для просмотра логов
tee $PROJECT_DIR/logs.sh > /dev/null <<EOF
#!/bin/bash
echo "📊 Логи приложения Minecraft Clicker:"
echo "======================================="
journalctl -u minecraft-clicker -f --no-pager
EOF
chmod +x $PROJECT_DIR/logs.sh

# Скрипт для перезапуска
tee $PROJECT_DIR/restart.sh > /dev/null <<EOF
#!/bin/bash
echo "🔄 Перезапускаем Minecraft Clicker..."
systemctl restart minecraft-clicker
echo "✅ Перезапуск завершен!"
echo ""
echo "📊 Статус сервиса:"
systemctl status minecraft-clicker --no-pager -l
EOF
chmod +x $PROJECT_DIR/restart.sh

# Скрипт для статуса
tee $PROJECT_DIR/status.sh > /dev/null <<EOF
#!/bin/bash
echo "📊 Статус Minecraft Clicker для $DOMAIN"
echo "========================================"
echo ""

echo "🚀 Приложение:"
systemctl status minecraft-clicker --no-pager

echo ""
echo "🌐 Nginx:"
systemctl status nginx --no-pager

echo ""
echo "🔒 SSL сертификат:"
certbot certificates

echo ""
echo "📈 Использование ресурсов:"
ps aux | grep "python.*app.py" | grep -v grep || echo "Приложение не запущено"

echo ""
echo "🌍 Доступность сайта:"
curl -s -o /dev/null -w "HTTP Status: %{http_code} | Total time: %{time_total}s\n" https://$DOMAIN || echo "Сайт недоступен"
EOF
chmod +x $PROJECT_DIR/status.sh

# Финальная проверка
echo ""
echo "📊 Финальная проверка сервисов..."
sleep 3

echo ""
echo "📊 Статус Nginx:"
systemctl status nginx --no-pager -l | head -10

echo ""
echo "📊 Статус приложения:"
systemctl status minecraft-clicker --no-pager -l | head -10

echo ""
echo "🎉 Установка завершена!"
echo "============================================"
echo ""
echo "📋 Информация о вашем сайте:"
echo "🌐 URL: https://$DOMAIN"
echo "📁 Директория: $PROJECT_DIR"
echo "🗄️  База данных: $PROJECT_DIR/minecraft_clicker.db"
echo ""
echo "🔧 Полезные команды:"
echo "📊 Статус системы:     $PROJECT_DIR/status.sh"
echo "📋 Просмотр логов:     $PROJECT_DIR/logs.sh"
echo "🔄 Перезапуск:         $PROJECT_DIR/restart.sh"
echo ""
echo "🛠️  Команды systemctl:"
echo "systemctl status minecraft-clicker     # Статус"
echo "systemctl restart minecraft-clicker    # Перезапуск"
echo "systemctl stop minecraft-clicker       # Остановка"
echo "systemctl start minecraft-clicker      # Запуск"
echo "journalctl -u minecraft-clicker -f     # Логи в реальном времени"
echo ""
echo "⚠️  Важные напоминания:"
echo "1. ✅ Убедитесь что DNS A-запись $DOMAIN направлена на IP этого сервера"
echo "2. ✅ Обновите токен Telegram бота в $PROJECT_DIR/app.py"
echo "3. ✅ Настройте RCON параметры Minecraft сервера в $PROJECT_DIR/app.py"
echo "4. ✅ После изменений в app.py выполните: $PROJECT_DIR/restart.sh"
echo ""
echo "🔗 Быстрая проверка:"
echo "curl -I https://$DOMAIN"

echo ""
echo "📝 Для редактирования конфига:"
echo "nano $PROJECT_DIR/app.py" 