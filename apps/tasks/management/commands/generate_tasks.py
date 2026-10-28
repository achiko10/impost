from django.core.management.base import BaseCommand
from django.utils import timezone
from dateutil.relativedelta import relativedelta
from apps.tasks.models import MaintenanceSchedule, Task
from apps.accounts.models import Tenant, User


class Command(BaseCommand):
    help = "Generate tasks from maintenance schedules (scoped per tenant)"

    def handle(self, *args, **kwargs):
        today = timezone.now()
        default_tenant, _ = Tenant.objects.get_or_create(name="IMPOSTI")
        User.objects.filter(tenant__isnull=True).update(tenant=default_tenant)

        schedules = MaintenanceSchedule.objects.select_related(
            "equipment__site__company__tenant"
        ).all()
        created_count = 0

        for schedule in schedules:
            tenant = schedule.equipment.site.company.tenant or default_tenant
            inspector = User.objects.filter(role="inspector", tenant=tenant).first()
            if not inspector:
                continue

            if schedule.frequency == "monthly":
                for month in range(12):
                    scheduled_date = (today + relativedelta(months=+month)).replace(
                        hour=9, minute=0, second=0, microsecond=0
                    )
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
                for quarter in range(4):
                    scheduled_date = (
                        today + relativedelta(months=+(3 * quarter))
                    ).replace(hour=9, minute=0, second=0, microsecond=0)
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
                for period in range(2):
                    scheduled_date = (
                        today + relativedelta(months=+(6 * period))
                    ).replace(hour=9, minute=0, second=0, microsecond=0)
                    if scheduled_date.month <= 6:
                        start_month, end_month = 1, 6
                    else:
                        start_month, end_month = 7, 12
                    exists = Task.objects.filter(
                        schedule=schedule,
                        scheduled_date__year=scheduled_date.year,
                        scheduled_date__month__gte=start_month,
                        scheduled_date__month__lte=end_month,
                    ).exists()
                    if not exists:
                        Task.objects.create(
                            schedule=schedule,
                            assigned_to=inspector,
                            scheduled_date=scheduled_date,
                            status="pending",
                        )
                        created_count += 1

            elif schedule.frequency == "annual":
                scheduled_date = today.replace(hour=9, minute=0, second=0, microsecond=0)
                exists = Task.objects.filter(
                    schedule=schedule,
                    scheduled_date__year=scheduled_date.year,
                ).exists()
                if not exists:
                    Task.objects.create(
                        schedule=schedule,
                        assigned_to=inspector,
                        scheduled_date=scheduled_date,
                        status="pending",
                    )
                    created_count += 1

        self.stdout.write(self.style.SUCCESS(f"[OK] Created {created_count} tasks"))
