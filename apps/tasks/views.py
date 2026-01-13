from rest_framework import viewsets, status
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.response import Response
from .permissions import IsManagerOrAssignedOrReadOnly
from django.shortcuts import get_object_or_404
from rest_framework.permissions import IsAuthenticated
from django.db import transaction
from .models import Task, TaskReport, TaskPhoto
from .serializers import TaskSerializer

# Authentication imports for calendar APIs
from rest_framework.authentication import SessionAuthentication
from rest_framework_simplejwt.authentication import JWTAuthentication
from rest_framework.decorators import authentication_classes


class TaskViewSet(viewsets.ModelViewSet):
    serializer_class = TaskSerializer
    permission_classes = [IsManagerOrAssignedOrReadOnly]

    def get_queryset(self):
        user = self.request.user
        role = getattr(user, "role", None)

        if role == "inspector":
            return Task.objects.filter(assigned_to=user)

        if role == "manager":
            return Task.objects.all()

        return Task.objects.none()

    @action(detail=True, methods=["post"])
    def complete(self, request, pk=None):
        task = self.get_object()

        # Ensure assigned and only assigned user can complete
        if not task.assigned_to or task.assigned_to != request.user:
            return Response(
                {"error": "Not authorized to complete this task"},
                status=status.HTTP_403_FORBIDDEN,
            )

        comment = request.data.get("comment", "")
        photos = request.FILES.getlist("photos", [])
        with transaction.atomic():
            # Create report and link photos atomically
            report = TaskReport.objects.create(task=task, comment=comment)
            # If TaskReport has a created_by (or similar) assign it
            if hasattr(report, "created_by"):
                try:
                    report.created_by = request.user
                    report.save()
                except Exception:
                    # ignore if readonly or unexpected field restrictions
                    pass

            for photo in photos:
                TaskPhoto.objects.create(report=report, image=photo)

            task.status = "completed"
            task.save()

        serializer = self.get_serializer(task)
        return Response(serializer.data)


# ==================== CALENDAR API ====================


@api_view(["GET"])
@authentication_classes([SessionAuthentication, JWTAuthentication])
@permission_classes([IsAuthenticated])
def calendar_events(request):
    """კალენდრის Events – უსაფრთხო წვდომა schedule/equipment-ისთვის."""
    user = request.user
    if getattr(user, "role", None) == "manager":
        tasks = Task.objects.select_related("schedule__equipment", "assigned_to").all()
    elif getattr(user, "role", None) == "inspector":
        tasks = Task.objects.filter(assigned_to=user).select_related(
            "schedule__equipment", "assigned_to"
        )
    else:
        tasks = Task.objects.none()

    events = []
    color_map = {
        "pending": "#6c757d",
        "in_progress": "#ffc107",
        "completed": "#28a745",
        "approved": "#17a2b8",
        "rejected": "#dc3545",
    }

    for task in tasks:
        title_equipment = "Unknown equipment"
        title_schedule = ""
        if getattr(task, "schedule", None):
            schedule = task.schedule
            equip = getattr(schedule, "equipment", None)
            if equip:
                title_equipment = (
                    getattr(equip, "name", title_equipment) or title_equipment
                )
            title_schedule = getattr(schedule, "task_name", "") or ""
        start = None
        if getattr(task, "scheduled_date", None):
            try:
                start = task.scheduled_date.isoformat()
            except Exception:
                start = str(task.scheduled_date)
        events.append(
            {
                "id": task.id,
                "title": f"{title_equipment} - {title_schedule[:30]}",
                "start": start,
                "backgroundColor": color_map.get(task.status, "#6c757d"),
                "borderColor": color_map.get(task.status, "#6c757d"),
                "status": task.status,
                "inspectorId": task.assigned_to.id if task.assigned_to else None,
            }
        )

    return Response(events)


@api_view(["GET"])
@authentication_classes([SessionAuthentication, JWTAuthentication])
@permission_classes([IsAuthenticated])
def task_detail_api(request, task_id):
    """Task დეტალები — კონტროლირებული ხელმისაწვდომობა schedule/equipment–ზე."""
    task = get_object_or_404(Task, id=task_id)
    # Only managers or assigned inspectors can view details
    if request.user.role == "manager":
        pass
    elif request.user.role == "inspector" and task.assigned_to != request.user:
        return Response(
            {"error": "Not authorized to view this task"},
            status=status.HTTP_403_FORBIDDEN,
        )
    else:
        return Response(
            {"error": "Not authorized to view this task"},
            status=status.HTTP_403_FORBIDDEN,
        )

    schedule_name = None
    equipment_name = "Unknown equipment"
    if getattr(task, "schedule", None):
        schedule_name = getattr(task.schedule, "task_name", None)
        equip = getattr(task.schedule, "equipment", None)
        if equip:
            site_name = getattr(getattr(equip, "site", None), "name", "") or ""
            equipment_name = f"{site_name} - {getattr(equip, 'name', '')}".strip(" -")

    scheduled_date = None
    if getattr(task, "scheduled_date", None):
        try:
            scheduled_date = task.scheduled_date.isoformat()
        except Exception:
            scheduled_date = str(task.scheduled_date)

    # Get report and photos
    report_data = None
    if hasattr(task, 'report') and task.report:
        photos = []
        if hasattr(task.report, 'photos'):
            for photo in task.report.photos.all():
                photos.append({
                    'id': photo.id,
                    'image': photo.image.url if photo.image else '',
                    'uploaded_at': photo.uploaded_at.isoformat() if photo.uploaded_at else None
                })
        report_data = {
            'id': task.report.id,
            'comment': task.report.comment,
            'created_at': task.report.created_at.isoformat() if task.report.created_at else None,
            'photos': photos
        }

    return Response(
        {
            "id": task.id,
            "schedule_name": schedule_name,
            "equipment_name": equipment_name,
            "assigned_to_id": (
                task.assigned_to.id if getattr(task, "assigned_to", None) else None
            ),
            "status": task.status,
            "scheduled_date": scheduled_date,
            "report": report_data
        }
    )


@api_view(["POST"])
@authentication_classes([SessionAuthentication, JWTAuthentication])
@permission_classes([IsAuthenticated])
def update_task(request, task_id):
    """Task განახლება — გამოიყენე request.data, დაამატე ვალიდაცია scheduled_date/assigned_to"""
    task = get_object_or_404(Task, id=task_id)

    data = request.data  # safer and supports form/multipart

    # Permission: manager or assigned user can update
    user_role = getattr(request.user, "role", None)
    if not (user_role == "manager" or request.user == task.assigned_to):
        return Response(
            {"error": "Not authorized to update this task"},
            status=status.HTTP_403_FORBIDDEN,
        )

    serializer = TaskSerializer(task, data=data, partial=True)
    if serializer.is_valid():
        serializer.save()
        return Response({"success": True, "task_id": task.id})
    return Response({"error": serializer.errors}, status=status.HTTP_400_BAD_REQUEST)


@api_view(["POST"])
@authentication_classes([SessionAuthentication, JWTAuthentication])
@permission_classes([IsAuthenticated])
def delete_task(request, task_id):
    """Task წაშლა — უსაფრთხო წვდომა."""
    task = get_object_or_404(Task, id=task_id)
    user_role = getattr(request.user, "role", None)
    # Only a manager or the assigned inspector can delete a task
    if not (user_role == "manager" or request.user == task.assigned_to):
        return Response(
            {"error": "Not authorized to delete this task"},
            status=status.HTTP_403_FORBIDDEN,
        )
    task.delete()
    return Response({"success": True}, status=status.HTTP_204_NO_CONTENT)


@api_view(["POST"])
@authentication_classes([SessionAuthentication, JWTAuthentication])
@permission_classes([IsAuthenticated])
def create_task(request):
    """ახალი Task შექმნა — გამოიყენე request.data და დააბრუნე შეცდომები სტატუსით"""
    data = {
        "schedule": request.data.get("schedule") or request.POST.get("schedule"),
        "assigned_to": request.data.get("inspector") or request.POST.get("inspector"),
        "scheduled_date": request.data.get("date") or request.POST.get("date"),
        "status": "pending",
    }

    # Permission: only managers can create tasks on behalf of others.
    if getattr(request.user, "role", None) != "manager":
        return Response(
            {"error": "Not authorized to create tasks"},
            status=status.HTTP_403_FORBIDDEN,
        )

    serializer = TaskSerializer(data=data)
    if serializer.is_valid():
        serializer.save()
        return Response(
            {"success": True, "task_id": serializer.instance.id},
            status=status.HTTP_201_CREATED,
        )
    return Response({"error": serializer.errors}, status=status.HTTP_400_BAD_REQUEST)


@api_view(["POST"])
@authentication_classes([SessionAuthentication, JWTAuthentication])
@permission_classes([IsAuthenticated])
def generate_tasks_api(request):
    """ტასკების გენერაცია გრაფიკებიდან API-ით"""
    from django.utils import timezone
    from dateutil.relativedelta import relativedelta
    from .models import MaintenanceSchedule
    from apps.accounts.models import User
    
    if getattr(request.user, "role", None) != "manager":
        return Response(
            {"error": "Only managers can generate tasks"},
            status=status.HTTP_403_FORBIDDEN,
        )
    
    today = timezone.now()
    inspector = User.objects.filter(role="inspector").first()
    
    if not inspector:
        return Response(
            {"error": "No inspector found to assign tasks"},
            status=status.HTTP_400_BAD_REQUEST,
        )
    
    schedules = MaintenanceSchedule.objects.all()
    created_count = 0
    
    for schedule in schedules:
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
            # წელიწადში ერთხელ
            exists = Task.objects.filter(
                schedule=schedule,
                scheduled_date__year=today.year,
            ).exists()
            
            if not exists:
                Task.objects.create(
                    schedule=schedule,
                    assigned_to=inspector,
                    scheduled_date=today,
                    status="pending",
                )
                created_count += 1
    
    return Response({
        "success": True,
        "message": f"შეიქმნა {created_count} ახალი ტასკი",
        "created_count": created_count,
    })
