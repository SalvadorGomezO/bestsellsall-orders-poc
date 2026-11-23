# --- ETAPA 1: Builder (Compilacion aislada de dependencias) ---
FROM python:3.11-slim AS builder

WORKDIR /build

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# --- ETAPA 2: Runtime (Imagen minima endurecida) ---
FROM python:3.11-slim AS runtime

WORKDIR /app

# Parcheo de paquetes del SO base (zlib1g) y limpieza de cache APT
RUN apt-get update && \
    apt-get upgrade -y --no-install-recommends && \
    rm -rf /var/lib/apt/lists/*

# Actualizacion de herramientas internas de empaquetado Python (wheel/setuptools)
RUN pip install --no-cache-dir --upgrade --ignore-installed "pip" "setuptools>=78.1.1" "wheel>=0.46.2"

# Creacion de grupo y usuario sin privilegios (Non-Root UID 10001)
RUN groupadd --gid 10001 appgroup && \
    useradd --uid 10001 --gid appgroup --shell /usr/sbin/nologin --create-home appuser

# Copia unicamente las librerias compiladas y el codigo de la aplicacion
COPY --from=builder /install /usr/local
COPY --chown=appuser:appgroup app.py .

# Cambio explicito a usuario no-root (Cumplimiento Pod Security Standards Restricted)
USER appuser

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/health')" || exit 1

CMD ["python", "app.py"]
