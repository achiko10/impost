from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth.decorators import login_required
from django.contrib import messages
from .models import Task, TaskReport, TaskPhoto


@login_required
def inspector_dashboard(request):
    if request.user.role != "inspector":
        return redirect("dashboard")

    tasks = Task.objects.filter(assigned_to=request.user).order_by("-scheduled_date")
    return render(request, "dashboard/inspector.html", {"tasks": tasks})


@login_required
def task_detail(request, task_id):
    task = get_object_or_404(Task, id=task_id)

    # შემოწმება რომ inspector-მა მხოლოდ თავისი task ნახოს
    if request.user.role == "inspector" and task.assigned_to != request.user:
        messages.error(request, "არ გაქვთ წვდომა ამ დავალებაზე")
        return redirect("inspector_dashboard")

    if request.method == "POST":
        comment = request.POST.get("comment")
        photos = request.FILES.getlist("photos")

        # შექმენი რეპორტი
        report = TaskReport.objects.create(task=task, comment=comment)

        # ატვირთე ფოტოები
        for photo in photos:
            TaskPhoto.objects.create(report=report, image=photo)

        # განაახლე task სტატუსი
        task.status = "completed"
        task.save()

        messages.success(request, "დავალება წარმატებით დასრულდა!")
        return redirect("inspector_dashboard")

    return render(request, "dashboard/task_detail.html", {"task": task})


# ... არსებული კოდი ...


@login_required
def calendar_view(request):
    """კალენდარი"""
    from apps.tasks.models import MaintenanceSchedule
    from apps.accounts.models import User

    inspectors = User.objects.filter(role="inspector")
    schedules = MaintenanceSchedule.objects.all().select_related("equipment__site")

    return render(
        request,
        "dashboard/calendar.html",
        {"inspectors": inspectors, "schedules": schedules},
    )


@login_required
def client_dashboard(request):
    """კლიენტის დაშბორდი - აჩვენებს კომპანიის მოწყობილობების სერვისებს"""
    from apps.tasks.models import Task
    from apps.companies.models import Equipment

    # კლიენტს უნდა ჰქონდეს კომპანია მიბმული
    if not request.user.company:
        # თუ კომპანია არ აქვს, აჩვენე ცარიელი გვერდი
        return render(
            request,
            "dashboard/client.html",
            {"tasks": [], "equipment": [], "company": None, "error": "თქვენ არ გაქვთ მიბმული კომპანია. დაუკავშირდით ადმინისტრატორს."},
        )

    company = request.user.company
    # კომპანიის ობიექტების მოწყობილობები
    equipment = Equipment.objects.filter(site__company=company)
    # ამ მოწყობილობების დავალებები
    tasks = Task.objects.filter(
        schedule__equipment__in=equipment
    ).select_related(
        "schedule__equipment__site", "assigned_to"
    ).order_by("-scheduled_date")

    return render(
        request,
        "dashboard/client.html",
        {"tasks": tasks, "equipment": equipment, "company": company},
    )


@login_required
def client_approve_task(request, task_id):
    """კლიენტი ადასტურებს შესრულებულ დავალებას"""
    from apps.tasks.models import Task

    task = get_object_or_404(Task, id=task_id)

    # შემოწმება: კლიენტს უნდა ჰქონდეს წვდომა ამ დავალებაზე
    if request.user.role != "client":
        messages.error(request, "მხოლოდ კლიენტს შეუძლია დადასტურება")
        return redirect("dashboard")

    if not request.user.company:
        messages.error(request, "თქვენ არ გაქვთ მიბმული კომპანია")
        return redirect("client_dashboard")

    # დავალება უნდა ეკუთვნოდეს კლიენტის კომპანიას
    if task.schedule.equipment.site.company != request.user.company:
        messages.error(request, "არ გაქვთ წვდომა ამ დავალებაზე")
        return redirect("client_dashboard")

    # დავალება უნდა იყოს completed სტატუსში
    if task.status != "completed":
        messages.error(request, "მხოლოდ დასრულებული დავალების დადასტურება შეიძლება")
        return redirect("client_dashboard")

    if request.method == "POST":
        action = request.POST.get("action")
        if action == "approve":
            task.status = "approved"
            task.save()
            messages.success(request, "დავალება დადასტურებულია!")
        elif action == "reject":
            task.status = "rejected"
            task.save()
            messages.warning(request, "დავალება უარყოფილია!")

    return redirect("client_dashboard")
