#!/bin/bash
set -e

echo "=== Bear Blog Docker Entrypoint ==="

# Wait for database to be ready
echo "Waiting for database..."
until python -c "
import os
import psycopg2
from urllib.parse import urlparse
url = urlparse(os.environ.get('DATABASE_URL', ''))
conn = psycopg2.connect(
    host=url.hostname,
    port=url.port or 5432,
    user=url.username,
    password=url.password,
    dbname=url.path[1:]
)
conn.close()
" 2>/dev/null; do
    echo "Database not ready, waiting..."
    sleep 2
done
echo "Database is ready!"

# Run database migrations
echo "Running database migrations..."
python manage.py migrate --noinput

# Create superuser if environment variables are set
if [ -n "$DJANGO_SUPERUSER_EMAIL" ] && [ -n "$DJANGO_SUPERUSER_PASSWORD" ]; then
    echo "Checking for superuser..."
    python manage.py shell << EOF
from django.contrib.auth import get_user_model
from blogs.models import UserSettings
User = get_user_model()

email = '$DJANGO_SUPERUSER_EMAIL'
password = '$DJANGO_SUPERUSER_PASSWORD'

if not User.objects.filter(email=email).exists():
    user = User.objects.create_superuser(
        username=email,
        email=email,
        password=password
    )
    # Ensure UserSettings exists and is upgraded for self-hosted mode
    settings, created = UserSettings.objects.get_or_create(user=user)
    settings.upgraded = True
    settings.save()
    print(f'Superuser {email} created and upgraded')
else:
    print(f'Superuser {email} already exists')
EOF
fi

echo "Starting application..."
exec "$@"
