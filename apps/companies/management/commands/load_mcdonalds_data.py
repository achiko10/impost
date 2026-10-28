from django.core.management.base import BaseCommand
from apps.accounts.models import Tenant, User
from apps.companies.models import Company, Site, Equipment, EquipmentCategory
from apps.tasks.models import MaintenanceSchedule


class Command(BaseCommand):
    help = "Load real McDonald's data"

    def handle(self, *args, **options):
        default_tenant, _ = Tenant.objects.get_or_create(name="IMPOSTI")

        self.stdout.write("Ensuring real McDonald's data...")

        # 1. Get or Create Company
        company, _ = Company.objects.get_or_create(
            name="McDonald's Georgia",
            defaults={"tenant": default_tenant},
        )
        if not company.tenant_id:
            company.tenant = default_tenant
            company.save(update_fields=["tenant"])
        self.stdout.write(self.style.SUCCESS(f"[OK] Company: {company.name}"))

        # Link client1 to McDonald's Georgia if present
        User.objects.filter(username="client1", company__isnull=True).update(
            company=company, tenant=default_tenant
        )

        # 2. Get or Create Site
        site, _ = Site.objects.get_or_create(
            company=company,
            name="McDonald's ერისთავი",
            defaults={"address": "ერისთავის 1"},
        )
        self.stdout.write(self.style.SUCCESS("[OK] Site created/verified"))

        # 3. Create Categories (with unique code)
        hvac_cat, _ = EquipmentCategory.objects.get_or_create(
            code="HVAC",
            defaults={
                "name": "HVAC",
                "system_type": "hvac",
                "icon": "bi-thermometer-half",
                "color": "#0d6efd",
                "description": "გათბობა, ვენტილაცია, კონდიცირება",
                "display_order": 1,
            },
        )

        ventilation_cat, _ = EquipmentCategory.objects.get_or_create(
            code="VENT",
            defaults={
                "name": "ვენტილაცია",
                "system_type": "ventilation",
                "icon": "bi-fan",
                "color": "#198754",
                "description": "ვენტილაციის სისტემები",
                "display_order": 2,
            },
        )

        split_cat, _ = EquipmentCategory.objects.get_or_create(
            code="SPLIT",
            defaults={
                "name": "სპლიტ სისტემა",
                "system_type": "hvac",
                "icon": "bi-snow",
                "color": "#0dcaf0",
                "description": "სპლიტ კონდიციონერები",
                "display_order": 3,
            },
        )
        self.stdout.write(self.style.SUCCESS("[OK] Categories created/verified"))

        # 4. Create Equipment (idempotently)
        eq_specs = [
            {
                "category": hvac_cat,
                "name": "Rooftop #1",
                "brand": "Clivet",
                "model_number": "Clivet",
                "serial_number": "AB806M5A0296",
                "system_type": "heating_cooling",
                "status": "active",
                "location_detail": "სახურავი",
            },
            {
                "category": hvac_cat,
                "name": "Rooftop #2",
                "brand": "Clivet",
                "model_number": "Clivet",
                "serial_number": "AB806M5A0297",
                "system_type": "heating_cooling",
                "status": "active",
                "location_detail": "სახურავი",
            },
            {
                "category": hvac_cat,
                "name": "Rooftop #3",
                "brand": "Clivet",
                "model_number": "Clivet",
                "serial_number": "",
                "system_type": "heating_cooling",
                "status": "active",
                "location_detail": "სახურავი",
            },
            {
                "category": ventilation_cat,
                "name": "KEF Ventilation #1",
                "brand": "Termofan",
                "model_number": "Termofan",
                "serial_number": "TS25-0051-0125",
                "system_type": "ventilation",
                "status": "active",
                "location_detail": "სამზარეულო",
            },
            {
                "category": ventilation_cat,
                "name": "KEF Ventilation #2",
                "brand": "Termofan",
                "model_number": "Termofan",
                "serial_number": "",
                "system_type": "ventilation",
                "status": "active",
                "location_detail": "სამზარეულო",
            },
            {
                "category": split_cat,
                "name": "სპლიტ კონდიციონერი #1",
                "brand": "",
                "model_number": "",
                "serial_number": "",
                "system_type": "heating_cooling",
                "status": "active",
                "location_detail": "დარბაზი",
            },
            {
                "category": split_cat,
                "name": "სპლიტ კონდიციონერი #2",
                "brand": "",
                "model_number": "",
                "serial_number": "",
                "system_type": "heating_cooling",
                "status": "active",
                "location_detail": "ოფისი",
            },
        ]

        eq_items = []
        for spec in eq_specs:
            eq, _ = Equipment.objects.get_or_create(
                site=site,
                name=spec["name"],
                defaults=spec,
            )
            eq_items.append(eq)

        self.stdout.write(
            self.style.SUCCESS(f"[OK] {len(eq_items)} Equipment items verified")
        )

        # 5. Create default Maintenance Schedules for equipment
        for eq in eq_items:
            MaintenanceSchedule.objects.get_or_create(
                equipment=eq,
                task_name="ყოველთვიური გეგმიური შემოწმება და ფილტრების წმენდა",
                defaults={"frequency": "monthly"},
            )
        self.stdout.write(
            self.style.SUCCESS("[OK] Default maintenance schedules verified")
        )
        self.stdout.write(
            self.style.SUCCESS("\n=== All McDonald's data loaded! ===")
        )
