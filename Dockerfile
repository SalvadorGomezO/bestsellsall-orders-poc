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

# 1. Parcheo de paquetes del SO base (zlib1g) y limpieza de cache APT
RUN apt-get update && \
    apt-get upgrade -y --no-install-recommends && \
    rm -rf /var/lib/apt/lists/*

# 2. Creacion de grupo y usuario sin privilegios (Non-Root UID 10001)
RUN groupadd --gid 10001 appgroup && \
    useradd --uid 10001 --gid appgroup --shell /usr/sbin/nologin --create-home appuser

# 3. Copia unicamente las librerias compiladas y el codigo de la aplicacion
COPY --from=builder /install /usr/local
COPY --chown=appuser:appgroup app.py .

# 4. Eliminacion de herramientas de compilacion/empaquetado innecesarias en runtime
# (Mitiga CVEs en setuptools, wheel y jaraco.context y reduce superficie de ataque)
RUN pip uninstall -y setuptools wheel && \
    rm -rf /usr/local/lib/python3.11/site-packages/setuptools* \
           /usr/local/lib/python3.11/site-packages/wheel* \
           /root/.cache

# 5. Cambio explicito a usuario no-root (Cumplimiento Pod Security Standards Restricted)
USER appuser

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/health')" || exit 1

CMD ["python", "app.py"]
