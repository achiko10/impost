from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth.decorators import login_required
from django.contrib import messages
from django.utils import timezone
from django.db.models import Count, Q, Prefetch
from django.db.models.functions import TruncMonth
from datetime import timedelta
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
from .models import Company, Site, Equipment, EquipmentCategory
from .serializers import (
    CompanySerializer,
    SiteSerializer,
    EquipmentCategorySerializer,
    EquipmentSerializer,
)
from apps.tasks.models import MaintenanceSchedule, Task
from apps.tasks.permissions import IsManagerOrReadOnly
from apps.tasks.serializers import MaintenanceScheduleSerializer, TaskSerializer
from apps.accounts.models import User, get_user_tenant
from apps.notifications.models import Notification


def _build_manager_dashboard_payload(user_tenant):
    """Helper to build Manager Dashboard statistics for both Web & REST API"""
    today = timezone.now()
    next_week = today + timedelta(days=7)

    stats = {
        "companies": Company.objects.filter(tenant=user_tenant).count(),
        "sites": Site.objects.filter(company__tenant=user_tenant).count(),
        "equipment": Equipment.objects.filter(site__company__tenant=user_tenant).count(),
        "schedules": MaintenanceSchedule.objects.filter(
            equipment__site__company__tenant=user_tenant
        ).count(),
        "tasks_total": Task.objects.filter(
            schedule__equipment__site__company__tenant=user_tenant
        ).count(),
        "tasks_pending": Task.objects.filter(
            status="pending", schedule__equipment__site__company__tenant=user_tenant
        ).count(),
        "tasks_in_progress": Task.objects.filter(
            status="in_progress", schedule__equipment__site__company__tenant=user_tenant
        ).count(),
        "tasks_completed": Task.objects.filter(
            status="completed", schedule__equipment__site__company__tenant=user_tenant
        ).count(),
        "tasks_approved": Task.objects.filter(
            status="approved", schedule__equipment__site__company__tenant=user_tenant
        ).count(),
        "tasks_rejected": Task.objects.filter(
            status="rejected", schedule__equipment__site__company__tenant=user_tenant
        ).count(),
        "tasks_overdue": Task.objects.filter(
            status="pending",
            scheduled_date__lt=today,
            schedule__equipment__site__company__tenant=user_tenant,
        ).count(),
        "inspectors": User.objects.filter(role="inspector", tenant=user_tenant).count(),
    }

    task_status_data = {
        "labels": [
            "მოლოდინში",
            "მიმდინარე",
            "დასრულებული",
            "დამტკიცებული",
            "უარყოფილი",
            "ვადაგასული",
        ],
        "values": [
            stats["tasks_pending"],
            stats["tasks_in_progress"],
            stats["tasks_completed"],
            stats["tasks_approved"],
            stats["tasks_rejected"],
            stats["tasks_overdue"],
        ],
        "colors": ["#ffc107", "#0dcaf0", "#198754", "#0d6efd", "#dc3545", "#ff6b6b"],
    }

    monthly_tasks = (
        Task.objects.filter(
            completed_date__isnull=False,
            schedule__equipment__site__company__tenant=user_tenant,
        )
        .annotate(month=TruncMonth("completed_date"))
        .values("month")
        .annotate(count=Count("id"))
        .order_by("month")
    )[:6]

    monthly_data = {
        "labels": [
            t["month"].strftime("%b %Y") if t["month"] else "" for t in monthly_tasks
        ],
        "values": [t["count"] for t in monthly_tasks],
    }

    inspector_stats = list(
        User.objects.filter(role="inspector", tenant=user_tenant)
        .annotate(
            total_tasks=Count("assigned_tasks"),
            completed_tasks=Count(
                "assigned_tasks",
                filter=Q(assigned_tasks__status__in=["completed", "approved"]),
            ),
        )
        .values(
            "id",
            "username",
            "first_name",
            "last_name",
            "total_tasks",
            "completed_tasks",
        )
    )

    urgent_tasks = (
        Task.objects.filter(
            status="pending",
            scheduled_date__lte=next_week,
            schedule__equipment__site__company__tenant=user_tenant,
        )
        .select_related("schedule__equipment__site__company", "assigned_to")
        .order_by("scheduled_date")[:5]
    )

    recent_tasks = (
        Task.objects.filter(schedule__equipment__site__company__tenant=user_tenant)
        .select_related("schedule__equipment__site__company", "assigned_to")
        .order_by("-created_at")[:10]
    )

    return {
        "stats": stats,
        "task_status_data": task_status_data,
        "monthly_data": monthly_data,
        "inspector_stats": inspector_stats,
        "urgent_tasks": urgent_tasks,
        "recent_tasks": recent_tasks,
    }


# ==================== REST API VIEWSETS & ENDPOINTS ====================


@api_view(["GET"])
@authentication_classes([JWTAuthentication, SessionAuthentication])
@permission_classes([IsAuthenticated])
def manager_dashboard_api(request):
    """Manager Dashboard სრული სტატისტიკა JSON ფორმატში (Flutter/Web API)"""
    if request.user.role != "manager":
        return Response(
            {"error": "მხოლოდ მენეჯერს აქვს წვდომა"},
            status=status.HTTP_403_FORBIDDEN,
        )

    user_tenant = get_user_tenant(request.user)
    payload = _build_manager_dashboard_payload(user_tenant)

    return Response(
        {
            "stats": payload["stats"],
            "task_status_data": payload["task_status_data"],
            "monthly_data": payload["monthly_data"],
            "inspector_stats": payload["inspector_stats"],
            "urgent_tasks": TaskSerializer(payload["urgent_tasks"], many=True).data,
            "recent_tasks": TaskSerializer(payload["recent_tasks"], many=True).data,
        }
    )


class CompanyViewSet(viewsets.ModelViewSet):
    """კომპანიების სრული CRUD API + /sites/ და /equipment/ ქვე-რესურსები"""

    serializer_class = CompanySerializer
    authentication_classes = [JWTAuthentication, SessionAuthentication]
    permission_classes = [IsManagerOrReadOnly]

    def get_queryset(self):
        user = self.request.user
        if user.role == "manager":
            user_tenant = get_user_tenant(user)
            return Company.objects.filter(tenant=user_tenant).order_by("name")
        if user.role == "client" and user.company_id:
            return Company.objects.filter(id=user.company_id)
        return Company.objects.none()

    def perform_create(self, serializer):
        user_tenant = get_user_tenant(self.request.user)
        serializer.save(tenant=user_tenant)

    @action(detail=True, methods=["get"])
    def sites(self, request, pk=None):
        company = self.get_object()
        sites = Site.objects.filter(company=company).order_by("name")
        return Response(SiteSerializer(sites, many=True).data)

    @action(detail=True, methods=["get"])
    def equipment(self, request, pk=None):
        company = self.get_object()
        equipment = (
            Equipment.objects.filter(site__company=company)
            .select_related("site__company", "category")
            .order_by("name")
        )
        return Response(EquipmentSerializer(equipment, many=True).data)


class SiteViewSet(viewsets.ModelViewSet):
    """ობიექტების (Sites) სრული CRUD API"""

    serializer_class = SiteSerializer
    authentication_classes = [JWTAuthentication, SessionAuthentication]
    permission_classes = [IsManagerOrReadOnly]

    def get_queryset(self):
        user = self.request.user
        if user.role == "manager":
            user_tenant = get_user_tenant(user)
            qs = Site.objects.filter(company__tenant=user_tenant).select_related(
                "company"
            )
        elif user.role == "client" and user.company_id:
            qs = Site.objects.filter(company_id=user.company_id).select_related(
                "company"
            )
        else:
            return Site.objects.none()

        company_id = self.request.query_params.get("company")
        if company_id:
            qs = qs.filter(company_id=company_id)
        return qs.order_by("company__name", "name")


class EquipmentCategoryViewSet(viewsets.ModelViewSet):
    """დანადგარების კატეგორიების სრული CRUD API"""

    serializer_class = EquipmentCategorySerializer
    authentication_classes = [JWTAuthentication, SessionAuthentication]
    permission_classes = [IsManagerOrReadOnly]
    queryset = EquipmentCategory.objects.all().order_by("display_order", "name")


class EquipmentViewSet(viewsets.ModelViewSet):
    """დანადგარების (Equipment) სრული CRUD API"""

    serializer_class = EquipmentSerializer
    authentication_classes = [JWTAuthentication, SessionAuthentication]
    permission_classes = [IsManagerOrReadOnly]

    def get_queryset(self):
        user = self.request.user
        if user.role == "manager":
            user_tenant = get_user_tenant(user)
            qs = Equipment.objects.filter(site__company__tenant=user_tenant)
        elif user.role == "client" and user.company_id:
            qs = Equipment.objects.filter(site__company_id=user.company_id)
        elif user.role == "inspector":
            user_tenant = get_user_tenant(user)
            qs = Equipment.objects.filter(site__company__tenant=user_tenant)
        else:
            return Equipment.objects.none()

        qs = qs.select_related("site__company", "category")

        site_id = self.request.query_params.get("site")
        company_id = self.request.query_params.get("company")
        category_id = self.request.query_params.get("category")
        status_filter = self.request.query_params.get("status")

        if site_id:
            qs = qs.filter(site_id=site_id)
        if company_id:
            qs = qs.filter(site__company_id=company_id)
        if category_id:
            qs = qs.filter(category_id=category_id)
        if status_filter:
            qs = qs.filter(status=status_filter)

        return qs.order_by("category__display_order", "site__name", "name")


class MaintenanceScheduleViewSet(viewsets.ModelViewSet):
    """გეგმიური შემოწმებების გრაფიკის (MaintenanceSchedule) სრული CRUD API"""

    serializer_class = MaintenanceScheduleSerializer
    authentication_classes = [JWTAuthentication, SessionAuthentication]
    permission_classes = [IsManagerOrReadOnly]

    def get_queryset(self):
        user = self.request.user
        if user.role == "manager":
            user_tenant = get_user_tenant(user)
            qs = MaintenanceSchedule.objects.filter(
                equipment__site__company__tenant=user_tenant
            )
        elif user.role == "client" and user.company_id:
            qs = MaintenanceSchedule.objects.filter(
                equipment__site__company_id=user.company_id
            )
        else:
            return MaintenanceSchedule.objects.none()

        qs = qs.select_related("equipment__site__company")
        equipment_id = self.request.query_params.get("equipment")
        if equipment_id:
            qs = qs.filter(equipment_id=equipment_id)
        return qs.order_by("equipment__name")


# ==================== MANAGER WEB VIEWS ====================


@login_required
def manager_main_dashboard(request):
    """Manager მთავარი გვერდი"""
    if request.user.role != "manager":
        return redirect("dashboard")

    user_tenant = get_user_tenant(request.user)
    payload = _build_manager_dashboard_payload(user_tenant)

    return render(
        request,
        "manager/home.html",
        payload,
    )


@login_required
def companies_list(request):
    """კომპანიების სია"""
    if request.user.role != "manager":
        return redirect("dashboard")

    user_tenant = get_user_tenant(request.user)
    companies = (
        Company.objects.filter(tenant=user_tenant)
        .annotate(
            sites_count=Count("sites", distinct=True),
            equipment_count=Count("sites__equipment", distinct=True),
        )
        .order_by("name")
    )
    return render(request, "manager/companies.html", {"companies": companies})


@login_required
def create_company(request):
    if request.user.role != "manager":
        return redirect("dashboard")

    user_tenant = get_user_tenant(request.user)

    if request.method == "POST":
        name = request.POST.get("name", "").strip()
        if name:
            Company.objects.create(name=name, tenant=user_tenant)
            messages.success(request, f'კომპანია "{name}" დაემატა!')

    return redirect("companies_list")


@login_required
def edit_company(request, company_id):
    if request.user.role != "manager":
        return redirect("dashboard")

    user_tenant = get_user_tenant(request.user)
    company = get_object_or_404(Company, id=company_id, tenant=user_tenant)

    if request.method == "POST":
        name = request.POST.get("name", "").strip()
        if name:
            company.name = name
            company.save(update_fields=["name"])
            messages.success(request, f'კომპანია "{name}" განახლდა!')

    return redirect("companies_list")


@login_required
def delete_company(request, company_id):
    if request.user.role != "manager":
        return redirect("dashboard")

    user_tenant = get_user_tenant(request.user)
    company = get_object_or_404(Company, id=company_id, tenant=user_tenant)
    company.delete()
    messages.success(request, "კომპანია წაშლილია!")
    return redirect("companies_list")


@login_required
def sites_list(request):
    """ობიექტების სია"""
    if request.user.role != "manager":
        return redirect("dashboard")

    user_tenant = get_user_tenant(request.user)
    sites = (
        Site.objects.filter(company__tenant=user_tenant)
        .select_related("company")
        .annotate(equipment_count=Count("equipment"))
        .order_by("company__name", "name")
    )
    companies = Company.objects.filter(tenant=user_tenant).order_by("name")

    return render(
        request, "manager/sites.html", {"sites": sites, "companies": companies}
    )


@login_required
def create_site(request):
    if request.user.role != "manager":
        return redirect("dashboard")

    user_tenant = get_user_tenant(request.user)

    if request.method == "POST":
        company_id = request.POST.get("company")
        name = request.POST.get("name", "").strip()
        address = request.POST.get("address", "").strip()

        company = get_object_or_404(Company, id=company_id, tenant=user_tenant)
        Site.objects.create(company=company, name=name, address=address)
        messages.success(request, f'ობიექტი "{name}" დაემატა!')

    return redirect("sites_list")


@login_required
def edit_site(request, site_id):
    if request.user.role != "manager":
        return redirect("dashboard")

    user_tenant = get_user_tenant(request.user)
    site = get_object_or_404(Site, id=site_id, company__tenant=user_tenant)

    if request.method == "POST":
        company_id = request.POST.get("company")
        name = request.POST.get("name", "").strip()
        address = request.POST.get("address", "").strip()

        if company_id:
            site.company = get_object_or_404(
                Company, id=company_id, tenant=user_tenant
            )
        if name:
            site.name = name
        site.address = address
        site.save()
        messages.success(request, f'ობიექტი "{site.name}" განახლდა!')

    return redirect("sites_list")


@login_required
def delete_site(request, site_id):
    if request.user.role != "manager":
        return redirect("dashboard")

    user_tenant = get_user_tenant(request.user)
    site = get_object_or_404(Site, id=site_id, company__tenant=user_tenant)
    site.delete()
    messages.success(request, "ობიექტი წაშლილია!")
    return redirect("sites_list")


@login_required
def equipment_list(request):
    """დანადგარების სია კატეგორიებით"""
    if request.user.role != "manager":
        return redirect("dashboard")

    user_tenant = get_user_tenant(request.user)

    equipment_list = (
        Equipment.objects.filter(site__company__tenant=user_tenant)
        .select_related("site__company", "category")
        .order_by("category__display_order", "site__name", "name")
    )
    sites = Site.objects.filter(company__tenant=user_tenant)
    categories = EquipmentCategory.objects.prefetch_related(
        Prefetch(
            "equipment",
            queryset=Equipment.objects.filter(site__company__tenant=user_tenant),
        )
    ).all()
    uncategorized = Equipment.objects.filter(
        category__isnull=True, site__company__tenant=user_tenant
    )

    stats = {
        "active": Equipment.objects.filter(
            status="active", site__company__tenant=user_tenant
        ).count(),
        "inactive": Equipment.objects.filter(
            status="inactive", site__company__tenant=user_tenant
        ).count(),
        "maintenance": Equipment.objects.filter(
            status="maintenance", site__company__tenant=user_tenant
        ).count(),
        "broken": Equipment.objects.filter(
            status="broken", site__company__tenant=user_tenant
        ).count(),
    }

    return render(
        request,
        "manager/equipment.html",
        {
            "equipment_list": equipment_list,
            "sites": sites,
            "categories": categories,
            "uncategorized": uncategorized,
            "stats": stats,
        },
    )


@login_required
def create_equipment(request):
    if request.user.role != "manager":
        return redirect("dashboard")

    user_tenant = get_user_tenant(request.user)

    if request.method == "POST":
        site_id = request.POST.get("site")
        category_id = request.POST.get("category")
        name = request.POST.get("name")
        brand = request.POST.get("brand", "")
        model_number = request.POST.get("model_number", "")
        serial_number = request.POST.get("serial_number", "")
        system_type = request.POST.get("system_type", "heating_cooling")
        status_val = request.POST.get("status", "active")
        location_detail = request.POST.get("location_detail", "")
        installation_date = request.POST.get("installation_date") or None
        warranty_end = request.POST.get("warranty_end") or None
        notes = request.POST.get("notes", "")

        site = get_object_or_404(Site, id=site_id, company__tenant=user_tenant)
        category = (
            get_object_or_404(EquipmentCategory, id=category_id)
            if category_id
            else None
        )

        Equipment.objects.create(
            site=site,
            category=category,
            name=name,
            brand=brand,
            model_number=model_number,
            serial_number=serial_number,
            system_type=system_type,
            status=status_val,
            location_detail=location_detail,
            installation_date=installation_date,
            warranty_end=warranty_end,
            notes=notes,
        )
        messages.success(request, f'მოწყობილობა "{name}" დაემატა!')

    return redirect("equipment_list")


@login_required
def edit_equipment(request, equipment_id):
    if request.user.role != "manager":
        return redirect("dashboard")

    user_tenant = get_user_tenant(request.user)
    equipment = get_object_or_404(
        Equipment, id=equipment_id, site__company__tenant=user_tenant
    )

    if request.method == "POST":
        site_id = request.POST.get("site")
        site = get_object_or_404(Site, id=site_id, company__tenant=user_tenant)

        equipment.site = site
        equipment.category_id = request.POST.get("category") or None
        equipment.name = request.POST.get("name")
        equipment.brand = request.POST.get("brand", "")
        equipment.model_number = request.POST.get("model_number", "")
        equipment.serial_number = request.POST.get("serial_number", "")
        equipment.system_type = request.POST.get("system_type", "heating_cooling")
        equipment.status = request.POST.get("status", "active")
        equipment.location_detail = request.POST.get("location_detail", "")
        equipment.installation_date = request.POST.get("installation_date") or None
        equipment.warranty_end = request.POST.get("warranty_end") or None
        equipment.notes = request.POST.get("notes", "")
        equipment.save()

        messages.success(request, f'მოწყობილობა "{equipment.name}" განახლდა!')
        return redirect("equipment_list")

    return redirect("equipment_list")


@login_required
def create_category(request):
    """ახალი კატეგორიის შექმნა"""
    if request.user.role != "manager":
        return redirect("dashboard")

    if request.method == "POST":
        name = request.POST.get("name")
        code = request.POST.get("code", "").upper()
        system_type = request.POST.get("system_type", "hvac")
        icon = request.POST.get("icon", "bi-gear")
        color = request.POST.get("color", "#6c757d")

        if not EquipmentCategory.objects.filter(code=code).exists():
            EquipmentCategory.objects.create(
                name=name,
                code=code,
                system_type=system_type,
                icon=icon,
                color=color,
            )
            messages.success(request, f'კატეგორია "{name}" შეიქმნა!')
        else:
            messages.error(request, f'კოდი "{code}" უკვე არსებობს!')

    return redirect("equipment_list")


@login_required
def delete_category(request, category_id):
    """კატეგორიის წაშლა"""
    if request.user.role != "manager":
        return redirect("dashboard")

    category = get_object_or_404(EquipmentCategory, id=category_id)
    category_name = category.name
    category.delete()
    messages.success(request, f'კატეგორია "{category_name}" წაშლილია!')
    return redirect("equipment_list")


@login_required
def delete_equipment(request, equipment_id):
    if request.user.role != "manager":
        return redirect("dashboard")

    user_tenant = get_user_tenant(request.user)
    equipment = get_object_or_404(
        Equipment, id=equipment_id, site__company__tenant=user_tenant
    )
    equipment.delete()
    messages.success(request, "დანადგარი წაშლილია!")
    return redirect("equipment_list")


@login_required
def schedules_list(request):
    """შემოწმებების გრაფიკი"""
    if request.user.role != "manager":
        return redirect("dashboard")

    user_tenant = get_user_tenant(request.user)
    schedules = (
        MaintenanceSchedule.objects.filter(
            equipment__site__company__tenant=user_tenant
        )
        .select_related("equipment__site__company")
        .order_by("equipment__name")
    )
    equipment_list = Equipment.objects.filter(
        site__company__tenant=user_tenant
    ).select_related("site__company")

    return render(
        request,
        "manager/schedules.html",
        {"schedules": schedules, "equipment_list": equipment_list},
    )


@login_required
def create_schedule(request):
    if request.user.role != "manager":
        return redirect("dashboard")

    user_tenant = get_user_tenant(request.user)

    if request.method == "POST":
        equipment_id = request.POST.get("equipment")
        task_name = request.POST.get("task_name")
        frequency = request.POST.get("frequency")

        equipment = get_object_or_404(
            Equipment, id=equipment_id, site__company__tenant=user_tenant
        )
        MaintenanceSchedule.objects.create(
            equipment=equipment, task_name=task_name, frequency=frequency
        )
        messages.success(request, f'შემოწმება "{task_name}" დაემატა!')

    return redirect("schedules_list")


@login_required
def edit_schedule(request, schedule_id):
    if request.user.role != "manager":
        return redirect("dashboard")

    user_tenant = get_user_tenant(request.user)
    schedule = get_object_or_404(
        MaintenanceSchedule,
        id=schedule_id,
        equipment__site__company__tenant=user_tenant,
    )

    if request.method == "POST":
        equipment_id = request.POST.get("equipment")
        task_name = request.POST.get("task_name", "").strip()
        frequency = request.POST.get("frequency", "").strip()

        if equipment_id:
            schedule.equipment = get_object_or_404(
                Equipment, id=equipment_id, site__company__tenant=user_tenant
            )
        if task_name:
            schedule.task_name = task_name
        if frequency:
            schedule.frequency = frequency
        schedule.save()
        messages.success(request, f'შემოწმება "{schedule.task_name}" განახლდა!')

    return redirect("schedules_list")


@login_required
def delete_schedule(request, schedule_id):
    if request.user.role != "manager":
        return redirect("dashboard")

    user_tenant = get_user_tenant(request.user)
    schedule = get_object_or_404(
        MaintenanceSchedule,
        id=schedule_id,
        equipment__site__company__tenant=user_tenant,
    )
    schedule.delete()
    messages.success(request, "შემოწმება წაშლილია!")
    return redirect("schedules_list")


@login_required
def tasks_list(request):
    """დავალებების სია ფილტრებით და სტატისტიკით"""
    if request.user.role != "manager":
        return redirect("dashboard")

    user_tenant = get_user_tenant(request.user)

    tasks = Task.objects.filter(
        schedule__equipment__site__company__tenant=user_tenant
    ).select_related(
        "schedule__equipment__site__company",
        "schedule__equipment__category",
        "assigned_to",
    )

    status_filter = request.GET.get("status")
    inspector_filter = request.GET.get("inspector")
    search = request.GET.get("search")
    date_from = request.GET.get("date_from")
    date_to = request.GET.get("date_to")

    if status_filter:
        tasks = tasks.filter(status=status_filter)
    if inspector_filter:
        tasks = tasks.filter(assigned_to_id=inspector_filter)
    if search:
        tasks = tasks.filter(
            Q(schedule__equipment__name__icontains=search)
            | Q(schedule__task_name__icontains=search)
            | Q(schedule__equipment__site__name__icontains=search)
            | Q(schedule__equipment__site__company__name__icontains=search)
        )
    if date_from:
        tasks = tasks.filter(scheduled_date__gte=date_from)
    if date_to:
        tasks = tasks.filter(scheduled_date__lte=date_to)

    all_tasks = Task.objects.filter(
        schedule__equipment__site__company__tenant=user_tenant
    )
    stats = {
        "total": all_tasks.count(),
        "pending": all_tasks.filter(status="pending").count(),
        "in_progress": all_tasks.filter(status="in_progress").count(),
        "completed": all_tasks.filter(status="completed").count(),
        "approved": all_tasks.filter(status="approved").count(),
        "rejected": all_tasks.filter(status="rejected").count(),
    }

    tasks = tasks.order_by("-scheduled_date")[:200]
    inspectors = User.objects.filter(role="inspector", tenant=user_tenant)

    return render(
        request,
        "manager/tasks.html",
        {
            "tasks": tasks,
            "inspectors": inspectors,
            "stats": stats,
        },
    )


@login_required
def generate_tasks(request):
    if request.user.role != "manager":
        return redirect("dashboard")

    user_tenant = get_user_tenant(request.user)

    if request.method == "POST":
        from dateutil.relativedelta import relativedelta

        today = timezone.now()
        inspector_id = request.POST.get("inspector")
        if inspector_id:
            inspector = User.objects.filter(
                id=inspector_id, role="inspector", tenant=user_tenant
            ).first()
        else:
            inspector = User.objects.filter(role="inspector", tenant=user_tenant).first()

        if not inspector:
            messages.error(
                request, "დავალებების მისანიჭებლად ინსპექტორი ვერ მოიძებნა!"
            )
            return redirect("tasks_list")

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
                scheduled_date = today.replace(
                    hour=9, minute=0, second=0, microsecond=0
                )
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

        messages.success(
            request,
            f"წარმატებით შეიქმნა {created_count} ახალი ტასკი ({inspector.get_full_name() or inspector.username})!",
        )

    return redirect("tasks_list")


@login_required
def create_inspector(request):
    if request.user.role != "manager":
        return redirect("dashboard")

    user_tenant = get_user_tenant(request.user)

    if request.method == "POST":
        username = request.POST.get("username")
        password = request.POST.get("password")
        phone = request.POST.get("phone", "")
        first_name = request.POST.get("first_name", "")
        last_name = request.POST.get("last_name", "")

        if User.objects.filter(username=username).exists():
            messages.error(request, f'მომხმარებელი "{username}" უკვე არსებობს!')
        else:
            User.objects.create_user(
                username=username,
                password=password,
                role="inspector",
                tenant=user_tenant,
                phone=phone,
                first_name=first_name,
                last_name=last_name,
            )
            messages.success(request, f'ინსპექტორი "{username}" დაემატა!')

    return redirect("manager_dashboard")
