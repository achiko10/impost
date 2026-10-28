from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from . import views

urlpatterns = [
    # API endpoints
    path("api/login/", views.login_view, name="api_login"),
    path("api/signup/", views.signup_api, name="api_signup"),
    path("api/token/refresh/", TokenRefreshView.as_view(), name="token_refresh"),
    path("api/logout/", views.logout_view, name="api_logout"),
    path("api/profile/", views.profile_view, name="api_profile"),
    path("api/users/", views.users_api, name="api_users"),
    path("api/users/<int:user_id>/", views.user_detail_api, name="api_user_detail"),
    # Web pages
    path("login/", views.login_page, name="login"),
    path("logout/", views.logout_page, name="logout"),
    path("signup/", views.signup_page, name="signup"),
    path("dashboard/", views.dashboard, name="dashboard"),
    path("manager/users/", views.users_list, name="users_list"),
    path("manager/users/create/", views.create_tenant_user, name="create_tenant_user"),
    path(
        "manager/users/edit/<int:user_id>/",
        views.edit_tenant_user,
        name="edit_tenant_user",
    ),
    path(
        "manager/users/delete/<int:user_id>/",
        views.delete_tenant_user,
        name="delete_tenant_user",
    ),
]
