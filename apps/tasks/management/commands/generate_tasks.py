from django.core.management.base import BaseCommand
from django.utils import timezone
from dateutil.relativedelta import relativedelta
from apps.tasks.models import MaintenanceSchedule, Task
from apps.accounts.models import User


class Command(BaseCommand):
    help = "Generate tasks from maintenance schedules"

    def handle(self, *args, **kwargs):
        today = timezone.now()
        inspector = User.objects.filter(role="inspector").first()

        if not inspector:
            self.stdout.write(self.style.WARNING("No inspector found!"))
            return

        schedules = MaintenanceSchedule.objects.all()
        created_count = 0

        for schedule in schedules:
            # განსაზღვრე თარიღები სიხშირის მიხედვით
            if schedule.frequency == "monthly":
                # შემდეგი 12 თვის tasks
                for month in range(12):
                    scheduled_date = today + relativedelta(months=+month)

                    exists = Task.objects.filter(
                        schedule=schedule,
                        scheduled_date__year=scheduled_date.year,
                        scheduled_date__month=scheduled_date.month,
                    ).exists()

                    if not exists:
                        Task.objects.create(
                            schedule=schedule,
                            assigned_to=inspector,
                            scheduled_date=scheduled_date,
                            status="pending",
                        )
                        created_count += 1

            elif schedule.frequency == "quarterly":
                # შემდეგი 4 კვარტალის tasks
                for quarter in range(4):
                    scheduled_date = today + relativedelta(months=+(3 * quarter))

                    exists = Task.objects.filter(
                        schedule=schedule,
                        scheduled_date__gte=scheduled_date,
                        scheduled_date__lt=scheduled_date + relativedelta(months=+3),
                    ).exists()

                    if not exists:
                        Task.objects.create(
                            schedule=schedule,
                            assigned_to=inspector,
                            scheduled_date=scheduled_date,
                            status="pending",
                        )
                        created_count += 1

            elif schedule.frequency == "biannual":
                # შემდეგი 2 პერიოდი (6-6 თვე)
                for period in range(2):
                    scheduled_date = today + relativedelta(months=+(6 * period))

                    exists = Task.objects.filter(
                        schedule=schedule,
                        scheduled_date__year=scheduled_date.year,
                        scheduled_date__month__gte=scheduled_date.month,
                        scheduled_date__month__lt=scheduled_date.month + 6,
                    ).exists()

                    if not exists:
                        Task.objects.create(
                            schedule=schedule,
                            assigned_to=inspector,
                            scheduled_date=scheduled_date,
                            status="pending",
                        )
                        created_count += 1

        self.stdout.write(self.style.SUCCESS(f"✅ Created {created_count} tasks"))
