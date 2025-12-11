პროექტის სრული რეფაქტორინგი და დასრულებისთვის საჭირო მოკლე ნაბიჯების გეგმა

მოკლე დანიშნულება:
ამ გეგმის მიზანია პროექტის დაცვა, ვალიდაცია, რეფაქტორინგი და მორჩენილი, პრეზენტაბელური რელიზისთვის მომზადება — უცვლელი კომიტების გარეშე; თითო ნაბიჯი შეიცავს კონკრეტულ ქმედებებს.

გეგმა (დაბალი ხმაზე, მოკლე):

1) Housekeeping
   - .gitignore: დაამატე `db_backup*.sqlite3`, `/venv/`, `.env`, `/staticfiles/`, `media/*.tmp`.
   - შექმენი `.env.example` (DEBUG, SECRET_KEY placeholder, ALLOWED_HOSTS).
   - README.md: მოკლე ინსტრუქცია (how to run, env, tests).

2) Security & settings
   - `config/settings.py`: set `DEBUG=False` default, `ALLOWED_HOSTS` from env, add CSRF/SESSION secure flags, HSTS and SSL redirect flags.
   - `LOGIN_URL = '/login/'` and `LOGIN_REDIRECT_URL = '/dashboard/'`.

3) Root path fix (avoid 404)
   - `config/urls.py`: add root redirect to dashboard via `RedirectView` یا define `index` view.

4) DRF Permissions & Role-based Access
   - New `apps/tasks/permissions.py`: `IsManagerOrAssignedOrReadOnly`.
   - Use this permission in `TaskViewSet` and secure other endpoints.
   - `calendar_events` & `task_detail_api`: require authentication and apply role filtering.

5) Serializer-based Validation
   - `TaskSerializer`:
     - `scheduled_date` as `DateTimeField`
     - `assigned_to` only accepts `inspector` (PrimaryKeyRelatedField queryset)
     - `status` as ChoiceField validation.
   - Use serializer in `create_task` and `update_task`, remove manual parse_date/parse_datetime.

6) Management commands fixes
   - `generate_tasks.py`: use `dateutil.relativedelta` for month/quarter/period increments.
   - Ensure idempotence and logs.

7) Reports and file handling
   - `apps/reports/views.py`: safe `task.report` access and default values, guard `strftime` calls.
   - Confirm `Pillow` installed and `MEDIA_ROOT` exists.
   - Decide about Cloudinary: local vs cloud; if cloud, add `DEFAULT_FILE_STORAGE` and `CLOUDINARY_URL` in env.

8) Tests & CI
   - Add `pytest` tests for core functionality:
     - Tasks endpoints (create/update/complete/delete permissions)
     - `generate_tasks` command
     - `load_real_data` command
     - `reports` excel export
   - Add `pytest` to dev requirements and `.github/workflows/ci.yml` for: install, migrate, tests, lint.

9) Linting & formatting
   - Add `black`, `isort`, `flake8` and `pre-commit` hooks.

10) Cleanup & final QA
   - Remove or ignore unnecessary files (backup dbs, venvs)
   - Run `migrate`, `load_real_data`, `generate_tasks`, `runserver` and smoke test the main endpoints.
   - Ensure `DEBUG=False` for production and `ALLOWED_HOSTS` set.

PRs sequencing (each small and focused):
- PR1: Housekeeping (README, .gitignore, .env.example)
- PR2: Production settings + security flags
- PR3: Add DRF permissions and update `TaskViewSet`
- PR4: Serializer improvements and input validation
- PR5: Secure `calendar_events` & `task_detail_api`
- PR6: Fix `generate_tasks` algorithm
- PR7: Fix `reports` and safer export
- PR8: Add tests
- PR9: Add CI, pre-commit, and linters
- PR10: Optional Cloudinary integration

Minimal acceptance criteria before delivery:
- All tests passing (pytest)
- No debug secrets in repo
- Default route `http://127.0.0.1:8000/` works (redirect to dashboard or public page)
- Role-based permission enforced for sensitive endpoints
- CI configured and passing
- README with setup + run + test instructions

შენიშვნა: ამ გეგმის ყველა პუნქტი შეიძლება განხორციელდეს patch-ებით; თუ გინდათ, მე შემიძლია მომზადებული patch-ები გიგზავნოთ და `apply_patches` სკრიპტი ვუსვამ ინსტრუქციით, ან თავად დაამატოთ ცვლილებები VS Code-ში და მივიღოთ შედეგი.

---

თუ გსურთ, შეჩერდით და ვიწყებ ავტომატურ patch-ების შექმნას (apply) — ან სკრიპტისთვის როცა მზად ხართ.