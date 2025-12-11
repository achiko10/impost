from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import User


@admin.register(User)
class CustomUserAdmin(UserAdmin):
    list_display = ["username", "email", "role", "company", "is_staff"]
    list_filter = ["role", "company", "is_staff"]
    fieldsets = UserAdmin.fieldsets + (
        ("დამატებითი ინფორმაცია", {"fields": ("role", "phone", "company")}),
    )
    autocomplete_fields = ["company"]
