#!/usr/bin/env bash
# Build script for Render

set -o errexit

pip install -r requirements.txt

python manage.py collectstatic --no-input
python manage.py migrate
python manage.py create_initial_users
python manage.py load_mcdonalds_data
