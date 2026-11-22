FROM python:3.12.10-slim

WORKDIR /app

COPY requirements.txt .

RUN apt-get update \
    && apt-get install -y --no-install-recommends procps iproute2 \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --no-cache-dir -r requirements.txt \
    && useradd --create-home appuser

COPY app.py .

USER appuser

EXPOSE 8000

CMD ["python", "app.py"]