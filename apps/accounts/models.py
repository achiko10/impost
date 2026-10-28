from django.contrib.auth.models import AbstractUser
from django.db import models


class Tenant(models.Model):
    name = models.CharField(max_length=200, verbose_name="სააგენტოს დასახელება")
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.name


class User(AbstractUser):
    ROLE_CHOICES = [
        ("manager", "Manager"),
        ("inspector", "Inspector"),
        ("client", "Client"),
    ]

    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default="client")
    phone = models.CharField(max_length=20, blank=True)
    tenant = models.ForeignKey(
        Tenant,
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name="users"
    )
    # კლიენტისთვის - რომელ კომპანიას ეკუთვნის
    company = models.ForeignKey(
        "companies.Company",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="users",
    )

    def __str__(self):
        return f"{self.username} ({self.role})"


def get_user_tenant(user):
    """
    აბრუნებს მომხმარებლის Tenant-ს.
    თუ ძველ მომხმარებელს ან კომპანიებს tenant არ აქვთ მინიჭებული (legacy ჩანაწერები),
    ავტომატურად ქმნის/ანიჭებს დეფოლტ 'IMPOSTI' Tenant-ს, რათა თავიდან აიცილოს
    უსასრულო გადამისამართება (redirect loop) და მონაცემთა დაკარგვა.
    """
    if not user or not user.is_authenticated:
        return None

    if user.tenant_id:
        return user.tenant

    from apps.companies.models import Company

    default_tenant, _ = Tenant.objects.get_or_create(name="IMPOSTI")
    User.objects.filter(tenant__isnull=True).update(tenant=default_tenant)
    Company.objects.filter(tenant__isnull=True).update(tenant=default_tenant)
    user.tenant = default_tenant
    return default_tenant
