import logging
import threading
import random
import string
import time
import sqlite3
import os
from flask import Flask, request, jsonify, render_template
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup, WebAppInfo
from telegram.ext import (
    ApplicationBuilder,
    CommandHandler,
    ContextTypes,
)
from mcrcon import MCRcon

# === НАСТРОЙКИ ===
TELEGRAM_TOKEN = "7829543177:AAEiDyUhfXFDWjHxv9k8eaCwI2pZznLNJ3Q"
RCON_HOST = "proxima.minerent.net"
RCON_PORT = 25811
RCON_PASSWORD = "sanumxxx"
WEBAPP_URL = "https://univappschedule.ru"

# === База данных ===
DB_PATH = "minecraft_clicker.db"

def init_database():
    """Инициализация базы данных"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # Таблица пользователей
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS users (
            telegram_id INTEGER PRIMARY KEY,
            nickname TEXT NOT NULL,
            verified INTEGER NOT NULL DEFAULT 0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            last_active TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    # Таблица кодов верификации
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS verification_codes (
            code TEXT PRIMARY KEY,
            telegram_id INTEGER NOT NULL,
            nickname TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            expires_at TIMESTAMP NOT NULL
        )
    ''')
    
    # Индексы для быстрого поиска
    cursor.execute('''
        CREATE INDEX IF NOT EXISTS idx_users_telegram_id ON users(telegram_id)
    ''')
    
    cursor.execute('''
        CREATE INDEX IF NOT EXISTS idx_codes_expires ON verification_codes(expires_at)
    ''')
    
    conn.commit()
    conn.close()
    print("✅ База данных инициализирована")

def get_db_connection():
    """Получение подключения к базе данных"""
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row  # Для доступа к столбцам по имени
    return conn

def cleanup_expired_codes():
    """Очистка устаревших кодов верификации"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    current_time = time.time()
    cursor.execute(
        "DELETE FROM verification_codes WHERE expires_at < ?", 
        (current_time,)
    )
    
    deleted_count = cursor.rowcount
    conn.commit()
    conn.close()
    
    if deleted_count > 0:
        print(f"🧹 Удалено {deleted_count} устаревших кодов")

def get_user_by_telegram_id(telegram_id):
    """Получение пользователя по Telegram ID"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    cursor.execute(
        "SELECT * FROM users WHERE telegram_id = ?", 
        (telegram_id,)
    )
    
    user = cursor.fetchone()
    conn.close()
    
    return dict(user) if user else None

def create_user(telegram_id, nickname):
    """Создание нового пользователя"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        cursor.execute(
            """INSERT INTO users (telegram_id, nickname, verified) 
               VALUES (?, ?, 0)""",
            (telegram_id, nickname)
        )
        conn.commit()
        conn.close()
        return True
    except sqlite3.IntegrityError:
        # Пользователь уже существует
        conn.close()
        return False

def verify_user(telegram_id):
    """Верификация пользователя"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    cursor.execute(
        "UPDATE users SET verified = 1, last_active = CURRENT_TIMESTAMP WHERE telegram_id = ?",
        (telegram_id,)
    )
    
    success = cursor.rowcount > 0
    conn.commit()
    conn.close()
    
    return success

def update_user_activity(telegram_id):
    """Обновление времени последней активности пользователя"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    cursor.execute(
        "UPDATE users SET last_active = CURRENT_TIMESTAMP WHERE telegram_id = ?",
        (telegram_id,)
    )
    
    conn.commit()
    conn.close()

def create_verification_code(telegram_id, nickname):
    """Создание кода верификации"""
    # Удаляем старые коды для этого пользователя
    conn = get_db_connection()
    cursor = conn.cursor()
    
    cursor.execute(
        "DELETE FROM verification_codes WHERE telegram_id = ?",
        (telegram_id,)
    )
    
    # Генерируем новый код
    code = ''.join(random.choices(string.digits, k=6))
    expires_at = time.time() + 600  # 10 минут
    
    cursor.execute(
        """INSERT INTO verification_codes (code, telegram_id, nickname, expires_at)
           VALUES (?, ?, ?, ?)""",
        (code, telegram_id, nickname, expires_at)
    )
    
    conn.commit()
    conn.close()
    
    return code

def get_verification_code(code):
    """Получение данных кода верификации"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    cursor.execute(
        "SELECT * FROM verification_codes WHERE code = ?",
        (code,)
    )
    
    code_data = cursor.fetchone()
    conn.close()
    
    return dict(code_data) if code_data else None

def delete_verification_code(code):
    """Удаление использованного кода"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    cursor.execute(
        "DELETE FROM verification_codes WHERE code = ?",
        (code,)
    )
    
    conn.commit()
    conn.close()

def get_user_stats():
    """Получение статистики пользователей"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    cursor.execute("SELECT COUNT(*) as total FROM users")
    total = cursor.fetchone()['total']
    
    cursor.execute("SELECT COUNT(*) as verified FROM users WHERE verified = 1")
    verified = cursor.fetchone()['verified']
    
    conn.close()
    
    return {
        'total_users': total,
        'verified_users': verified,
        'unverified_users': total - verified
    }

# === Flask-приложение ===
flask_app = Flask(__name__)

@flask_app.route("/")
def index():
    return render_template("index.html")

@flask_app.route("/api/register", methods=["POST"])
def register():
    """Регистрация нового пользователя с вводом ника"""
    data = request.get_json()
    user_id = data.get("user_id")
    nickname = data.get("nickname", "").strip()

    if not user_id or not nickname:
        return jsonify({"error": "Необходимо указать ник"}), 400

    # Проверяем валидность ника Minecraft (3-16 символов, буквы и цифры)
    if not (3 <= len(nickname) <= 16) or not nickname.replace("_", "").isalnum():
        return jsonify({"error": "Неверный формат ника Minecraft"}), 400

    # Проверяем, существует ли уже пользователь
    existing_user = get_user_by_telegram_id(user_id)
    if existing_user:
        # Обновляем ник если изменился
        if existing_user['nickname'] != nickname:
            conn = get_db_connection()
            cursor = conn.cursor()
            cursor.execute(
                "UPDATE users SET nickname = ?, verified = 0 WHERE telegram_id = ?",
                (nickname, user_id)
            )
            conn.commit()
            conn.close()
    else:
        # Создаем нового пользователя
        create_user(user_id, nickname)

    # Генерируем код верификации
    code = create_verification_code(user_id, nickname)

    # Отправляем код в игру
    try:
        with MCRcon(RCON_HOST, RCON_PASSWORD, port=RCON_PORT) as mcr:
            mcr.command(f"title {nickname} title {{\"text\":\"КОД ВЕРИФИКАЦИИ\",\"color\":\"gold\",\"bold\":true}}")
            mcr.command(f"title {nickname} subtitle {{\"text\":\"{code}\",\"color\":\"yellow\",\"bold\":true}}")
            mcr.command(f"tellraw {nickname} [{{\"text\":\"Ваш код верификации: \",\"color\":\"green\"}},{{\"text\":\"{code}\",\"color\":\"yellow\",\"bold\":true}}]")
            mcr.command(f"tellraw {nickname} [{{\"text\":\"Код действителен 10 минут\",\"color\":\"gray\"}}]")
    except Exception as e:
        return jsonify({"error": f"Ошибка отправки кода в игру: {str(e)}"}), 500

    return jsonify({
        "success": True,
        "message": "Код отправлен в игру! Введите его для подтверждения."
    })

@flask_app.route("/api/verify", methods=["POST"])
def verify():
    """Верификация пользователя по коду"""
    data = request.get_json()
    user_id = data.get("user_id")
    code = data.get("code", "").strip()

    if not user_id or not code:
        return jsonify({"error": "Необходимо указать код"}), 400

    # Очищаем устаревшие коды
    cleanup_expired_codes()

    # Проверяем код
    code_data = get_verification_code(code)
    if not code_data:
        return jsonify({"error": "Неверный или устаревший код"}), 400

    # Проверяем, что код принадлежит этому пользователю
    if code_data["telegram_id"] != user_id:
        return jsonify({"error": "Код не принадлежит вам"}), 400

    # Проверяем, что код не устарел
    if time.time() > code_data["expires_at"]:
        delete_verification_code(code)
        return jsonify({"error": "Код истек. Запросите новый код."}), 400

    # Верифицируем пользователя
    if verify_user(user_id):
        delete_verification_code(code)
        return jsonify({
            "success": True,
            "message": "Верификация прошла успешно! Добро пожаловать в игру!"
        })
    else:
        return jsonify({"error": "Ошибка верификации"}), 500

@flask_app.route("/api/user_status", methods=["POST"])
def user_status():
    """Проверка статуса пользователя"""
    data = request.get_json()
    user_id = data.get("user_id")

    if not user_id:
        return jsonify({"error": "user_id required"}), 400

    user = get_user_by_telegram_id(user_id)
    if not user:
        return jsonify({"registered": False, "verified": False})

    # Обновляем время последней активности
    if user['verified']:
        update_user_activity(user_id)

    return jsonify({
        "registered": True,
        "verified": bool(user["verified"]),
        "nickname": user["nickname"]
    })

@flask_app.route("/api/tap", methods=["POST"])
def tap():
    data = request.get_json()
    user_id = data.get("user_id")
    
    user = get_user_by_telegram_id(user_id)
    if not user or not user["verified"]:
        return jsonify({"error": "Пользователь не верифицирован"}), 400

    nick = user["nickname"]
    
    # Обновляем активность
    update_user_activity(user_id)

    try:
        with MCRcon(RCON_HOST, RCON_PASSWORD, port=RCON_PORT) as mcr:
            mcr.command(f"scoreboard players add {nick} HKC 1")
            res = mcr.command(f"scoreboard players get {nick} HKC")
        score = int(res.split("has")[1].strip().split()[0])
        return jsonify({"score": score})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@flask_app.route("/api/balance", methods=["POST"])
def balance():
    data = request.get_json()
    user_id = data.get("user_id")
    
    user = get_user_by_telegram_id(user_id)
    if not user or not user["verified"]:
        return jsonify({"score": 0})

    nick = user["nickname"]
    
    # Обновляем активность
    update_user_activity(user_id)

    try:
        with MCRcon(RCON_HOST, RCON_PASSWORD, port=RCON_PORT) as mcr:
            res = mcr.command(f"scoreboard players get {nick} HKC")
        score = int(res.split("has")[1].strip().split()[0])
        return jsonify({"score": score})
    except:
        return jsonify({"score": 0})

@flask_app.route("/api/stats", methods=["GET"])
def stats():
    """Статистика пользователей (для админов)"""
    stats_data = get_user_stats()
    return jsonify(stats_data)

# === Telegram-бот ===
async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = update.effective_user.id
    user = get_user_by_telegram_id(user_id)
    
    if user and user['verified']:
        await update.message.reply_text(
            f"Привет, {user['nickname']}! 🎮\n"
            f"Ты уже зарегистрирован и верифицирован.\n"
            f"Нажми /clicker чтобы открыть игру!"
        )
    else:
        await update.message.reply_text(
            "Привет! 👋\n"
            "Добро пожаловать в Minecraft Кликер!\n"
            "Нажми /clicker чтобы начать регистрацию."
        )

async def open_clicker(update: Update, context: ContextTypes.DEFAULT_TYPE):
    keyboard = [[
        InlineKeyboardButton(
            "🚀 Открыть кликер",
            web_app=WebAppInfo(url=WEBAPP_URL)
        )
    ]]
    reply_markup = InlineKeyboardMarkup(keyboard)
    await update.message.reply_text("Нажми кнопку, чтобы открыть кликер:", reply_markup=reply_markup)

# === Фоновые задачи ===
def background_cleanup():
    """Фоновая очистка устаревших кодов"""
    while True:
        try:
            cleanup_expired_codes()
            time.sleep(300)  # Каждые 5 минут
        except Exception as e:
            print(f"Ошибка в фоновой очистке: {e}")
            time.sleep(60)

# === Фоновый запуск Flask-сервера ===
def run_flask():
    flask_app.run(host="0.0.0.0", port=5000)

# === Запуск Telegram-бота и Flask ===
def main():
    logging.basicConfig(level=logging.INFO)
    
    # Инициализируем базу данных
    init_database()
    
    # Запускаем фоновую очистку
    threading.Thread(target=background_cleanup, daemon=True).start()
    
    # Запускаем Flask сервер
    threading.Thread(target=run_flask, daemon=True).start()

    app = ApplicationBuilder().token(TELEGRAM_TOKEN).build()
    app.add_handler(CommandHandler("start", start))
    app.add_handler(CommandHandler("clicker", open_clicker))

    print("✅ Flask и Telegram-бот запущены")
    print(f"📊 Статистика: {get_user_stats()}")
    app.run_polling()

if __name__ == "__main__":
    main()
