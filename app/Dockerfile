FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN apt-get update \
    && apt-get upgrade -y --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# La app no instala paquetes: se eliminan las herramientas de instalación
# y las librerías vulnerables que traen incluidas
RUN python -m pip uninstall -y pip setuptools wheel

RUN useradd --create-home --uid 10001 appuser
WORKDIR /home/appuser
COPY app.py .

USER appuser
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:8080/health')"]

CMD ["python", "app.py"]