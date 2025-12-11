from django.urls import path
from . import views

urlpatterns = [
    path("pdf/<int:company_id>/", views.generate_pdf_report, name="pdf_report"),
    path("excel/", views.generate_excel_report, name="excel_report"),
    path("monthly/", views.monthly_report, name="monthly_report"),
    path("equipment/<int:equipment_id>/", views.equipment_report, name="equipment_report"),
    path("task/<int:task_id>/pdf/", views.task_completion_pdf, name="task_completion_pdf"),
    path("task/<int:task_id>/email/", views.send_task_email, name="send_task_email"),
]
