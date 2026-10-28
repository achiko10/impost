from rest_framework import serializers
from .models import Company, Site, Equipment, EquipmentCategory


class CompanySerializer(serializers.ModelSerializer):
    sites_count = serializers.SerializerMethodField()
    equipment_count = serializers.SerializerMethodField()

    class Meta:
        model = Company
        fields = [
            "id",
            "name",
            "tenant",
            "created_at",
            "sites_count",
            "equipment_count",
        ]
        read_only_fields = ["id", "tenant", "created_at"]

    def get_sites_count(self, obj):
        return obj.sites.count()

    def get_equipment_count(self, obj):
        return Equipment.objects.filter(site__company=obj).count()


class SiteSerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(source="company.name", read_only=True)
    equipment_count = serializers.SerializerMethodField()

    class Meta:
        model = Site
        fields = [
            "id",
            "company",
            "company_name",
            "name",
            "address",
            "created_at",
            "equipment_count",
        ]
        read_only_fields = ["id", "created_at"]

    def get_equipment_count(self, obj):
        return obj.equipment.count()


class EquipmentCategorySerializer(serializers.ModelSerializer):
    equipment_count = serializers.SerializerMethodField()

    class Meta:
        model = EquipmentCategory
        fields = [
            "id",
            "name",
            "code",
            "system_type",
            "icon",
            "color",
            "description",
            "display_order",
            "equipment_count",
        ]
        read_only_fields = ["id"]

    def get_equipment_count(self, obj):
        return obj.equipment.count()


class EquipmentSerializer(serializers.ModelSerializer):
    site_name = serializers.CharField(source="site.name", read_only=True)
    company_id = serializers.IntegerField(source="site.company.id", read_only=True)
    company_name = serializers.CharField(source="site.company.name", read_only=True)
    category_name = serializers.CharField(
        source="category.name", read_only=True, default=None
    )
    category_color = serializers.CharField(
        source="category.color", read_only=True, default="#6c757d"
    )
    category_icon = serializers.CharField(
        source="category.icon", read_only=True, default="bi-gear"
    )
    status_display = serializers.CharField(
        source="get_status_display", read_only=True
    )
    system_type_display = serializers.CharField(
        source="get_system_type_display", read_only=True
    )
    is_under_warranty = serializers.BooleanField(read_only=True)

    class Meta:
        model = Equipment
        fields = "__all__"
        read_only_fields = ["id", "created_at", "updated_at"]
