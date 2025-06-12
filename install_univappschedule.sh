#!/bin/bash

# 🚀 Установка Minecraft Clicker для univappschedule.ru

set -e  # Остановить выполнение при ошибке

DOMAIN="univappschedule.ru"
PROJECT_DIR="/var/www/minecraft-clicker"

echo "🚀 Начинаем установку Minecraft Clicker для $DOMAIN..."

# Проверка прав root
if [[ $EUID -eq 0 ]]; then
   echo "❌ Не запускайте этот скрипт под root! Используйте sudo для отдельных команд."
   exit 1
fi

# Проверка операционной системы
if ! command -v apt &> /dev/null; then
    echo "❌ Этот скрипт предназначен для Ubuntu/Debian систем"
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
sudo apt update
sudo apt upgrade -y

# Установка необходимых пакетов
echo "🔧 Устанавливаем необходимые пакеты..."
sudo apt install -y python3 python3-pip python3-venv nginx certbot python3-certbot-nginx git ufw curl

# Создание пользователя для приложения (если не существует)
if ! id "minecraft" &>/dev/null; then
    echo "👤 Создаем пользователя для приложения..."
    sudo useradd -r -s /bin/false minecraft
fi

# Создание директории проекта
echo "📁 Создаем директории..."
sudo mkdir -p $PROJECT_DIR
sudo chown $USER:$USER $PROJECT_DIR
cd $PROJECT_DIR

# Копирование файлов проекта
echo "📋 Копируем файлы проекта..."
if [[ -d "$HOME/telegramminecraft" ]]; then
    cp -r $HOME/telegramminecraft/* .
elif [[ -f "../app.py" ]]; then
    cp ../* .
else
    echo "⚠️  Файлы проекта не найдены. Скопируйте их вручную в $PROJECT_DIR"
    echo "Необходимые файлы: app.py, templates/, requirements.txt"
    read -p "Нажмите Enter когда файлы будут скопированы..."
fi

# Создание виртуального окружения
echo "🐍 Создаем виртуальное окружение Python..."
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip

# Установка зависимостей Python
echo "📦 Устанавливаем зависимости Python..."
if [[ -f "requirements.txt" ]]; then
    pip install -r requirements.txt
else
    pip install Flask==2.3.3 python-telegram-bot==20.6 mcrcon==1.0.0
fi

# Создание директории для базы данных
mkdir -p data
chmod 755 data

# Обновление прав на файлы
sudo chown -R $USER:www-data $PROJECT_DIR
sudo chmod -R 755 $PROJECT_DIR

# Создание конфигурации Nginx
echo "🌐 Настраиваем Nginx..."
sudo tee /etc/nginx/sites-available/minecraft-clicker > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;

    # Перенаправление на HTTPS (будет добавлено certbot)
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
        
        # WebSocket support (если понадобится)
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
sudo ln -sf /etc/nginx/sites-available/minecraft-clicker /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx

# Создание systemd сервиса
echo "🚀 Создаем systemd сервис..."
sudo tee /etc/systemd/system/minecraft-clicker.service > /dev/null <<EOF
[Unit]
Description=Minecraft Clicker Flask App for univappschedule.ru
After=network.target nginx.service
Wants=nginx.service

[Service]
Type=simple
User=$USER
Group=www-data
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
sudo systemctl daemon-reload
sudo systemctl enable minecraft-clicker

# Настройка брандмауэра
echo "🛡️  Настраиваем брандмауэр..."
sudo ufw --force enable
sudo ufw allow ssh
sudo ufw allow 'Nginx Full'
sudo ufw allow 80
sudo ufw allow 443

# Запуск приложения
echo "▶️  Запускаем приложение..."
sudo systemctl start minecraft-clicker

# Ожидание запуска приложения
echo "⏳ Ожидаем запуска приложения..."
sleep 5

# Проверка что приложение запустилось
if sudo systemctl is-active --quiet minecraft-clicker; then
    echo "✅ Приложение успешно запущено!"
else
    echo "❌ Ошибка запуска приложения. Проверьте логи:"
    sudo journalctl -u minecraft-clicker --no-pager -n 20
    echo ""
    echo "Проверьте конфигурацию в app.py и попробуйте снова."
fi

# Получение SSL сертификата
echo "🔒 Получаем SSL сертификат для $DOMAIN..."

# Проверка доступности домена
echo "🌐 Проверяем доступность домена..."
if curl -s --connect-timeout 10 http://$DOMAIN > /dev/null; then
    echo "✅ Домен доступен, получаем SSL сертификат..."
    
    sudo certbot --nginx -d $DOMAIN -d www.$DOMAIN \
        --non-interactive \
        --agree-tos \
        --email $EMAIL \
        --redirect
    
    if [[ $? -eq 0 ]]; then
        # Настройка автообновления SSL
        echo "0 12 * * * /usr/bin/certbot renew --quiet && /usr/bin/systemctl reload nginx" | sudo crontab -
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
    echo "Затем запустите: sudo certbot --nginx -d $DOMAIN -d www.$DOMAIN"
fi

# Создание полезных скриптов
echo "📝 Создаем полезные скрипты..."

# Скрипт для просмотра логов
cat > $PROJECT_DIR/logs.sh <<EOF
#!/bin/bash
echo "📊 Логи приложения Minecraft Clicker:"
echo "======================================="
sudo journalctl -u minecraft-clicker -f --no-pager
EOF
chmod +x $PROJECT_DIR/logs.sh

# Скрипт для перезапуска
cat > $PROJECT_DIR/restart.sh <<EOF
#!/bin/bash
echo "🔄 Перезапускаем Minecraft Clicker..."
sudo systemctl restart minecraft-clicker
echo "✅ Перезапуск завершен!"
echo ""
echo "📊 Статус сервиса:"
sudo systemctl status minecraft-clicker --no-pager -l
EOF
chmod +x $PROJECT_DIR/restart.sh

# Скрипт для обновления
cat > $PROJECT_DIR/update.sh <<EOF
#!/bin/bash
echo "🔄 Обновление Minecraft Clicker..."
cd $PROJECT_DIR

# Бэкап базы данных
if [[ -f "minecraft_clicker.db" ]]; then
    cp minecraft_clicker.db minecraft_clicker.db.backup.\$(date +%Y%m%d_%H%M%S)
    echo "✅ Бэкап базы данных создан"
fi

# Активация виртуального окружения
source venv/bin/activate

# Обновление зависимостей (если есть новый requirements.txt)
if [[ -f "requirements.txt" ]]; then
    pip install -r requirements.txt
fi

# Перезапуск сервиса
sudo systemctl restart minecraft-clicker

echo "✅ Обновление завершено!"
./restart.sh
EOF
chmod +x $PROJECT_DIR/update.sh

# Скрипт для проверки статуса
cat > $PROJECT_DIR/status.sh <<EOF
#!/bin/bash
echo "📊 Статус Minecraft Clicker для $DOMAIN"
echo "========================================"
echo ""

echo "🚀 Приложение:"
sudo systemctl status minecraft-clicker --no-pager

echo ""
echo "🌐 Nginx:"
sudo systemctl status nginx --no-pager

echo ""
echo "🔒 SSL сертификат:"
sudo certbot certificates

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
sudo systemctl status nginx --no-pager -l | head -10

echo ""
echo "📊 Статус приложения:"
sudo systemctl status minecraft-clicker --no-pager -l | head -10

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
echo "📊 Статус системы:     ./status.sh"
echo "📋 Просмотр логов:     ./logs.sh"
echo "🔄 Перезапуск:         ./restart.sh"
echo "⬆️  Обновление:        ./update.sh"
echo ""
echo "🛠️  Команды systemctl:"
echo "sudo systemctl status minecraft-clicker     # Статус"
echo "sudo systemctl restart minecraft-clicker    # Перезапуск"
echo "sudo systemctl stop minecraft-clicker       # Остановка"
echo "sudo systemctl start minecraft-clicker      # Запуск"
echo "sudo journalctl -u minecraft-clicker -f     # Логи в реальном времени"
echo ""
echo "⚠️  Важные напоминания:"
echo "1. ✅ Убедитесь что DNS A-запись $DOMAIN направлена на IP этого сервера"
echo "2. ✅ Обновите токен Telegram бота в app.py"
echo "3. ✅ Настройте RCON параметры Minecraft сервера в app.py"
echo "4. ✅ После изменений в app.py выполните: ./restart.sh"
echo ""
echo "🔗 Быстрая проверка:"
echo "curl -I https://$DOMAIN" 