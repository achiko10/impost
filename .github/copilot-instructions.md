# Copilot Instructions for Maintenance Management System

## Project Overview
- **Purpose:** Full-featured maintenance and technical service management system built with Django 5.1 and Django REST Framework.
- **Core Apps:**
  - `accounts`: User management, authentication (JWT/SimpleJWT)
  - `companies`: Companies, sites, equipment
  - `tasks`: Task management, schedules, auto-generation
  - `reports`: PDF/email reporting
  - `notifications`: In-app notifications
- **Frontend:** Bootstrap 5, Chart.js, FullCalendar (served via Django templates)
- **Database:** SQLite (dev), PostgreSQL (prod)

## Key Patterns & Conventions
- **App Structure:** All business logic is in `apps/` subfolders. Each app has `models.py`, `serializers.py`, `views.py`, `urls.py`, and `tests.py`.
- **API:** RESTful endpoints under `/api/` (see README for full list). Use JWT for authentication.
- **PDF Generation:** Uses xhtml2pdf and Google Fonts for Georgian-language reports.
- **File Uploads:** Media files (e.g., task photos) are stored in `media/`.
- **Settings:** Centralized in `config/settings.py`.
- **Templates:** HTML in `templates/`, organized by feature (e.g., `dashboard/`, `manager/`).
- **Static Files:** CSS/JS/images in `static/`.

## Developer Workflows
- **Setup:**
  - Create venv: `python -m venv venv && venv\Scripts\activate`
  - Install: `pip install -r requirements.txt`
  - Copy `.env.example` to `.env` and configure
  - Run migrations: `python manage.py migrate`
  - Create superuser: `python manage.py createsuperuser`
  - Start server: `python manage.py runserver`
- **Docker:** Use `docker-compose up --build -d` for containerized dev/prod.
- **Testing:**
  - Run all tests: `pytest` (uses `pytest.ini`)
  - App-specific tests: `pytest apps/<app>/tests.py`
- **Scripts:** Utility scripts in `scripts/` (e.g., `api_test_script.py`, `reset_passwords.py`).

## Integration & Cross-App Patterns
- **User Roles:** Manager, Inspector, Client (see `accounts/models.py`). Role-based permissions enforced in views and serializers.
- **Task Generation:** Tasks can be auto-generated from schedules (`/api/generate-tasks/`).
- **Notifications:** Triggered on task status changes, sent via in-app system.
- **Reports:** PDF and email reports generated per task (`reports/`).

## Examples
- To add a new API endpoint, create a view in the relevant app's `views.py`, add a serializer if needed, and register the route in `urls.py`.
- To add a new user role, update `accounts/models.py` and adjust permissions in views/serializers.

## References
- See `README.md` for full API list, setup, and project structure.
- Key config: `config/settings.py`, `docker-compose.yml`, `requirements.txt`.
- Example test users in README for quick login.

---
For any unclear conventions or missing documentation, consult the README or ask for clarification.
