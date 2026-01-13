from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth.decorators import login_required
from django.contrib import messages
from django.utils import timezone
from django.http import JsonResponse
from django.db.models import Count, Q
from django.db.models.functions import TruncMonth
from datetime import timedelta
from .models import Company, Site, Equipment, EquipmentCategory
from apps.tasks.models import MaintenanceSchedule, Task
from apps.accounts.models import User
from rest_framework.decorators import api_view, permission_classes, authentication_classes
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework.authentication import SessionAuthentication
from rest_framework_simplejwt.authentication import JWTAuthentication
from rest_framework import status
from .serializers import EquipmentSerializer

# ==================== MANAGER DASHBOARD ====================


@login_required
def manager_main_dashboard(request):
    """Manager მთავარი გვერდი"""
    if request.user.role != "manager":
        return redirect("dashboard")

    today = timezone.now()
    next_week = today + timedelta(days=7)
    
    # Basic stats
    stats = {
        "companies": Company.objects.count(),
        "sites": Site.objects.count(),
        "equipment": Equipment.objects.count(),
        "schedules": MaintenanceSchedule.objects.count(),
        "tasks_total": Task.objects.count(),
        "tasks_pending": Task.objects.filter(status="pending").count(),
        "tasks_in_progress": Task.objects.filter(status="in_progress").count(),
        "tasks_completed": Task.objects.filter(status="completed").count(),
        "tasks_approved": Task.objects.filter(status="approved").count(),
        "tasks_rejected": Task.objects.filter(status="rejected").count(),
        "tasks_overdue": Task.objects.filter(status="pending", scheduled_date__lt=today).count(),
        "inspectors": User.objects.filter(role="inspector").count(),
    }
    
    # Task status distribution for pie chart
    task_status_data = {
        'labels': ['მოლოდინში', 'მიმდინარე', 'დასრულებული', 'დამტკიცებული', 'უარყოფილი', 'ვადაგასული'],
        'values': [
            stats['tasks_pending'],
            stats['tasks_in_progress'],
            stats['tasks_completed'],
            stats['tasks_approved'],
            stats['tasks_rejected'],
            stats['tasks_overdue'],
        ],
        'colors': ['#ffc107', '#0dcaf0', '#198754', '#0d6efd', '#dc3545', '#ff6b6b']
    }
    
    # Monthly task completion trend
    monthly_tasks = (
        Task.objects.filter(completed_date__isnull=False)
        .annotate(month=TruncMonth('completed_date'))
        .values('month')
        .annotate(count=Count('id'))
        .order_by('month')
    )[:6]
    
    monthly_data = {
        'labels': [t['month'].strftime('%b %Y') if t['month'] else '' for t in monthly_tasks],
        'values': [t['count'] for t in monthly_tasks]
    }
    
    # Inspector performance
    inspector_stats = (
        User.objects.filter(role='inspector')
        .annotate(
            total_tasks=Count('assigned_tasks'),
            completed_tasks=Count('assigned_tasks', filter=Q(assigned_tasks__status__in=['completed', 'approved']))
        )
        .values('username', 'total_tasks', 'completed_tasks')
    )
    
    urgent_tasks = (
        Task.objects.filter(status="pending", scheduled_date__lte=next_week)
        .select_related("schedule__equipment")
        .order_by("scheduled_date")[:5]
    )
    
    # Recent activity
    recent_tasks = (
        Task.objects.select_related('schedule__equipment', 'assigned_to')
        .order_by('-created_at')[:10]
    )

    return render(
        request,
        "manager/home.html",
        {
            "stats": stats,
            "urgent_tasks": urgent_tasks,
            "task_status_data": task_status_data,
            "monthly_data": monthly_data,
            "inspector_stats": list(inspector_stats),
            "recent_tasks": recent_tasks,
        },
    )


# ==================== COMPANIES ====================


@login_required
def companies_list(request):
    """კომპანიების სია"""
    if request.user.role != "manager":
        return redirect("dashboard")

    companies = Company.objects.all().order_by("name")
    return render(request, "manager/companies.html", {"companies": companies})


@login_required
def create_company(request):
    if request.user.role != "manager":
        return redirect("dashboard")

    if request.method == "POST":
        name = request.POST.get("name")
        Company.objects.create(name=name)
        messages.success(request, f'კომპანია "{name}" დაემატა!')

    return redirect("companies_list")


@login_required
def delete_company(request, company_id):
    if request.user.role != "manager":
        return redirect("dashboard")

    company = get_object_or_404(Company, id=company_id)
    company.delete()
    messages.success(request, "კომპანია წაშლილია!")
    return redirect("companies_list")


# ==================== SITES ====================


@login_required
def sites_list(request):
    """ობიექტების სია"""
    if request.user.role != "manager":
        return redirect("dashboard")

    sites = (
        Site.objects.all().select_related("company").order_by("company__name", "name")
    )
    companies = Company.objects.all()

    return render(
        request, "manager/sites.html", {"sites": sites, "companies": companies}
    )


@login_required
def create_site(request):
    if request.user.role != "manager":
        return redirect("dashboard")

    if request.method == "POST":
        company_id = request.POST.get("company")
        name = request.POST.get("name")
        address = request.POST.get("address")

        company = get_object_or_404(Company, id=company_id)
        Site.objects.create(company=company, name=name, address=address)
        messages.success(request, f'ობიექტი "{name}" დაემატა!')

    return redirect("sites_list")


@login_required
def delete_site(request, site_id):
    if request.user.role != "manager":
        return redirect("dashboard")

    site = get_object_or_404(Site, id=site_id)
    site.delete()
    messages.success(request, "ობიექტი წაშლილია!")
    return redirect("sites_list")


# ==================== EQUIPMENT ====================


@login_required
def equipment_list(request):
    """დანადგარების სია კატეგორიებით"""
    if request.user.role != "manager":
        return redirect("dashboard")

    equipment_list = (
        Equipment.objects.all()
        .select_related("site__company", "category")
        .order_by("category__display_order", "site__name", "name")
    )
    sites = Site.objects.all().select_related("company")
    categories = EquipmentCategory.objects.prefetch_related("equipment").all()
    uncategorized = Equipment.objects.filter(category__isnull=True)
    
    # Statistics
    stats = {
        "active": Equipment.objects.filter(status="active").count(),
        "inactive": Equipment.objects.filter(status="inactive").count(),
        "maintenance": Equipment.objects.filter(status="maintenance").count(),
        "broken": Equipment.objects.filter(status="broken").count(),
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

    if request.method == "POST":
        site_id = request.POST.get("site")
        category_id = request.POST.get("category")
        name = request.POST.get("name")
        brand = request.POST.get("brand", "")
        model_number = request.POST.get("model_number", "")
        serial_number = request.POST.get("serial_number", "")
        system_type = request.POST.get("system_type", "heating_cooling")
        status = request.POST.get("status", "active")
        location_detail = request.POST.get("location_detail", "")
        installation_date = request.POST.get("installation_date") or None
        warranty_end = request.POST.get("warranty_end") or None
        notes = request.POST.get("notes", "")

        site = get_object_or_404(Site, id=site_id)
        category = get_object_or_404(EquipmentCategory, id=category_id) if category_id else None
        
        Equipment.objects.create(
            site=site,
            category=category,
            name=name,
            brand=brand,
            model_number=model_number,
            serial_number=serial_number,
            system_type=system_type,
            status=status,
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

    equipment = get_object_or_404(Equipment, id=equipment_id)

    if request.method == "POST":
        equipment.site_id = request.POST.get("site")
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

    equipment = get_object_or_404(Equipment, id=equipment_id)
    equipment.delete()
    messages.success(request, "დანადგარი წაშლილია!")
    return redirect("equipment_list")


@api_view(["GET"])
@authentication_classes([SessionAuthentication, JWTAuthentication])
@permission_classes([IsAuthenticated])
def equipment_detail_api(request, equipment_id):
    """Equipment დეტალები API"""
    if request.user.role != "manager":
        return Response(
            {"error": "Not authorized"},
            status=status.HTTP_403_FORBIDDEN
        )
    
    equipment = get_object_or_404(Equipment, id=equipment_id)
    serializer = EquipmentSerializer(equipment)
    return Response(serializer.data)


# ==================== SCHEDULES ====================


@login_required
def schedules_list(request):
    """შემოწმებების გრაფიკი"""
    if request.user.role != "manager":
        return redirect("dashboard")

    schedules = (
        MaintenanceSchedule.objects.all()
        .select_related("equipment__site__company")
        .order_by("equipment__name")
    )
    equipment_list = Equipment.objects.all().select_related("site__company")

    return render(
        request,
        "manager/schedules.html",
        {"schedules": schedules, "equipment_list": equipment_list},
    )


@login_required
def create_schedule(request):
    if request.user.role != "manager":
        return redirect("dashboard")

    if request.method == "POST":
        equipment_id = request.POST.get("equipment")
        task_name = request.POST.get("task_name")
        frequency = request.POST.get("frequency")

        equipment = get_object_or_404(Equipment, id=equipment_id)
        MaintenanceSchedule.objects.create(
            equipment=equipment, task_name=task_name, frequency=frequency
        )
        messages.success(request, f'შემოწმება "{task_name}" დაემატა!')

    return redirect("schedules_list")


@login_required
def delete_schedule(request, schedule_id):
    if request.user.role != "manager":
        return redirect("dashboard")

    schedule = get_object_or_404(MaintenanceSchedule, id=schedule_id)
    schedule.delete()
    messages.success(request, "შემოწმება წაშლილია!")
    return redirect("schedules_list")


# ==================== TASKS ====================


@login_required
def tasks_list(request):
    """დავალებების სია ფილტრებით და სტატისტიკით"""
    if request.user.role != "manager":
        return redirect("dashboard")

    # Base query with relations
    tasks = Task.objects.all().select_related(
        "schedule__equipment__site", 
        "schedule__equipment__category",
        "assigned_to"
    )

    # Apply filters
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
            schedule__equipment__name__icontains=search
        ) | tasks.filter(
            schedule__task_name__icontains=search
        )
    if date_from:
        tasks = tasks.filter(scheduled_date__gte=date_from)
    if date_to:
        tasks = tasks.filter(scheduled_date__lte=date_to)

    # Statistics (before slicing)
    all_tasks = Task.objects.all()
    stats = {
        "total": all_tasks.count(),
        "pending": all_tasks.filter(status="pending").count(),
        "in_progress": all_tasks.filter(status="in_progress").count(),
        "completed": all_tasks.filter(status="completed").count(),
        "approved": all_tasks.filter(status="approved").count(),
        "rejected": all_tasks.filter(status="rejected").count(),
    }

    # Order and limit
    tasks = tasks.order_by("-scheduled_date")[:200]

    inspectors = User.objects.filter(role="inspector")

    return render(
        request, 
        "manager/tasks.html", 
        {
            "tasks": tasks, 
            "inspectors": inspectors,
            "stats": stats,
        }
    )


@login_required
def generate_tasks(request):
    if request.user.role != "manager":
        return redirect("dashboard")

    if request.method == "POST":
        from django.core.management import call_command

        call_command("generate_tasks")
        messages.success(request, "ახალი ტასკები შეიქმნა!")

    return redirect("tasks_list")


# ==================== INSPECTORS ====================


@login_required
def create_inspector(request):
    if request.user.role != "manager":
        return redirect("dashboard")

    if request.method == "POST":
        username = request.POST.get("username")
        password = request.POST.get("password")
        phone = request.POST.get("phone", "")
        first_name = request.POST.get("first_name", "")
        last_name = request.POST.get("last_name", "")

        User.objects.create_user(
            username=username,
            password=password,
            role="inspector",
            phone=phone,
            first_name=first_name,
            last_name=last_name,
        )
        messages.success(request, f'ინსპექტორი "{username}" დაემატა!')

    return redirect("manager_dashboard")
