from django.contrib import admin
from django.urls import path, include, re_path
from django.views.generic import RedirectView
from django.views.static import serve
from django.conf import settings

urlpatterns = [
    # Redirect root to dashboard
    path("", RedirectView.as_view(pattern_name="dashboard", permanent=False)),
    path("admin/", admin.site.urls),
    path("", include("apps.accounts.urls")),
    path("", include("apps.tasks.urls")),
    path("", include("apps.companies.urls")),
    path("", include("apps.notifications.urls")),
    path("reports/", include("apps.reports.urls")),
    # Serve uploaded media files in both dev and production (Gunicorn/Render/Railway)
    re_path(r"^media/(?P<path>.*)$", serve, {"document_root": settings.MEDIA_ROOT}),
]
