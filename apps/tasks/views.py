from rest_framework import viewsets, status
from rest_framework.decorators import (
    action,
    api_view,
    permission_classes,
    authentication_classes,
)
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework.authentication import SessionAuthentication
from rest_framework_simplejwt.authentication import JWTAuthentication
from django.shortcuts import get_object_or_404
from django.db import transaction
from django.db.models import Q
from django.utils import timezone
from .permissions import IsManagerOrAssignedOrReadOnly
from .models import Task, TaskReport, TaskPhoto, MaintenanceSchedule
from .serializers import TaskSerializer
from apps.accounts.models import User, get_user_tenant
from apps.notifications.models import Notification


def notify_task_completed(task):
    """შეტყობინების გაგზავნა მენეჯერებისა და კლიენტისთვის დავალების შესრულებისას"""
    try:
        equipment = task.schedule.equipment
        site = equipment.site
        company = site.company
        tenant = company.tenant

        managers = User.objects.filter(role="manager", tenant=tenant)
        for manager in managers:
            Notification.create_notification(
                user=manager,
                notification_type="task_completed",
                title="დავალება შესრულდა",
                message=f"{equipment.name} ({site.name}) - '{task.schedule.task_name}' შესრულდა ინსპექტორის მიერ.",
                link="/manager/tasks/",
            )

        clients = User.objects.filter(role="client", company=company)
        for client in clients:
            Notification.create_notification(
                user=client,
                notification_type="task_completed",
                title="სერვისი დასრულდა — საჭიროებს დადასტურებას",
                message=f"{equipment.name} ({site.name}) - '{task.schedule.task_name}' შესრულებულია და ელოდება თქვენს დადასტურებას.",
                link="/client/",
            )
    except Exception:
        pass


class TaskViewSet(viewsets.ModelViewSet):
    serializer_class = TaskSerializer
    authentication_classes = [JWTAuthentication, SessionAuthentication]
    permission_classes = [IsManagerOrAssignedOrReadOnly]

    def get_queryset(self):
        user = self.request.user
        role = getattr(user, "role", None)

        if role == "inspector":
            qs = Task.objects.filter(assigned_to=user)
        elif role == "manager":
            user_tenant = get_user_tenant(user)
            qs = Task.objects.filter(
                schedule__equipment__site__company__tenant=user_tenant
            )
        elif role == "client" and getattr(user, "company_id", None):
            qs = Task.objects.filter(
                schedule__equipment__site__company=user.company
            )
        else:
            return Task.objects.none()

        qs = qs.select_related(
            "schedule__equipment__site__company", "assigned_to", "report"
        ).prefetch_related("report__photos")

        # Optional query filters for Flutter & Web
        params = self.request.query_params
        status_filter = params.get("status")
        inspector_filter = params.get("inspector")
        company_filter = params.get("company")
        site_filter = params.get("site")
        equipment_filter = params.get("equipment")
        search = params.get("search")
        date_from = params.get("date_from")
        date_to = params.get("date_to")

        if status_filter:
            qs = qs.filter(status=status_filter)
        if inspector_filter:
            qs = qs.filter(assigned_to_id=inspector_filter)
        if company_filter:
            qs = qs.filter(schedule__equipment__site__company_id=company_filter)
        if site_filter:
            qs = qs.filter(schedule__equipment__site_id=site_filter)
        if equipment_filter:
            qs = qs.filter(schedule__equipment_id=equipment_filter)
        if search:
            qs = qs.filter(
                Q(schedule__equipment__name__icontains=search)
                | Q(schedule__task_name__icontains=search)
                | Q(schedule__equipment__site__name__icontains=search)
            )
        if date_from:
            qs = qs.filter(scheduled_date__gte=date_from)
        if date_to:
            qs = qs.filter(scheduled_date__lte=date_to)

        return qs.order_by("-scheduled_date")

    def perform_update(self, serializer):
        user = self.request.user
        instance = self.get_object()
        if getattr(user, "role", None) == "inspector":
            new_status = serializer.validated_data.get("status", instance.status)
            if new_status in ("approved", "rejected"):
                from rest_framework.exceptions import PermissionDenied

                raise PermissionDenied("ინსპექტორს არ შეუძლია დავალების დამტკიცება ან უარყოფა.")
            serializer.validated_data.pop("assigned_to", None)
            serializer.validated_data.pop("schedule", None)

        updated_task = serializer.save()
        if (
            updated_task.status in ("completed", "approved")
            and not updated_task.completed_date
        ):
            updated_task.completed_date = timezone.now()
            updated_task.save(update_fields=["completed_date"])

    @action(
        detail=True,
        methods=["delete", "post"],
        url_path=r"photos/(?P<photo_id>\d+)",
    )
    def delete_photo(self, request, pk=None, photo_id=None):
        """რეპორტში ატვირთული ფოტოს წაშლა (სანამ დავალება დამტკიცებული არ არის)"""
        task = self.get_object()
        if task.status == "approved" and getattr(request.user, "role", None) != "manager":
            return Response(
                {"error": "დამტკიცებული დავალების ფოტოს წაშლა დაუშვებელია"},
                status=status.HTTP_400_BAD_REQUEST,
            )
        photo = get_object_or_404(TaskPhoto, id=photo_id, report__task=task)
        photo.delete()
        return Response({"success": True})

    @action(detail=True, methods=["post"])
    def start(self, request, pk=None):
        """ინსპექტორი იწყებს დავალების შესრულებას (status -> in_progress)"""
        task = self.get_object()
        if not task.assigned_to or task.assigned_to != request.user:
            return Response(
                {"error": "Not authorized to start this task"},
                status=status.HTTP_403_FORBIDDEN,
            )
        task.status = "in_progress"
        task.save(update_fields=["status"])
        return Response(self.get_serializer(task).data)

    @action(detail=True, methods=["post"])
    def complete(self, request, pk=None):
        """ინსპექტორი ასრულებს ან ინახავს დავალების პროგრესს (კომენტარი + ფოტოები)"""
        task = self.get_object()

        if not task.assigned_to or task.assigned_to != request.user:
            return Response(
                {"error": "Not authorized to complete this task"},
                status=status.HTTP_403_FORBIDDEN,
            )

        action_type = request.data.get("action", "complete")
        comment = request.data.get("comment", "")
        photos = request.FILES.getlist("photos", [])
        with transaction.atomic():
            report, _ = TaskReport.objects.update_or_create(
                task=task, defaults={"comment": comment}
            )

            for photo in photos:
                TaskPhoto.objects.create(report=report, image=photo)

            if action_type == "save":
                task.status = "in_progress"
                task.save(update_fields=["status"])
            else:
                task.status = "completed"
                task.completed_date = timezone.now()
                task.save()

        if action_type != "save":
            notify_task_completed(task)
        serializer = self.get_serializer(task)
        return Response(serializer.data)

    @action(
        detail=True,
        methods=["post"],
        permission_classes=[IsAuthenticated],
    )
    def approve(self, request, pk=None):
        """კლიენტი (ან მენეჯერი) ადასტურებს შესრულებულ დავალებას API-ით"""
        task = get_object_or_404(Task, pk=pk)
        task_company = task.schedule.equipment.site.company

        if request.user.role == "client":
            if request.user.company != task_company:
                return Response(
                    {"error": "არ გაქვთ წვდომა ამ დავალებაზე"},
                    status=status.HTTP_403_FORBIDDEN,
                )
        elif request.user.role == "manager":
            if task_company.tenant != get_user_tenant(request.user):
                return Response(
                    {"error": "არ გაქვთ წვდომა ამ დავალებაზე"},
                    status=status.HTTP_403_FORBIDDEN,
                )
        else:
            return Response(
                {"error": "მხოლოდ კლიენტს ან მენეჯერს შეუძლია დადასტურება"},
                status=status.HTTP_403_FORBIDDEN,
            )

        if task.status != "completed":
            return Response(
                {"error": "მხოლოდ დასრულებული დავალების დადასტურება შეიძლება"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        task.status = "approved"
        if not task.completed_date:
            task.completed_date = timezone.now()
        task.save()

        equipment_name = task.schedule.equipment.name
        task_name = task.schedule.task_name

        if task.assigned_to:
            Notification.create_notification(
                user=task.assigned_to,
                notification_type="task_approved",
                title="დავალება დადასტურდა",
                message=f"{task_company.name}: {equipment_name} - '{task_name}' დადასტურებულია.",
                link=f"/tasks/{task.id}/",
            )
        for manager in User.objects.filter(role="manager", tenant=task_company.tenant):
            Notification.create_notification(
                user=manager,
                notification_type="task_approved",
                title="კლიენტმა დაადასტურა სერვისი",
                message=f"{task_company.name}: {equipment_name} - '{task_name}' დადასტურდა.",
                link="/manager/tasks/",
            )

        return Response(self.get_serializer(task).data)

    @action(
        detail=True,
        methods=["post"],
        permission_classes=[IsAuthenticated],
    )
    def reject(self, request, pk=None):
        """კლიენტი (ან მენეჯერი) უარყოფს შესრულებულ დავალებას API-ით"""
        task = get_object_or_404(Task, pk=pk)
        task_company = task.schedule.equipment.site.company

        if request.user.role == "client":
            if request.user.company != task_company:
                return Response(
                    {"error": "არ გაქვთ წვდომა ამ დავალებაზე"},
                    status=status.HTTP_403_FORBIDDEN,
                )
        elif request.user.role == "manager":
            if task_company.tenant != get_user_tenant(request.user):
                return Response(
                    {"error": "არ გაქვთ წვდომა ამ დავალებაზე"},
                    status=status.HTTP_403_FORBIDDEN,
                )
        else:
            return Response(
                {"error": "მხოლოდ კლიენტს ან მენეჯერს შეუძლია უარყოფა"},
                status=status.HTTP_403_FORBIDDEN,
            )

        if task.status != "completed":
            return Response(
                {"error": "მხოლოდ დასრულებული დავალების უარყოფა შეიძლება"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        reason = (request.data.get("reason") or "").strip()
        task.status = "rejected"
        task.save()

        if reason and hasattr(task, "report") and task.report:
            task.report.comment = (
                f"{task.report.comment}\n\n[კლიენტის შენიშვნა: {reason}]".strip()
            )
            task.report.save(update_fields=["comment"])

        reason_suffix = f" მიზეზი: {reason}" if reason else ""
        equipment_name = task.schedule.equipment.name
        task_name = task.schedule.task_name

        if task.assigned_to:
            Notification.create_notification(
                user=task.assigned_to,
                notification_type="task_rejected",
                title="დავალება უარყოფილია",
                message=f"{task_company.name}: {equipment_name} - '{task_name}' უარყოფილია.{reason_suffix}",
                link=f"/tasks/{task.id}/",
            )
        for manager in User.objects.filter(role="manager", tenant=task_company.tenant):
            Notification.create_notification(
                user=manager,
                notification_type="task_rejected",
                title="კლიენტმა უარყო სერვისი",
                message=f"{task_company.name}: {equipment_name} - '{task_name}' უარყოფილია.{reason_suffix}",
                link="/manager/tasks/",
            )

        return Response(self.get_serializer(task).data)


@api_view(["GET"])
@authentication_classes([JWTAuthentication, SessionAuthentication])
@permission_classes([IsAuthenticated])
def client_dashboard_api(request):
    """კლიენტის დაშბორდის სრული მონაცემები JSON ფორმატში (Flutter/Web API)"""
    from apps.companies.models import Equipment
    from apps.companies.serializers import CompanySerializer, EquipmentSerializer

    get_user_tenant(request.user)

    if not request.user.company:
        return Response(
            {
                "company": None,
                "stats": {
                    "equipment": 0,
                    "tasks_total": 0,
                    "tasks_pending": 0,
                    "tasks_completed": 0,
                    "tasks_approved": 0,
                    "tasks_rejected": 0,
                },
                "equipment": [],
                "tasks": [],
                "error": "თქვენ არ გაქვთ მიბმული კომპანია.",
            }
        )

    company = request.user.company
    equipment = Equipment.objects.filter(site__company=company).select_related(
        "site__company", "category"
    )
    tasks = (
        Task.objects.filter(schedule__equipment__in=equipment)
        .select_related("schedule__equipment__site__company", "assigned_to", "report")
        .prefetch_related("report__photos")
        .order_by("-scheduled_date")
    )

    stats = {
        "equipment": equipment.count(),
        "tasks_total": tasks.count(),
        "tasks_pending": tasks.filter(status__in=["pending", "in_progress"]).count(),
        "tasks_completed": tasks.filter(status="completed").count(),
        "tasks_approved": tasks.filter(status="approved").count(),
        "tasks_rejected": tasks.filter(status="rejected").count(),
    }

    return Response(
        {
            "company": CompanySerializer(company).data,
            "stats": stats,
            "equipment": EquipmentSerializer(equipment, many=True).data,
            "tasks": TaskSerializer(tasks, many=True).data,
        }
    )


# ==================== CALENDAR API ====================


@api_view(["GET"])
@authentication_classes([SessionAuthentication, JWTAuthentication])
@permission_classes([IsAuthenticated])
def calendar_events(request):
    """კალენდრის Events – უსაფრთხო წვდომა schedule/equipment-ისთვის."""
    user = request.user
    if getattr(user, "role", None) == "manager":
        user_tenant = get_user_tenant(user)
        tasks = Task.objects.filter(
            schedule__equipment__site__company__tenant=user_tenant
        ).select_related("schedule__equipment", "assigned_to")
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
    if request.user.role == "manager":
        user_tenant = get_user_tenant(request.user)
        if task.schedule.equipment.site.company.tenant != user_tenant:
            return Response(
                {"error": "Not authorized to view this task"},
                status=status.HTTP_403_FORBIDDEN,
            )
    elif request.user.role == "inspector" and task.assigned_to != request.user:
        return Response(
            {"error": "Not authorized to view this task"},
            status=status.HTTP_403_FORBIDDEN,
        )
    elif request.user.role == "client" and (
        not request.user.company
        or task.schedule.equipment.site.company != request.user.company
    ):
        return Response(
            {"error": "Not authorized to view this task"},
            status=status.HTTP_403_FORBIDDEN,
        )
    elif request.user.role not in ("manager", "inspector", "client"):
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

    report_data = None
    if hasattr(task, "report") and task.report:
        photos = []
        if hasattr(task.report, "photos"):
            for photo in task.report.photos.all():
                photos.append(
                    {
                        "id": photo.id,
                        "image": photo.image.url if photo.image else "",
                        "uploaded_at": (
                            photo.uploaded_at.isoformat()
                            if photo.uploaded_at
                            else None
                        ),
                    }
                )
        report_data = {
            "id": task.report.id,
            "comment": task.report.comment,
            "created_at": (
                task.report.created_at.isoformat() if task.report.created_at else None
            ),
            "photos": photos,
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
            "completed_date": (
                task.completed_date.isoformat() if task.completed_date else None
            ),
            "report": report_data,
        }
    )


@api_view(["POST"])
@authentication_classes([SessionAuthentication, JWTAuthentication])
@permission_classes([IsAuthenticated])
def update_task(request, task_id):
    """Task განახლება — გამოიყენე request.data, დაამატე ვალიდაცია scheduled_date/assigned_to"""
    task = get_object_or_404(Task, id=task_id)
    data = request.data.copy() if hasattr(request.data, "copy") else dict(request.data)

    user_role = getattr(request.user, "role", None)
    if user_role == "manager":
        user_tenant = get_user_tenant(request.user)
        if task.schedule.equipment.site.company.tenant != user_tenant:
            return Response(
                {"error": "Not authorized to update this task"},
                status=status.HTTP_403_FORBIDDEN,
            )
    elif user_role == "inspector" and request.user == task.assigned_to:
        requested_status = data.get("status")
        if requested_status in ("approved", "rejected"):
            return Response(
                {"error": "ინსპექტორს არ შეუძლია დავალების დამტკიცება ან უარყოფა"},
                status=status.HTTP_403_FORBIDDEN,
            )
        data.pop("assigned_to", None)
        data.pop("schedule", None)
    else:
        return Response(
            {"error": "Not authorized to update this task"},
            status=status.HTTP_403_FORBIDDEN,
        )

    old_status = task.status
    serializer = TaskSerializer(task, data=data, partial=True)
    if serializer.is_valid():
        updated_task = serializer.save()
        if (
            updated_task.status in ("completed", "approved")
            and not updated_task.completed_date
        ):
            updated_task.completed_date = timezone.now()
            updated_task.save(update_fields=["completed_date"])
        if old_status != "completed" and updated_task.status == "completed":
            notify_task_completed(updated_task)
        return Response({"success": True, "task_id": task.id})
    return Response({"error": serializer.errors}, status=status.HTTP_400_BAD_REQUEST)


@api_view(["POST"])
@authentication_classes([SessionAuthentication, JWTAuthentication])
@permission_classes([IsAuthenticated])
def delete_task(request, task_id):
    """Task წაშლა — მხოლოდ მენეჯერისთვის."""
    task = get_object_or_404(Task, id=task_id)
    user_role = getattr(request.user, "role", None)
    if user_role != "manager":
        return Response(
            {"error": "Not authorized to delete this task"},
            status=status.HTTP_403_FORBIDDEN,
        )
    user_tenant = get_user_tenant(request.user)
    if task.schedule.equipment.site.company.tenant != user_tenant:
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
    if getattr(request.user, "role", None) != "manager":
        return Response(
            {"error": "Not authorized to create tasks"},
            status=status.HTTP_403_FORBIDDEN,
        )

    data = {
        "schedule": request.data.get("schedule") or request.POST.get("schedule"),
        "assigned_to": request.data.get("inspector") or request.POST.get("inspector"),
        "scheduled_date": request.data.get("date") or request.POST.get("date"),
        "status": "pending",
    }

    serializer = TaskSerializer(data=data)
    if serializer.is_valid():
        task = serializer.save()
        if task.assigned_to:
            Notification.create_notification(
                user=task.assigned_to,
                notification_type="task_assigned",
                title="ახალი დავალება",
                message=f"თქვენ დაგენიშნათ დავალება: {task.schedule.equipment.name} - {task.schedule.task_name}",
                link=f"/tasks/{task.id}/",
            )
        return Response(
            {"success": True, "task_id": task.id},
            status=status.HTTP_201_CREATED,
        )
    return Response({"error": serializer.errors}, status=status.HTTP_400_BAD_REQUEST)


@api_view(["POST"])
@authentication_classes([SessionAuthentication, JWTAuthentication])
@permission_classes([IsAuthenticated])
def generate_tasks_api(request):
    """ტასკების გენერაცია გრაფიკებიდან API-ით"""
    from dateutil.relativedelta import relativedelta

    if getattr(request.user, "role", None) != "manager":
        return Response(
            {"error": "Only managers can generate tasks"},
            status=status.HTTP_403_FORBIDDEN,
        )

    today = timezone.now()
    user_tenant = get_user_tenant(request.user)
    inspector_id = request.data.get("inspector") or request.POST.get("inspector")
    if inspector_id:
        inspector = User.objects.filter(
            id=inspector_id, role="inspector", tenant=user_tenant
        ).first()
    else:
        inspector = User.objects.filter(role="inspector", tenant=user_tenant).first()

    if not inspector:
        return Response(
            {"error": "No inspector found to assign tasks for your tenant"},
            status=status.HTTP_400_BAD_REQUEST,
        )

    schedules = MaintenanceSchedule.objects.filter(
        equipment__site__company__tenant=user_tenant
    )
    created_count = 0

    for schedule in schedules:
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

    if created_count > 0:
        Notification.create_notification(
            user=inspector,
            notification_type="task_assigned",
            title="ახალი გეგმიური დავალებები",
            message=f"თქვენ დაგენიშნათ {created_count} ახალი გეგმიური დავალება.",
            link="/inspector/",
        )

    return Response(
        {
            "success": True,
            "message": f"შეიქმნა {created_count} ახალი ტასკი",
            "created_count": created_count,
        }
    )
