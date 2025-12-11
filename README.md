# Maintenance Management System

სრულფასოვანი სარემონტო და ტექნიკური მომსახურების მართვის სისტემა Django-ზე.

## 🚀 ფუნქციონალი

### მომხმარებლები და როლები
- **Manager** - სრული წვდომა: კომპანიები, აღჭურვილობა, გრაფიკები, ტასკები
- **Inspector** - ტასკების შესრულება, ფოტოების ატვირთვა, რეპორტები
- **Client** - თავისი კომპანიის მონაცემების ნახვა

### ძირითადი მოდულები
- 🏢 **კომპანიების მართვა** - CRUD + სტატისტიკა
- 🔧 **აღჭურვილობა** - კატეგორიები, ფილტრები, სტატუსები
- 📍 **ობიექტები** - Sites მართვა
- 📅 **გრაფიკები** - განმეორებადი დავალებები (daily/weekly/monthly/yearly)
- ✅ **ტასკები** - ავტო-გენერაცია, bulk actions, სტატუსები
- 📊 **Dashboard** - Chart.js დიაგრამები, სტატისტიკა
- 🔔 **ნოტიფიკაციები** - In-app შეტყობინებები
- 📄 **PDF რეპორტები** - ქართული ფონტით
- 📧 **Email** - ტასკის PDF-ის გაგზავნა
- 📸 **ფოტოები** - Drag & Drop ატვირთვა

## 🛠 ტექნოლოგიები

- **Backend**: Django 5.1, Django REST Framework
- **Authentication**: JWT (SimpleJWT)
- **Frontend**: Bootstrap 5, Chart.js, FullCalendar
- **Database**: SQLite (dev), PostgreSQL (production)
- **File Storage**: Local / Cloudinary
- **PDF**: xhtml2pdf + Google Fonts

## ⚙️ ინსტალაცია (Development)

```bash
# 1. Clone repository
git clone <repo-url>
cd maintenance_system

# 2. Create virtual environment
python -m venv venv
venv\Scripts\activate  # Windows
source venv/bin/activate  # Linux/Mac

# 3. Install dependencies
pip install -r requirements.txt

# 4. Setup environment
copy .env.example .env
# Edit .env with your settings

# 5. Run migrations
python manage.py migrate

# 6. Create superuser
python manage.py createsuperuser

# 7. Run server
python manage.py runserver
```

## 🐳 Docker Deployment

```bash
# Build and run
docker-compose up --build -d

# Run migrations
docker-compose exec web python manage.py migrate

# Create superuser
docker-compose exec web python manage.py createsuperuser
```

## 📁 პროექტის სტრუქტურა

```
maintenance_system/
├── apps/
│   ├── accounts/     # მომხმარებლები, ავტორიზაცია
│   ├── companies/    # კომპანიები, ობიექტები, აღჭურვილობა
│   ├── tasks/        # ტასკები, გრაფიკები
│   ├── reports/      # PDF რეპორტები, Email
│   └── notifications/# შეტყობინებები
├── config/           # Django settings
├── templates/        # HTML templates
├── static/           # CSS, JS, Images
└── media/            # Uploaded files
```

## 🔐 API Endpoints

### Authentication
- `POST /api/login/` - Login (returns JWT tokens)
- `POST /api/token/refresh/` - Refresh token
- `POST /api/logout/` - Logout

### Companies
- `GET/POST /api/companies/` - List/Create companies
- `GET/PUT/DELETE /api/companies/{id}/` - Company detail
- `GET /api/companies/{id}/equipment/` - Company equipment
- `GET /api/companies/{id}/sites/` - Company sites

### Tasks
- `GET/POST /api/tasks/` - List/Create tasks
- `GET/PUT/DELETE /api/tasks/{id}/` - Task detail
- `POST /api/tasks/{id}/complete/` - Complete task
- `POST /api/generate-tasks/` - Generate tasks from schedules

### Reports
- `GET /reports/task/{id}/pdf/` - Task PDF (Georgian)
- `POST /reports/task/{id}/email/` - Send task via email

### Notifications
- `GET /api/notifications/` - List notifications
- `POST /api/notifications/{id}/mark-read/` - Mark as read

## 👥 ტესტ მომხმარებლები

| Username | Password | Role |
|----------|----------|------|
| achi | achi123 | Manager |
| manager1 | manager123 | Manager |
| inspector1 | inspector123 | Inspector |
| client1 | client123 | Client |

## 📝 License

MIT License

## 👨‍💻 Author

Maintenance System Team
