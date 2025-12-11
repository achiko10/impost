from django.urls import path
from . import views

urlpatterns = [
    # Manager Dashboard
    path("manager/", views.manager_main_dashboard, name="manager_dashboard"),
    # Companies
    path("manager/companies/", views.companies_list, name="companies_list"),
    path("companies/create/", views.create_company, name="create_company"),
    path(
        "companies/<int:company_id>/delete/",
        views.delete_company,
        name="delete_company",
    ),
    # Sites
    path("manager/sites/", views.sites_list, name="sites_list"),
    path("sites/create/", views.create_site, name="create_site"),
    path("sites/<int:site_id>/delete/", views.delete_site, name="delete_site"),
    # Equipment
    path("manager/equipment/", views.equipment_list, name="equipment_list"),
    path("equipment/create/", views.create_equipment, name="equipment_create"),
    path(
        "equipment/<int:equipment_id>/delete/",
        views.delete_equipment,
        name="equipment_delete",
    ),
    # Equipment Categories
    path("category/create/", views.create_category, name="category_create"),
    # Schedules
    path("manager/schedules/", views.schedules_list, name="schedules_list"),
    path("schedules/create/", views.create_schedule, name="create_schedule"),
    path(
        "schedules/<int:schedule_id>/delete/",
        views.delete_schedule,
        name="delete_schedule",
    ),
    # Tasks
    path("manager/tasks/", views.tasks_list, name="tasks_list"),
    path("tasks/generate/", views.generate_tasks, name="generate_tasks"),
    # Inspectors
    path("inspectors/create/", views.create_inspector, name="create_inspector"),
]
