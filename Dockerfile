# Stage 1: Builder
FROM python:3.11-slim-bookworm AS builder

WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip wheel --no-cache-dir --no-deps --wheel-dir /app/wheels -r requirements.txt

# Stage 2: Production
FROM python:3.11-slim-bookworm AS production

WORKDIR /app

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN groupadd -r bearblog && useradd -r -g bearblog bearblog

# Copy wheels and install
COPY --from=builder /app/wheels /wheels
RUN pip install --no-cache /wheels/* && rm -rf /wheels

# Copy application code
COPY --chown=bearblog:bearblog . .

# Create media directory
RUN mkdir -p /app/media && chown bearblog:bearblog /app/media

# Make entrypoint executable
RUN chmod +x /app/docker-entrypoint.sh

# Collect static files (as root, before switching user)
RUN python manage.py collectstatic --noinput

# Switch to non-root user
USER bearblog

EXPOSE 8000

ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD ["gunicorn", "conf.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "2", "--timeout", "24", "--graceful-timeout", "5", "--max-requests", "10000"]
