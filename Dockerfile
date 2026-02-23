# БЛОК 1: База и подготовка

# Правило 1: Минимальный базовый образ
# python:3.11-slim-bookstorm - ~50 МБ вместо 1 ГБ
# slim - обрезанная версия Debian, только необходимое
FROM python:3.11-slim-bookworm AS builder

# Правило 2: Версия зафиксирована - никакого :latest
# 3.11-slim-bookworm - конкретная версия Python и дистрибутива
# Правило 4: Порядок слоёв - сначала то, что меняется редко

# Устанавливаем рабочий каталог
WORKDIR /app

# Сначала копируем ТОЛЬКО файл с зависимостями
# Это меняется редко -> будет кэшироваться
COPY requirements.txt .

# ПОТОМ устанавливаем зависимости
# Этот слой пересоберется, только если изменился requirements.txt
# Правило 5: Объединяем RUN и чистим кэш в том же слое

# Устанавливаем зависимости и сразу чистим кэш pip
# --no-cache-dir не оставляет мусора
RUN pip install --no-cache-dir -r requirements.txt && \
    # Проверяем, что всё установилось
    pip list && \
    # Удаляем временные файлы если есть
    find /usr/local/lib/python3.11/site-packages -name "*.pyc" -delete
# Правило 7: Multi-stage build - разделяем сборку и запуск

# Первый этап (builder) закончился
# Теперь начинается финальный образ

FROM python:3.11-slim-bookworm

# Добавляем tini для корректной обработки сигналов (будет позже)
# Но установим сразу
RUN apt-get update && \
    apt-get install -y --no-install-recommends tini=0.19.0-1+b3 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Копируем установленные пакеты из builder
# --from=builder берёт файлы из первого этапа
COPY --from=builder /usr/local/lib/python3.11/site-packages/ /usr/local/lib/python3.11/site-packages/
COPY --from=builder /usr/local/bin/ /usr/local/bin/
# Добавим после установки зависимостей (в этапе builder)
RUN --mount=type=secret,id=app_secret \
    # Проверяем, что секрет доступен
    if [ -f /run/secrets/app_secret ]; then \
        echo "Secret is available" && \
        SECRET=$(cat /run/secrets/app_secret) && \
        # Здесь можно было бы использовать секрет
        echo "Secret length: ${#SECRET}"; \
    fi

# Правило 9: Не работаем под root

# Создаём группу и пользователя для приложения
# --system - системный пользователь (без пароля, не для входа)
# --group - создаём группу с тем же именем
RUN addgroup --system --gid 1001 app && \
    adduser --system --uid 1001 --gid 1001 --no-create-home app

# Создаём рабочую директорию и сразу выставляем владельца
WORKDIR /app
# Копируем код (меняется часто - поэтому в самом конце)
# --chown сразу выставляет правильного владельца
COPY --chown=app:app app.py .

# Проверяем, что файлы принадлежат пользователю app
RUN ls -la /app
# Правило 11: PID 1 и graceful shutdown
# tini будет принимать сигналы и передавать их приложению
ENTRYPOINT ["/usr/bin/tini", "--"]

# Правило 12: HEALTHCHECK
# Docker будет регулярно проверять, живо ли приложение
# --interval: как часто проверять
# --timeout: таймаут на проверку
# --start-period: сколько ждать перед первой проверкой
# --retries: сколько попыток до объявления unhealthy
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')" || exit 1

# Правило 9 (продолжение): переключаемся на непривилегированного пользователя
USER app

# Объявляем порт (информационно)
EXPOSE 5000

# Команда по умолчанию
# Будет выполнена после ENTRYPOINT
CMD ["python", "app.py"]
