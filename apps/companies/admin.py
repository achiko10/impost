from django.contrib import admin
from django.utils.html import format_html
from .models import Company, Site, Equipment, EquipmentCategory


@admin.register(Company)
class CompanyAdmin(admin.ModelAdmin):
    list_display = ["name", "site_count", "equipment_count", "created_at"]
    search_fields = ["name"]
    
    def site_count(self, obj):
        return obj.sites.count()
    site_count.short_description = "ობიექტები"
    
    def equipment_count(self, obj):
        return Equipment.objects.filter(site__company=obj).count()
    equipment_count.short_description = "მოწყობილობები"


@admin.register(Site)
class SiteAdmin(admin.ModelAdmin):
    list_display = ["name", "company", "address", "equipment_count", "created_at"]
    list_filter = ["company"]
    search_fields = ["name", "address"]
    
    def equipment_count(self, obj):
        return obj.equipment.count()
    equipment_count.short_description = "მოწყობილობები"


@admin.register(EquipmentCategory)
class EquipmentCategoryAdmin(admin.ModelAdmin):
    list_display = ["display_icon", "name", "code", "system_type", "color_preview", "equipment_count", "display_order"]
    list_editable = ["display_order"]
    search_fields = ["name", "code"]
    list_filter = ["system_type"]
    ordering = ["display_order", "name"]
    
    def display_icon(self, obj):
        return format_html('<i class="{}" style="font-size: 1.5em; color: {};"></i>', obj.icon, obj.color)
    display_icon.short_description = ""
    
    def color_preview(self, obj):
        return format_html(
            '<span style="display: inline-block; width: 20px; height: 20px; background-color: {}; border-radius: 4px;"></span> {}',
            obj.color, obj.color
        )
    color_preview.short_description = "ფერი"
    
    def equipment_count(self, obj):
        return obj.equipment.count()
    equipment_count.short_description = "მოწყობილობები"


@admin.register(Equipment)
class EquipmentAdmin(admin.ModelAdmin):
    list_display = [
        "name", "category_badge", "site", "brand", "model_number", 
        "status", "status_badge", "location_detail", "warranty_status"
    ]
    list_filter = ["category", "status", "system_type", "site__company", "site"]
    search_fields = ["name", "serial_number", "brand", "model_number"]
    list_editable = ["status"]
    date_hierarchy = "created_at"
    
    fieldsets = (
        ("ძირითადი ინფორმაცია", {
            "fields": ("name", "category", "site", "system_type", "status")
        }),
        ("ტექნიკური დეტალები", {
            "fields": ("brand", "model_number", "serial_number"),
            "classes": ("collapse",)
        }),
        ("მდებარეობა და გარანტია", {
            "fields": ("location_detail", "installation_date", "warranty_end"),
            "classes": ("collapse",)
        }),
        ("დამატებითი", {
            "fields": ("notes",),
            "classes": ("collapse",)
        }),
    )
    
    def category_badge(self, obj):
        if obj.category:
            return format_html(
                '<span style="background-color: {}; color: white; padding: 3px 8px; border-radius: 4px; font-size: 11px;">'
                '<i class="{}" style="margin-right: 4px;"></i>{}</span>',
                obj.category.color, obj.category.icon, obj.category.name
            )
        return "-"
    category_badge.short_description = "კატეგორია"
    
    def status_badge(self, obj):
        colors = {
            "active": "#198754",
            "inactive": "#6c757d", 
            "maintenance": "#ffc107",
            "broken": "#dc3545"
        }
        return format_html(
            '<span style="background-color: {}; color: white; padding: 2px 6px; border-radius: 3px; font-size: 11px;">{}</span>',
            colors.get(obj.status, "#6c757d"), obj.get_status_display()
        )
    status_badge.short_description = "სტატუსი"
    
    def warranty_status(self, obj):
        if obj.warranty_end:
            if obj.is_under_warranty:
                return format_html('<span style="color: green;">✓ {}</span>', obj.warranty_end)
            return format_html('<span style="color: red;">✗ ვადაგასული</span>')
        return "-"
    warranty_status.short_description = "გარანტია"
