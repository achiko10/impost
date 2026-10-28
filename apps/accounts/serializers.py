from rest_framework import serializers
from .models import User


class UserSerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(source="company.name", read_only=True, default=None)
    tenant_name = serializers.CharField(source="tenant.name", read_only=True, default=None)
    full_name = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = [
            "id",
            "username",
            "email",
            "role",
            "phone",
            "first_name",
            "last_name",
            "full_name",
            "company",
            "company_name",
            "tenant",
            "tenant_name",
        ]
        read_only_fields = ["id", "tenant"]

    def get_full_name(self, obj):
        full = f"{obj.first_name} {obj.last_name}".strip()
        return full or obj.username
