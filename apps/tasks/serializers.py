from rest_framework import serializers
from django.contrib.auth import get_user_model
from .models import MaintenanceSchedule, Task, TaskReport, TaskPhoto

User = get_user_model()


class MaintenanceScheduleSerializer(serializers.ModelSerializer):
    equipment_name = serializers.CharField(source="equipment.name", read_only=True)

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
    assigned_to_name = serializers.CharField(
        source="assigned_to.username", read_only=True
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

    def validate_assigned_to(self, value):
        # Ensure assigned user is an inspector
        if value and getattr(value, "role", None) != "inspector":
            raise serializers.ValidationError("assigned_to must be an inspector")
        return value
