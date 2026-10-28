from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth.decorators import login_required
from django.contrib import messages
from django.db.models import Q
from django.utils import timezone
from .models import Task, TaskReport, TaskPhoto, MaintenanceSchedule
from .views import notify_task_completed
from apps.accounts.models import User, get_user_tenant
from apps.notifications.models import Notification


@login_required
def inspector_dashboard(request):
    if request.user.role != "inspector":
        return redirect("dashboard")

    get_user_tenant(request.user)
    base_qs = (
        Task.objects.filter(assigned_to=request.user)
        .select_related("schedule__equipment__site__company", "report")
        .prefetch_related("report__photos")
    )

    stats = {
        "total": base_qs.count(),
        "pending": base_qs.filter(status="pending").count(),
        "in_progress": base_qs.filter(status="in_progress").count(),
        "rejected": base_qs.filter(status="rejected").count(),
        "completed": base_qs.filter(status__in=["completed", "approved"]).count(),
    }

    tasks = base_qs
    status_filter = request.GET.get("status", "").strip()
    search = request.GET.get("search", "").strip()

    if status_filter == "done":
        tasks = tasks.filter(status__in=["completed", "approved"])
    elif status_filter in ("pending", "in_progress", "rejected", "completed", "approved"):
        tasks = tasks.filter(status=status_filter)

    if search:
        tasks = tasks.filter(
            Q(schedule__equipment__name__icontains=search)
            | Q(schedule__task_name__icontains=search)
            | Q(schedule__equipment__site__name__icontains=search)
            | Q(schedule__equipment__site__company__name__icontains=search)
        )

    tasks = tasks.order_by("-scheduled_date")
    return render(
        request,
        "dashboard/inspector.html",
        {
            "tasks": tasks,
            "stats": stats,
            "status_filter": status_filter,
            "search": search,
        },
    )


@login_required
def task_detail(request, task_id):
    task = get_object_or_404(
        Task.objects.select_related(
            "schedule__equipment__site__company", "assigned_to", "report"
        ).prefetch_related("report__photos"),
        id=task_id,
    )

    # უსაფრთხოების შემოწმება როლების მიხედვით
    if request.user.role == "inspector" and task.assigned_to != request.user:
        messages.error(request, "არ გაქვთ წვდომა ამ დავალებაზე")
        return redirect("inspector_dashboard")
    elif request.user.role == "client":
        if (
            not request.user.company
            or task.schedule.equipment.site.company != request.user.company
        ):
            messages.error(request, "არ გაქვთ წვდომა ამ დავალებაზე")
            return redirect("client_dashboard")
    elif request.user.role == "manager":
        if task.schedule.equipment.site.company.tenant != get_user_tenant(request.user):
            messages.error(request, "არ გაქვთ წვდომა ამ დავალებაზე")
            return redirect("manager_home")

    if request.method == "POST":
        if request.user.role == "inspector" and task.assigned_to != request.user:
            messages.error(request, "არ გაქვთ წვდომა ამ დავალებაზე")
            return redirect("inspector_dashboard")

        delete_photo_id = request.POST.get("delete_photo_id")
        if delete_photo_id:
            if task.status != "approved" or request.user.role == "manager":
                TaskPhoto.objects.filter(
                    id=delete_photo_id, report__task=task
                ).delete()
                messages.info(request, "ფოტო წაიშალა.")
            return redirect("task_detail", task_id=task.id)

        action = request.POST.get("action", "complete")
        comment = request.POST.get("comment", "")
        photos = request.FILES.getlist("photos")

        # შექმენი ან განაახლე რეპორტი
        report, _ = TaskReport.objects.update_or_create(
            task=task, defaults={"comment": comment}
        )

        # ატვირთე ფოტოები
        for photo in photos:
            TaskPhoto.objects.create(report=report, image=photo)

        if action == "save":
            # შენახვა გაგრძელებისთვის (Draft / In Progress)
            task.status = "in_progress"
            task.save(update_fields=["status"])
            messages.info(
                request, "სამუშაო პროგრესი შენახულია (სტატუსი: მიმდინარე)."
            )
            return redirect("task_detail", task_id=task.id)

        # სრული დასრულება
        task.status = "completed"
        task.completed_date = timezone.now()
        task.save()

        notify_task_completed(task)

        messages.success(request, "დავალება წარმატებით დასრულდა!")
        return redirect("inspector_dashboard")

    base_template = (
        "manager/base.html"
        if getattr(request.user, "role", None) == "manager"
        else "base/base.html"
    )
    return render(
        request,
        "dashboard/task_detail.html",
        {"task": task, "base_template": base_template},
    )


@login_required
def calendar_view(request):
    """კალენდარი"""
    user_tenant = get_user_tenant(request.user)
    inspectors = User.objects.filter(role="inspector", tenant=user_tenant)
    schedules = MaintenanceSchedule.objects.filter(
        equipment__site__company__tenant=user_tenant
    ).select_related("equipment__site")
    base_template = (
        "manager/base.html"
        if getattr(request.user, "role", None) == "manager"
        else "base/base.html"
    )

    return render(
        request,
        "dashboard/calendar.html",
        {
            "inspectors": inspectors,
            "schedules": schedules,
            "base_template": base_template,
        },
    )


@login_required
def client_dashboard(request):
    """კლიენტის დაშბორდი - აჩვენებს კომპანიის მოწყობილობების სერვისებს"""
    from apps.companies.models import Equipment

    get_user_tenant(request.user)

    # კლიენტს უნდა ჰქონდეს კომპანია მიბმული
    if not request.user.company:
        return render(
            request,
            "dashboard/client.html",
            {
                "tasks": [],
                "equipment": [],
                "company": None,
                "error": "თქვენ არ გაქვთ მიბმული კომპანია. დაუკავშირდით ადმინისტრატორს.",
            },
        )

    company = request.user.company

    # უსაფრთხოების შემოწმება: კომპანია უნდა ეკუთვნოდეს იმავე tenant-ს
    if request.user.tenant and company.tenant and company.tenant != request.user.tenant:
        return render(
            request,
            "dashboard/client.html",
            {
                "tasks": [],
                "equipment": [],
                "company": None,
                "error": "წვდომა აკრძალულია.",
            },
        )

    equipment = Equipment.objects.filter(site__company=company).select_related(
        "site", "category"
    )
    tasks = (
        Task.objects.filter(schedule__equipment__in=equipment)
        .select_related("schedule__equipment__site", "assigned_to", "report")
        .prefetch_related("report__photos")
        .order_by("-scheduled_date")
    )

    return render(
        request,
        "dashboard/client.html",
        {"tasks": tasks, "equipment": equipment, "company": company},
    )


@login_required
def client_approve_task(request, task_id):
    """კლიენტი ადასტურებს ან უარყოფს შესრულებულ დავალებას"""
    task = get_object_or_404(Task, id=task_id)

    # შემოწმება: კლიენტს უნდა ჰქონდეს წვდომა ამ დავალებაზე
    if request.user.role != "client":
        messages.error(request, "მხოლოდ კლიენტს შეუძლია დადასტურება")
        return redirect("dashboard")

    if not request.user.company:
        messages.error(request, "თქვენ არ გაქვთ მიბმული კომპანია")
        return redirect("client_dashboard")

    # დავალება უნდა ეკუთვნოდეს კლიენტის კომპანიას
    task_company = task.schedule.equipment.site.company
    if task_company != request.user.company:
        messages.error(request, "არ გაქვთ წვდომა ამ დავალებაზე")
        return redirect("client_dashboard")

    # დავალება უნდა იყოს completed სტატუსში
    if task.status != "completed":
        messages.error(request, "მხოლოდ დასრულებული დავალების დადასტურება შეიძლება")
        return redirect("client_dashboard")

    if request.method == "POST":
        action = request.POST.get("action")
        reason = request.POST.get("reason", "").strip()
        equipment_name = task.schedule.equipment.name
        task_name = task.schedule.task_name

        if action == "approve":
            task.status = "approved"
            if not task.completed_date:
                task.completed_date = timezone.now()
            task.save()

            if task.assigned_to:
                Notification.create_notification(
                    user=task.assigned_to,
                    notification_type="task_approved",
                    title="დავალება დადასტურდა კლიენტის მიერ",
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

            messages.success(request, "დავალება დადასტურებულია!")
        elif action == "reject":
            task.status = "rejected"
            task.save()

            if reason and hasattr(task, "report") and task.report:
                task.report.comment = (
                    f"{task.report.comment}\n\n[კლიენტის შენიშვნა: {reason}]".strip()
                )
                task.report.save(update_fields=["comment"])

            reason_suffix = f" მიზეზი: {reason}" if reason else ""

            if task.assigned_to:
                Notification.create_notification(
                    user=task.assigned_to,
                    notification_type="task_rejected",
                    title="დავალება უარყოფილია კლიენტის მიერ",
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

            messages.warning(request, "დავალება უარყოფილია!")

    return redirect("client_dashboard")
