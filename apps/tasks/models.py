from django.db import models
from django.conf import settings
from apps.companies.models import Equipment


class MaintenanceSchedule(models.Model):
    FREQUENCY_CHOICES = [
        ("monthly", "თვეში ერთხელ"),
        ("quarterly", "კვარტალში ერთხელ"),
        ("biannual", "წელიწადში 2-ჯერ"),
        ("annual", "წელიწადში ერთხელ"),
    ]

    equipment = models.ForeignKey(
        Equipment, on_delete=models.CASCADE, related_name="schedules"
    )
    task_name = models.CharField(max_length=300)
    frequency = models.CharField(max_length=20, choices=FREQUENCY_CHOICES)

    def __str__(self):
        return f"{self.equipment.name} - {self.task_name}"


class Task(models.Model):
    STATUS_CHOICES = [
        ("pending", "მოლოდინში"),
        ("in_progress", "მიმდინარე"),
        ("completed", "დასრულებული"),
        ("approved", "დამტკიცებული"),
        ("rejected", "უარყოფილი"),
    ]

    schedule = models.ForeignKey(
        MaintenanceSchedule, on_delete=models.CASCADE, related_name="tasks"
    )
    assigned_to = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        related_name="assigned_tasks",
    )
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default="pending")
    scheduled_date = models.DateTimeField()
    completed_date = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.schedule.task_name} - {self.scheduled_date.date()}"


class TaskReport(models.Model):
    task = models.OneToOneField(Task, on_delete=models.CASCADE, related_name="report")
    comment = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Report for {self.task}"


class TaskPhoto(models.Model):
    report = models.ForeignKey(
        TaskReport, on_delete=models.CASCADE, related_name="photos"
    )
    image = models.ImageField(upload_to="task_photos/")
    uploaded_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Photo for {self.report.task}"
