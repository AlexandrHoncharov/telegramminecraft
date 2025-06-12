# 🚀 Настройка сервера с доменом и HTTPS

## 📋 Предварительные требования
- Ubuntu/Debian сервер
- Root доступ или sudo права
- Зарегистрированный домен

## 🔧 Установка необходимых компонентов

### 1. Обновление системы
```bash
sudo apt update
sudo apt upgrade -y
```

### 2. Установка Python и зависимостей
```bash
sudo apt install python3 python3-pip python3-venv nginx certbot python3-certbot-nginx -y
```

### 3. Установка проекта
```bash
# Создайте директорию для проекта
sudo mkdir -p /var/www/minecraft-clicker
cd /var/www/minecraft-clicker

# Клонируйте или загрузите ваш проект
# git clone your-repo .

# Создайте виртуальное окружение
python3 -m venv venv
source venv/bin/activate

# Установите зависимости
pip install -r requirements.txt
```

## 🌐 Настройка Nginx

### 1. Создайте конфигурацию Nginx
```bash
sudo nano /etc/nginx/sites-available/minecraft-clicker
```

### 2. Добавьте конфигурацию:
```nginx
server {
    listen 80;
    server_name yourdomain.tk www.yourdomain.tk;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### 3. Активируйте конфигурацию
```bash
sudo ln -s /etc/nginx/sites-available/minecraft-clicker /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

## 🔒 Настройка SSL с Let's Encrypt

### 1. Получите SSL сертификат
```bash
sudo certbot --nginx -d yourdomain.tk -d www.yourdomain.tk
```

### 2. Настройте автообновление
```bash
sudo crontab -e
# Добавьте строку:
0 12 * * * /usr/bin/certbot renew --quiet
```

## 🚀 Настройка автозапуска приложения

### 1. Создайте systemd сервис
```bash
sudo nano /etc/systemd/system/minecraft-clicker.service
```

### 2. Добавьте конфигурацию сервиса:
```ini
[Unit]
Description=Minecraft Clicker Flask App
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=/var/www/minecraft-clicker
Environment=PATH=/var/www/minecraft-clicker/venv/bin
ExecStart=/var/www/minecraft-clicker/venv/bin/python app.py
Restart=always

[Install]
WantedBy=multi-user.target
```

### 3. Запустите сервис
```bash
sudo systemctl daemon-reload
sudo systemctl start minecraft-clicker
sudo systemctl enable minecraft-clicker
sudo systemctl status minecraft-clicker
```

## 🛡️ Настройка брандмауэра
```bash
sudo ufw allow 22
sudo ufw allow 80
sudo ufw allow 443
sudo ufw enable
```

## 📊 Проверка работы
```bash
# Проверьте статус сервисов
sudo systemctl status nginx
sudo systemctl status minecraft-clicker

# Проверьте логи
sudo journalctl -u minecraft-clicker -f
```

## 🔄 Обновление приложения
```bash
cd /var/www/minecraft-clicker
git pull  # если используете git
sudo systemctl restart minecraft-clicker
``` 