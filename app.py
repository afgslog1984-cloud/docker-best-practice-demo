#!/usr/bin/env python3
"""
Простое веб-приложение на Flask для демонстрации Docker best practices
"""

from flask import Flask
import os
import socket
import time

app = Flask(__name__)

# При запуске сохраняем время старта
start_time = time.time()

@app.route('/')
def hello():
    """Главная страница - показывает информацию о контейнере"""
    hostname = socket.gethostname()
    uptime = int(time.time() - start_time)
    return f"""
    <html>
        <head><title>Docker Best Practices Demo</title></head>
        <body style="font-family: sans-serif; margin: 40px;">
            <h1>✅ Docker работает!</h1>
            <p>Контейнер: <strong>{hostname}</strong></p>
            <p>Работает: <strong>{uptime} секунд</strong></p>
            <p>Этот образ собран по всем правилам DevOps</p>
        </body>
    </html>
    """

@app.route('/health')
def health():
    """Endpoint для проверки здоровья"""
    return "OK", 200

@app.route('/ready')
def ready():
    """Endpoint для проверки готовности"""
    return "READY", 200

if __name__ == '__main__':
    # Запускаем на всех интерфейсах, порт 5000
    app.run(host='0.0.0.0', port=5000, debug=False)
