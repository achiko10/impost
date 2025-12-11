from django.urls import path
from . import views

urlpatterns = [
    # API endpoints
    path("api/login/", views.login_view, name="api_login"),
    path("api/logout/", views.logout_view, name="api_logout"),
    path("api/profile/", views.profile_view, name="api_profile"),
    # Web pages
    path("login/", views.login_page, name="login"),
    path("logout/", views.logout_page, name="logout"),
    path("dashboard/", views.dashboard, name="dashboard"),
]
