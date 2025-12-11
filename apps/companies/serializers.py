from rest_framework import serializers
from .models import Company, Site, Equipment


class CompanySerializer(serializers.ModelSerializer):
    class Meta:
        model = Company
        fields = "__all__"


class SiteSerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(source="company.name", read_only=True)

    class Meta:
        model = Site
        fields = "__all__"


class EquipmentSerializer(serializers.ModelSerializer):
    site_name = serializers.CharField(source="site.name", read_only=True)
    company_name = serializers.CharField(source="site.company.name", read_only=True)

    class Meta:
        model = Equipment
        fields = "__all__"
