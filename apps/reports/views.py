from django.http import HttpResponse
from django.shortcuts import render, get_object_or_404
from django.contrib.auth.decorators import login_required
from django.template.loader import render_to_string
from django.utils import timezone
from datetime import datetime, timedelta
from io import BytesIO

from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment
from apps.tasks.models import Task, MaintenanceSchedule
from apps.companies.models import Company, Site, Equipment
from apps.accounts.models import User

# Try to import xhtml2pdf for PDF generation
try:
    from xhtml2pdf import pisa
    PDF_AVAILABLE = True
except ImportError:
    PDF_AVAILABLE = False


@login_required
def generate_pdf_report(request, company_id):
    """Generate PDF report for a company"""
    if not PDF_AVAILABLE:
        return HttpResponse("PDF generation not available. Install xhtml2pdf.", status=503)
    
    company = get_object_or_404(Company, id=company_id)
    
    # Get tasks for this company
    tasks = Task.objects.filter(
        schedule__equipment__site__company=company
    ).select_related(
        'schedule__equipment__site', 'assigned_to', 'report'
    ).order_by('-scheduled_date')
    
    # Statistics
    stats = {
        'total': tasks.count(),
        'pending': tasks.filter(status='pending').count(),
        'in_progress': tasks.filter(status='in_progress').count(),
        'completed': tasks.filter(status='completed').count(),
        'approved': tasks.filter(status='approved').count(),
    }
    
    context = {
        'company': company,
        'tasks': tasks,
        'stats': stats,
        'generated_at': timezone.now(),
    }
    
    # Render HTML
    html = render_to_string('reports/pdf_report.html', context)
    
    # Create PDF
    response = HttpResponse(content_type='application/pdf')
    response['Content-Disposition'] = f'attachment; filename="{company.name}_report_{datetime.now().strftime("%Y%m%d")}.pdf"'
    
    pisa_status = pisa.CreatePDF(BytesIO(html.encode('utf-8')), dest=response)
    
    if pisa_status.err:
        return HttpResponse('PDF generation error', status=500)
    
    return response


@login_required
def monthly_report(request):
    """Generate monthly report"""
    if request.user.role not in ['manager']:
        return HttpResponse('Unauthorized', status=403)
    
    # Get date range
    today = timezone.now()
    start_of_month = today.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    
    tasks = Task.objects.filter(
        scheduled_date__gte=start_of_month,
        scheduled_date__lte=today
    ).select_related('schedule__equipment__site__company', 'assigned_to')
    
    # Group by company
    companies_data = {}
    for task in tasks:
        company_name = task.schedule.equipment.site.company.name
        if company_name not in companies_data:
            companies_data[company_name] = {
                'total': 0,
                'completed': 0,
                'pending': 0,
            }
        companies_data[company_name]['total'] += 1
        if task.status in ['completed', 'approved']:
            companies_data[company_name]['completed'] += 1
        else:
            companies_data[company_name]['pending'] += 1
    
    context = {
        'month': today.strftime('%B %Y'),
        'companies_data': companies_data,
        'total_tasks': tasks.count(),
        'generated_at': today,
    }
    
    return render(request, 'reports/monthly_report.html', context)


@login_required
def equipment_report(request, equipment_id):
    """Generate equipment maintenance history report"""
    equipment = get_object_or_404(Equipment, id=equipment_id)
    
    tasks = Task.objects.filter(
        schedule__equipment=equipment
    ).select_related('assigned_to', 'report').order_by('-scheduled_date')
    
    context = {
        'equipment': equipment,
        'tasks': tasks,
        'generated_at': timezone.now(),
    }
    
    return render(request, 'reports/equipment_report.html', context)


@login_required
def task_completion_pdf(request, task_id):
    """დასრულებული ტასკის PDF - ოფიციალური დოკუმენტი"""
    task = get_object_or_404(Task, id=task_id)
    
    # Check permission
    if request.user.role == 'inspector' and task.assigned_to != request.user:
        return HttpResponse('Unauthorized', status=403)
    
    # Task must be completed
    if task.status not in ['completed', 'approved']:
        return HttpResponse('Task not completed yet', status=400)
    
    equipment = task.schedule.equipment
    site = equipment.site
    company = site.company
    
    context = {
        'task': task,
        'equipment': equipment,
        'site': site,
        'company': company,
        'report': getattr(task, 'report', None),
        'photos': task.report.photos.all() if hasattr(task, 'report') and task.report else [],
        'generated_at': timezone.now(),
    }
    
    # Check if PDF download requested
    if request.GET.get('download') == 'pdf' and PDF_AVAILABLE:
        html = render_to_string('reports/task_completion_pdf.html', context)
        
        response = HttpResponse(content_type='application/pdf')
        filename = f"task_{task.id}_{datetime.now().strftime('%Y%m%d')}.pdf"
        response['Content-Disposition'] = f'attachment; filename="{filename}"'
        
        pisa_status = pisa.CreatePDF(BytesIO(html.encode('utf-8')), dest=response)
        
        if pisa_status.err:
            return HttpResponse('PDF generation error', status=500)
        
        return response
    
    # Default: render HTML page with print button
    return render(request, 'reports/task_completion_view.html', context)


@login_required
def send_task_email(request, task_id):
    """დასრულებული ტასკის PDF გაგზავნა ემაილზე"""
    from django.core.mail import EmailMessage
    from django.conf import settings
    
    task = get_object_or_404(Task, id=task_id)
    
    # Only approved tasks
    if task.status != 'approved':
        return HttpResponse('მხოლოდ დამტკიცებული ტასკების გაგზავნა შეიძლება', status=400)
    
    # Get email from request
    recipient_email = request.POST.get('email') or request.GET.get('email')
    if not recipient_email:
        return HttpResponse('Email მისამართი აუცილებელია', status=400)
    
    # Generate PDF
    if not PDF_AVAILABLE:
        return HttpResponse("PDF არ არის ხელმისაწვდომი", status=503)
    
    equipment = task.schedule.equipment
    site = equipment.site
    company = site.company
    
    context = {
        'task': task,
        'equipment': equipment,
        'site': site,
        'company': company,
        'report': getattr(task, 'report', None),
        'photos': task.report.photos.all() if hasattr(task, 'report') and task.report else [],
        'generated_at': timezone.now(),
    }
    
    html = render_to_string('reports/task_completion_pdf.html', context)
    pdf_buffer = BytesIO()
    pisa.CreatePDF(BytesIO(html.encode('utf-8')), dest=pdf_buffer)
    pdf_buffer.seek(0)
    
    # Send email
    subject = f'სერვისის აქტი - {equipment.name} - {task.schedule.task_name}'
    body = f'''
გამარჯობა,

გაგზავნილია სერვისის აქტი შემდეგი სამუშაოსთვის:

კომპანია: {company.name}
ობიექტი: {site.name}
დანადგარი: {equipment.name}
სამუშაო: {task.schedule.task_name}
თარიღი: {task.completed_date or timezone.now()}

დოკუმენტი თანდართულია PDF ფორმატში.

პატივისცემით,
Maintenance Management System
'''
    
    try:
        email = EmailMessage(
            subject=subject,
            body=body,
            from_email=settings.DEFAULT_FROM_EMAIL,
            to=[recipient_email],
        )
        email.attach(
            f'service_act_{task.id}.pdf',
            pdf_buffer.getvalue(),
            'application/pdf'
        )
        email.send()
        
        return HttpResponse('ემაილი წარმატებით გაიგზავნა!', status=200)
    except Exception as e:
        return HttpResponse(f'შეცდომა ემაილის გაგზავნისას: {str(e)}', status=500)


@login_required
def generate_excel_report(request):
    if request.user.role not in ["manager", "client"]:
        return HttpResponse("Unauthorized", status=403)

    wb = Workbook()
    ws = wb.active
    ws.title = "Tasks Report"

    headers = [
        "ID",
        "კომპანია",
        "ობიექტი",
        "დანადგარი",
        "შემოწმება",
        "სიხშირე",
        "ინსპექტორი",
        "სტატუსი",
        "დაგეგმილი თარიღი",
        "დასრულების თარიღი",
        "კომენტარი",
    ]
    ws.append(headers)

    header_fill = PatternFill(
        start_color="0066CC", end_color="0066CC", fill_type="solid"
    )
    header_font = Font(bold=True, color="FFFFFF")

    for cell in ws[1]:
        cell.fill = header_fill
        cell.font = header_font
        cell.alignment = Alignment(horizontal="center", vertical="center")

    tasks = Task.objects.select_related(
        "schedule__equipment__site__company", "assigned_to", "report"
    ).order_by("-scheduled_date")

    for task in tasks:
        # Safely get values for Nullable fields
        scheduled_date_str = ""
        if getattr(task, "scheduled_date", None):
            # Use a safe formatted string for scheduled_date
            scheduled_date_attr = getattr(task, 'scheduled_date', None)
            scheduled_date_str = (
                scheduled_date_attr.strftime('%d.%m.%Y %H:%M') if scheduled_date_attr else ''
            )

        completed_date_str = ""
        if getattr(task, "completed_date", None):
            completed_date_attr = getattr(task, 'completed_date', None)
            completed_date_str = (
                completed_date_attr.strftime('%d.%m.%Y %H:%M') if completed_date_attr else ''
            )

        comment_text = ""
        if hasattr(task, "report") and getattr(task, "report") is not None:
            comment_text = getattr(task.report, "comment", "")

        ws.append(
            [
                task.id,
                task.schedule.equipment.site.company.name,
                task.schedule.equipment.site.name,
                task.schedule.equipment.name,
                task.schedule.task_name,
                task.schedule.get_frequency_display(),
                task.assigned_to.username if task.assigned_to else "",
                task.get_status_display(),
                scheduled_date_str,
                completed_date_str,
                comment_text,
            ]
        )

    for column in ws.columns:
        max_length = 0
        column_letter = column[0].column_letter
        for cell in column:
            try:
                if len(str(cell.value)) > max_length:
                    max_length = len(cell.value)
            except Exception:
                # ignore cells that can't be converted to string
                pass
        adjusted_width = min(max_length + 2, 50)
        ws.column_dimensions[column_letter].width = adjusted_width

    response = HttpResponse(
        content_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    )
    response["Content-Disposition"] = (
        f'attachment; filename="tasks_report_{datetime.now().strftime("%Y%m%d")}.xlsx"'
    )
    wb.save(response)

    return response
