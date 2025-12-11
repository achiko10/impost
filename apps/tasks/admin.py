from django.contrib import admin
from .models import MaintenanceSchedule, Task, TaskReport, TaskPhoto


@admin.register(MaintenanceSchedule)
class MaintenanceScheduleAdmin(admin.ModelAdmin):
    list_display = ["task_name", "equipment", "frequency"]
    list_filter = ["frequency", "equipment__site__company"]
    search_fields = ["task_name", "equipment__name"]


@admin.register(Task)
class TaskAdmin(admin.ModelAdmin):
    list_display = [
        "schedule",
        "assigned_to",
        "status",
        "scheduled_date",
        "completed_date",
    ]
    list_filter = ["status", "scheduled_date"]
    search_fields = ["schedule__task_name"]


@admin.register(TaskReport)
class TaskReportAdmin(admin.ModelAdmin):
    list_display = ["task", "created_at"]
    search_fields = ["task__schedule__task_name", "comment"]


@admin.register(TaskPhoto)
class TaskPhotoAdmin(admin.ModelAdmin):
    list_display = ["report", "uploaded_at"]
    list_filter = ["uploaded_at"]
