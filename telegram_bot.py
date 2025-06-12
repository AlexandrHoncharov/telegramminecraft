import logging
import sqlite3
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup, WebAppInfo
from telegram.ext import (
    ApplicationBuilder,
    CommandHandler,
    ContextTypes,
)

# === НАСТРОЙКИ ===
TELEGRAM_TOKEN = "7829543177:AAEiDyUhfXFDWjHxv9k8eaCwI2pZznLNJ3Q"
WEBAPP_URL = "https://univappschedule.ru"

# === База данных ===
DB_PATH = "minecraft_clicker.db"

def get_db_connection():
    """Получение подключения к базе данных"""
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

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

if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    
    print("🤖 Запускаем Telegram-бот...")
    
    # Создаем приложение бота
    app = ApplicationBuilder().token(TELEGRAM_TOKEN).build()
    app.add_handler(CommandHandler("start", start))
    app.add_handler(CommandHandler("clicker", open_clicker))
    
    print("✅ Telegram-бот запущен")
    
    # Запускаем бота
    app.run_polling() 