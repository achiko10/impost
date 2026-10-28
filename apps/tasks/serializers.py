from rest_framework import serializers
from django.contrib.auth import get_user_model
from .models import MaintenanceSchedule, Task, TaskReport, TaskPhoto

User = get_user_model()


class MaintenanceScheduleSerializer(serializers.ModelSerializer):
    equipment_name = serializers.CharField(source="equipment.name", read_only=True)
    site_id = serializers.IntegerField(source="equipment.site.id", read_only=True)
    site_name = serializers.CharField(source="equipment.site.name", read_only=True)
    company_id = serializers.IntegerField(
        source="equipment.site.company.id", read_only=True
    )
    company_name = serializers.CharField(
        source="equipment.site.company.name", read_only=True
    )
    frequency_display = serializers.CharField(
        source="get_frequency_display", read_only=True
    )

    class Meta:
        model = MaintenanceSchedule
        fields = "__all__"


class TaskPhotoSerializer(serializers.ModelSerializer):
    class Meta:
        model = TaskPhoto
        fields = "__all__"


class TaskReportSerializer(serializers.ModelSerializer):
    photos = TaskPhotoSerializer(many=True, read_only=True)

    class Meta:
        model = TaskReport
        fields = "__all__"


class TaskSerializer(serializers.ModelSerializer):
    schedule_name = serializers.CharField(source="schedule.task_name", read_only=True)
    frequency = serializers.CharField(source="schedule.frequency", read_only=True)
    frequency_display = serializers.CharField(
        source="schedule.get_frequency_display", read_only=True
    )
    equipment_id = serializers.IntegerField(
        source="schedule.equipment.id", read_only=True
    )
    equipment_name = serializers.CharField(
        source="schedule.equipment.name", read_only=True
    )
    site_id = serializers.IntegerField(
        source="schedule.equipment.site.id", read_only=True
    )
    site_name = serializers.CharField(
        source="schedule.equipment.site.name", read_only=True
    )
    company_id = serializers.IntegerField(
        source="schedule.equipment.site.company.id", read_only=True
    )
    company_name = serializers.CharField(
        source="schedule.equipment.site.company.name", read_only=True
    )
    assigned_to_name = serializers.CharField(
        source="assigned_to.username", read_only=True, default=None
    )
    assigned_to_full_name = serializers.SerializerMethodField()
    status_display = serializers.CharField(
        source="get_status_display", read_only=True
    )
    report = TaskReportSerializer(read_only=True)

    assigned_to = serializers.PrimaryKeyRelatedField(
        queryset=User.objects.filter(role="inspector"), required=False, allow_null=True
    )
    scheduled_date = serializers.DateTimeField()
    status = serializers.ChoiceField(choices=Task.STATUS_CHOICES, default="pending")

    class Meta:
        model = Task
        fields = "__all__"

    def get_assigned_to_full_name(self, obj):
        if not obj.assigned_to:
            return None
        full = f"{obj.assigned_to.first_name} {obj.assigned_to.last_name}".strip()
        return full or obj.assigned_to.username

    def validate_assigned_to(self, value):
        if value and getattr(value, "role", None) != "inspector":
            raise serializers.ValidationError("assigned_to must be an inspector")
        return value
