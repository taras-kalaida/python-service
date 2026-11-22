
# Python Service - CI/CD with Docker and GitHub Actions

## Опис проєкту

Практична робота №6. Автоматизоване тестування та розгортання Python-сервісу.

Проєкт демонструє автоматизований процес CI/CD: тестування Python-застосунку, створення Docker-образу, розгортання на Ubuntu Server, перевірку працездатності та автоматичне повернення попередньої версії у випадку помилки.

## Використані технології

- Python 3.12
- Flask
- pytest
- Testinfra
- Docker та Docker Compose
- Git і GitHub
- GitHub Actions
- Ubuntu Server 24.04
- Self-hosted GitHub Actions Runner

## API

Застосунок має два маршрути:

- `GET /health` - перевірка працездатності сервісу.
- `GET /version` - отримання поточної версії застосунку.

Успішна відповідь `/health`:

```json
{
  "status": "ok"
}
```

При `HEALTH_FAILURE=true` маршрут повертає HTTP 503.

## Локальний запуск

Створити файл налаштувань:

```bash
cp .env.example .env
```

Зібрати та запустити контейнер:

```bash
docker compose up -d --build
```

Перевірити роботу:

```bash
curl --max-time 5 http://localhost:8000/health
curl --max-time 5 http://localhost:8000/version
```

Зупинити контейнер:

```bash
docker compose down
```

## Автоматизоване тестування

Встановити залежності:

```bash
python -m pip install -r requirements.txt
```

Запустити тести API:

```bash
python -m pytest tests/test_app.py -v
```

Запустити інфраструктурні тести на Linux після запуску контейнера:

```bash
python -m pytest tests/test_infrastructure_linux.py -v
```

Тести перевіряють:

- Відповіді API.
- Поведінку при неправильних налаштуваннях.
- Наявність файлів у контейнері.
- Роботу процесу Python.
- Доступність порту 8000.
- Запуск застосунку без прав root.

## CI/CD Pipeline

GitHub Actions автоматично виконує три етапи:

### 1. Test

Запуск pytest при push та Pull Request.

Якщо тести завершуються помилкою, наступні етапи блокуються.

### 2. Build

Збірка Docker-образу з тегом, який відповідає SHA коміту.

Підготовлений образ передається на наступний етап через GitHub Actions Artifacts.

### 3. Deploy

Розгортання образу на Ubuntu Server за допомогою self-hosted runner.

Після запуску виконуються:

- HTTP-перевірка `/health` із тайм-аутом.
- Інфраструктурні перевірки Testinfra.
- Збереження звітів і логів контейнера.

У разі помилки запускається автоматичний відкат.

## Автоматичний відкат

Скрипт `scripts/deploy.sh` перед розгортанням визначає поточний Docker-образ.

Якщо нова версія не проходить перевірку, скрипт відновлює попередній образ та повторно перевіряє `/health`.

Навіть після успішного відкату невдале розгортання зберігає статус Failed.

Для ручного відновлення раніше збереженого образу на Ubuntu:

```bash
export IMAGE_TAG="<previous-commit-sha>"
export HEALTH_FAILURE=false
docker compose -f compose.deploy.yaml up -d --force-recreate --no-build
curl --fail --max-time 5 http://localhost:8000/health
```

Команду необхідно виконувати з каталогу, де розташований `compose.deploy.yaml`. Попередній образ має залишатися доступним у Docker.

## Експеримент №1 - помилка pytest

До тестів навмисно додано неправильне твердження:

```python
def test_intentional_failure():
    assert 1 == 2
```

Результат:

- Test - Failed.
- Build - Skipped.
- Deploy - Skipped.

Експеримент підтвердив, що помилка тестування блокує розгортання.

## Експеримент №2 - несправний /health

Створено спеціальний коміт:

```bash
git commit --allow-empty -m "Experiment: [fail-health] test automatic rollback"
git push origin main
```

Позначка `[fail-health]` активує симуляцію несправності під час розгортання.

Результат:

- Test - Success.
- Build - Success.
- Deploy - Failed.
- HTTP-перевірка повернула 503.
- Автоматично відновлено попередній Docker-образ.
- Повторна перевірка `/health` повернула HTTP 200.

Результат невдалого розгортання залишився позначеним як Failed.

## Діагностика

GitHub Actions зберігає:

- `api-test-results`
- `docker-build-logs`
- `deployment-results`
- `python-service-image`

HTTP-запити мають тайм-аути, а перевірка готовності сервісу виконується з обмеженою кількістю повторних спроб.

## Розміщення на IaaS та PaaS

Для перенесення на IaaS можна створити хмарну віртуальну машину з Linux, встановити Docker і налаштувати GitHub Actions Runner. У цьому випадку користувач відповідає за оновлення операційної системи, Docker, мережеві правила та безпеку сервера. Для PaaS можна використовувати платформу, яка підтримує розгортання контейнерів, а керування базовою інфраструктурою та її оновленнями бере на себе провайдер. Основні витрати виникатимуть через використання обчислювальних ресурсів, дискового простору, мережевого трафіку та зберігання Docker-образів і логів.

## Репозиторій

https://github.com/taras-kalaida/python-service
