# 🚀 IMPOSTI - Deployment & Support Guide
## სამშენებლო & მეპ კომპანია - ტექნიკური მომსახურების სისტემა

---

## 📋 სისტემის მოკლე აღწერა

**IMPOSTI Maintenance System** - სრულფასოვანი ვებ-აპლიკაცია აღჭურვილობის ტექნიკური მომსახურების მართვისთვის.

### მომხმარებლის როლები:
| როლი | უფლებები |
|------|----------|
| **Manager** | სრული წვდომა: კომპანიები, ობიექტები, აღჭურვილობა, გრაფიკები, ტასკები |
| **Inspector** | ტასკების შესრულება, ფოტოების ატვირთვა, რეპორტების ნახვა |
| **Client** | მხოლოდ თავისი კომპანიის მონაცემების ნახვა |

### ძირითადი ფუნქციები:
- ✅ კომპანიების და ობიექტების მართვა
- ✅ აღჭურვილობის კატეგორიზაცია და ტრეკინგი
- ✅ გრაფიკების შექმნა (ყოველდღიური/კვირეული/თვიური/წლიური)
- ✅ ტასკების ავტომატური გენერაცია
- ✅ ფოტოებიანი რეპორტები (PDF + Email)
- ✅ In-app ნოტიფიკაციები
- ✅ Dashboard სტატისტიკა (Chart.js)
- ✅ კალენდარი (FullCalendar)

---

## 🔧 ლოკალური ინსტალაცია

### წინაპირობები:
- Python 3.10+
- Git

### ნაბიჯები:

```bash
# 1. Clone repository
git clone https://github.com/achiko10/impost.git
cd impost

# 2. Virtual environment
python -m venv venv
venv\Scripts\activate  # Windows
source venv/bin/activate  # Linux/Mac

# 3. Install dependencies
pip install -r requirements.txt

# 4. Environment setup
copy .env.example .env
# შეცვალე SECRET_KEY და სხვა პარამეტრები

# 5. Database migrations
python manage.py migrate

# 6. Create superuser
python manage.py createsuperuser

# 7. Run server
python manage.py runserver
```

### წვდომა:
- **აპლიკაცია:** http://127.0.0.1:8000/
- **Admin Panel:** http://127.0.0.1:8000/admin/

---

## 🌐 Production Deployment (Railway.app)

### ნაბიჯი 1: Railway-ზე რეგისტრაცია
1. შედი https://railway.app
2. Sign up with GitHub

### ნაბიჯი 2: პროექტის შექმნა
1. "New Project" → "Deploy from GitHub repo"
2. აირჩიე `achiko10/impost`

### ნაბიჯი 3: PostgreSQL დამატება
1. "New" → "Database" → "PostgreSQL"
2. Railway ავტომატურად დააკავშირებს

### ნაბიჯი 4: Environment Variables
Settings → Variables → დაამატე:
```
SECRET_KEY=your-super-secret-key-minimum-50-characters
DEBUG=False
ALLOWED_HOSTS=your-app.railway.app
DATABASE_URL=${{Postgres.DATABASE_URL}}
```

### ნაბიჯი 5: Deploy
Railway ავტომატურად დააბილდებს და გაუშვებს.

---

## 🐳 Docker Deployment

```bash
# Build and run
docker-compose up --build -d

# Migrations
docker-compose exec web python manage.py migrate

# Create superuser
docker-compose exec web python manage.py createsuperuser
```

---

## 👥 ტესტ მომხმარებლები

| Username | Password | როლი |
|----------|----------|------|
| achi | achi123 | Manager |
| manager1 | manager123 | Manager |
| inspector1 | inspector123 | Inspector |
| client1 | client123 | Client |

⚠️ **მნიშვნელოვანი:** Production-ში აუცილებლად შეცვალეთ პაროლები!

---

## 📁 პროექტის სტრუქტურა

```
impost/
├── apps/
│   ├── accounts/     # მომხმარებლები, ავტორიზაცია
│   ├── companies/    # კომპანიები, ობიექტები, აღჭურვილობა
│   ├── tasks/        # ტასკები, გრაფიკები
│   ├── reports/      # PDF, Email
│   └── notifications/# შეტყობინებები
├── config/           # Django settings
├── templates/        # HTML templates
├── static/           # CSS, JS, Images
├── media/            # Uploaded files
├── Dockerfile
├── docker-compose.yml
└── requirements.txt
```

---

## 🔐 უსაფრთხოება

### Production-ისთვის აუცილებელი:
1. **SECRET_KEY** - უნიკალური, მინიმუმ 50 სიმბოლო
2. **DEBUG=False** - აუცილებლად გამორთე
3. **ALLOWED_HOSTS** - მხოლოდ შენი დომენი
4. **HTTPS** - SSL სერტიფიკატი
5. **პაროლების შეცვლა** - ყველა ტესტ მომხმარებლისთვის

### .env ფაილის მაგალითი:
```env
SECRET_KEY=your-very-long-and-random-secret-key-here-50-chars-min
DEBUG=False
ALLOWED_HOSTS=imposti.railway.app,imposti.ge
DATABASE_URL=postgres://user:pass@host:5432/dbname
EMAIL_HOST_USER=your-email@gmail.com
EMAIL_HOST_PASSWORD=your-app-password
```

---

## 🛠 სერვისული ოპერაციები

### Database Backup
```bash
# SQLite
copy db.sqlite3 backup_$(date +%Y%m%d).sqlite3

# PostgreSQL
pg_dump DATABASE_URL > backup.sql
```

### Static Files
```bash
python manage.py collectstatic
```

### ტასკების გენერაცია
```bash
python manage.py generate_tasks
```

---

## 📞 Support & Maintenance

### ხშირი პრობლემები:

**1. ლოგინი არ მუშაობს**
- შეამოწმე username/password
- Admin-დან შეამოწმე მომხმარებლის role

**2. ფოტო არ იტვირთება**
- შეამოწმე MEDIA_ROOT და MEDIA_URL settings
- შეამოწმე folder permissions

**3. Email არ იგზავნება**
- შეამოწმე EMAIL_HOST_USER და EMAIL_HOST_PASSWORD
- Gmail-ისთვის საჭიროა App Password

**4. PDF-ში ქართული არ ჩანს**
- გამოიყენე HTML view: /reports/task/{id}/pdf/
- Browser-ით Print to PDF

### Log Files
```bash
# Django logs
tail -f logs/django.log

# Docker logs
docker-compose logs -f web
```

---

## 📈 მომავალი განახლებები (Roadmap)

შესაძლო დამატებები მომავალში:
- [ ] Mobile Application (React Native)
- [ ] SMS ნოტიფიკაციები
- [ ] Advanced Analytics Dashboard
- [ ] Multi-language support
- [ ] API Documentation (Swagger)
- [ ] Two-Factor Authentication

---

## 📄 ლიცენზია

© 2025 IMPOSTI - Construction & MEP Company
All Rights Reserved

---

## 👨‍💻 დეველოპერი

**Contact for Support:**
- Email: [შეავსეთ]
- Phone: [შეავსეთ]

**GitHub Repository:**
https://github.com/achiko10/impost
