# 🌐 Настройка DNS для univappschedule.ru

## 📋 Что нужно сделать:

### **1. Узнайте IP адрес вашего сервера**
```bash
# На сервере выполните:
curl ifconfig.me
# Или:
wget -qO- ifconfig.me
```

### **2. Настройте DNS записи**

В панели управления вашего регистратора домена (.ru домены обычно через REG.RU, R01, Timeweb и т.д.) добавьте следующие записи:

| Тип записи | Имя | Значение | TTL |
|------------|-----|----------|-----|
| A | @ | ВАШ_IP_СЕРВЕРА | 3600 |
| A | www | ВАШ_IP_СЕРВЕРА | 3600 |
| CNAME | * | univappschedule.ru | 3600 |

**Пример для IP 198.51.100.42:**
```
A     @     198.51.100.42     3600
A     www   198.51.100.42     3600  
CNAME *     univappschedule.ru 3600
```

### **3. Проверьте DNS записи**

После настройки (может занять до 24 часов) проверьте:

```bash
# Проверка A записи
nslookup univappschedule.ru
dig univappschedule.ru

# Проверка www поддомена
nslookup www.univappschedule.ru
dig www.univappschedule.ru
```

### **4. Онлайн проверка DNS**

Используйте сервисы:
- https://whatsmydns.net
- https://dnschecker.org
- https://mxtoolbox.com/DNSLookup.aspx

Введите `univappschedule.ru` и проверьте что A записи показывают ваш IP сервера.

## ⚡ Популярные панели управления доменами .ru:

### **REG.RU:**
1. Войдите в личный кабинет
2. Мои домены → univappschedule.ru → Управление DNS
3. Добавьте записи как указано выше

### **R01.RU:**
1. Личный кабинет → Домены → univappschedule.ru
2. DNS управление → Добавить записи

### **Timeweb:**
1. Панель управления → Домены → univappschedule.ru
2. DNS записи → Добавить

### **Cloudflare (рекомендуется):**
1. Добавьте домен в Cloudflare
2. Измените NS серверы у регистратора на Cloudflare
3. В Cloudflare добавьте A записи
4. Включите "SSL/TLS" → "Full"

## 🚀 После настройки DNS:

1. **Дождитесь распространения DNS** (до 24 часов)
2. **Проверьте доступность:**
   ```bash
   curl -I http://univappschedule.ru
   ```
3. **Запустите установку на сервере:**
   ```bash
   chmod +x install_univappschedule.sh
   ./install_univappschedule.sh
   ```

## ❓ Частые проблемы:

**Домен не открывается:**
- Проверьте DNS записи
- Убедитесь что IP сервера правильный
- Проверьте что порты 80/443 открыты на сервере

**SSL не работает:**
- Убедитесь что домен направлен на сервер
- Проверьте что Nginx работает
- Запустите `sudo certbot --nginx -d univappschedule.ru`

**Приложение не отвечает:**
- Проверьте статус: `sudo systemctl status minecraft-clicker`
- Просмотрите логи: `sudo journalctl -u minecraft-clicker -f` 