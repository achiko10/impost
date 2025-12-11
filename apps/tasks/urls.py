from django.urls import path, include
from rest_framework.routers import DefaultRouter
from . import views, template_views

router = DefaultRouter()
router.register(r"tasks", views.TaskViewSet, basename="task")

urlpatterns = [
    # API
    path("api/", include(router.urls)),
    # Calendar API URLs (outside api/ to bypass REST auth)
    path("calendar-events/", views.calendar_events, name="calendar_events"),
    path("task-detail/<int:task_id>/", views.task_detail_api, name="task_detail_api"),
    path("task-update/<int:task_id>/", views.update_task, name="update_task"),
    path("task-delete/<int:task_id>/", views.delete_task, name="delete_task"),
    path("task-create/", views.create_task, name="create_task"),
    path("api/generate-tasks/", views.generate_tasks_api, name="generate_tasks_api"),
    # Templates
    path("calendar/", template_views.calendar_view, name="calendar"),
    path("tasks/<int:task_id>/", template_views.task_detail, name="task_detail"),
    # Dashboards
    path("inspector/", template_views.inspector_dashboard, name="inspector_dashboard"),
    path("client/", template_views.client_dashboard, name="client_dashboard"),
    path("client/approve/<int:task_id>/", template_views.client_approve_task, name="client_approve_task"),
]
