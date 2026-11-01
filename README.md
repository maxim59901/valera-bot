# Valera Bot

Личный AI-клиент (**Android + Windows**) с Linux-шлюзом к **Ollama**, **SearXNG** (поиск) и **ComfyUI** (генерация картинок). Голос — позже.

## Структура

```
apps/mobile/   Flutter-клиент (Valera Bot)
server/        FastAPI-шлюз
deploy/        docker-compose SearXNG, systemd, nginx example
```

## Быстрый старт — сервер (Linux)

1. Установите [Ollama](https://ollama.com) и скачайте модели:
   ```bash
   ollama pull llama3.1
   ollama pull llava
   ```
2. SearXNG:
   ```bash
   cd deploy
   docker compose up -d
   ```
3. ComfyUI на `:8188` с checkpoint (по умолчанию workflow ждёт `v1-5-pruned-emaonly.safetensors` — поменяйте имя в `server/app/services/comfyui.py` под свой файл).
4. API:
   ```bash
   cd server
   python3 -m venv .venv
   source .venv/bin/activate
   pip install -r requirements.txt
   cp .env.example .env   # задайте APP_TOKEN
   uvicorn app.main:app --host 0.0.0.0 --port 8000
   ```
5. Доступ с телефона/ПК: **Tailscale** или WireGuard (рекомендуется), не открывайте порт в интернет.

Systemd-юнит: [`deploy/valera-bot-api.service`](deploy/valera-bot-api.service).

## Клиент

```bash
cd apps/mobile
flutter pub get
flutter run -d windows
# или
flutter build apk
```

В **Settings** укажите URL шлюза (например `http://100.x.x.x:8000`) и тот же `APP_TOKEN`.

## API

| Метод | Путь | Описание |
|-------|------|----------|
| POST | `/auth/token` | проверка токена |
| GET | `/auth/settings` | дефолты сервера |
| GET/POST | `/chats` | список / новый чат |
| GET | `/chats/{id}/messages` | история |
| POST | `/chats/{id}/messages` | SSE-стрим ответа |
| POST | `/chats/{id}/vision` | картинка + текст → SSE |
| POST | `/images/generate` | ComfyUI txt2img |
| GET | `/models` | модели Ollama |

Заголовок: `Authorization: Bearer <APP_TOKEN>` или `X-API-Token`.

## Возможности v1

- Стриминг чата, история на сервере (общая для Android и Windows)
- Характер **Valera Bot** (system prompt, можно переопределить в Settings)
- Vision через multimodal-модель Ollama
- Веб-поиск через SearXNG + tool-calling
- Генерация изображений через ComfyUI

Голос (STT/TTS) — следующий этап.
