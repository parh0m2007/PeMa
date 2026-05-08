#!/bin/bash
# PeMa launcher — сборка + бэкенд + приложение одной кнопкой

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
API_DIR="$APP_DIR/api"
BUILD_DIR="$APP_DIR/build-local"
QT_APP="$BUILD_DIR/PeMa.app"
CMAKE="$HOME/Qt/Tools/CMake/CMake.app/Contents/bin/cmake"
QT_DIR="$HOME/Qt/6.11.0/macos"

# ── 1. Собрать Qt-приложение если нужно ──────────────────────────────────────
echo "🔨 Проверяю сборку..."

# Первый раз — сконфигурировать
if [ ! -f "$BUILD_DIR/Makefile" ] && [ ! -f "$BUILD_DIR/build.ninja" ]; then
    echo "   Первая сборка, конфигурирую..."
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"
    "$CMAKE" -DCMAKE_PREFIX_PATH="$QT_DIR" -G "Unix Makefiles" "$APP_DIR" || {
        echo "❌ Ошибка конфигурации CMake"; read -p "Нажмите Enter..."; exit 1
    }
fi

cd "$BUILD_DIR"
"$CMAKE" --build . --parallel $(sysctl -n hw.logicalcpu) 2>&1 | tail -5
if [ $? -ne 0 ]; then
    echo "❌ Ошибка сборки. Запустите PeMa.command из Терминала чтобы увидеть детали."
    read -p "Нажмите Enter для выхода..."
    exit 1
fi
echo "✅ Сборка готова"

# ── 2. Убить старый uvicorn если висит ───────────────────────────────────────
lsof -ti :8000 | xargs kill -9 2>/dev/null
sleep 0.3

# ── 3. Запустить FastAPI бэкенд в фоне ───────────────────────────────────────
echo "🚀 Запускаю бэкенд..."
cd "$API_DIR"

# Создать venv если нет
if [ ! -d "venv" ]; then
    echo "   Создаю виртуальное окружение..."
    python3 -m venv venv
fi

source venv/bin/activate

# Установить зависимости если нужно
pip install -q -r requirements.txt

uvicorn main:app --port 8000 &
UVICORN_PID=$!

# ── 4. Подождать пока сервер поднимется ──────────────────────────────────────
for i in $(seq 1 30); do
    curl -s http://localhost:8000/docs > /dev/null 2>&1 && break
    sleep 0.3
done
echo "✅ Бэкенд запущен (PID $UVICORN_PID)"

# ── 5. Запустить Qt-приложение ────────────────────────────────────────────────
echo "🖥  Открываю приложение..."
open -W "$QT_APP"   # -W: ждёт пока приложение закроется

# ── 6. Когда приложение закроется — убить бэкенд ─────────────────────────────
kill $UVICORN_PID 2>/dev/null
echo "👋 Бэкенд остановлен."
