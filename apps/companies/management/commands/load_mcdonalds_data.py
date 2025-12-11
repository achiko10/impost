from django.core.management.base import BaseCommand
from apps.companies.models import Company, Site, Equipment, EquipmentCategory
from apps.tasks.models import Schedule


class Command(BaseCommand):
    help = "Load real McDonald's data"

    def handle(self, *args, **options):
        # Check if data already exists
        if Company.objects.filter(name="McDonald's Georgia").exists():
            self.stdout.write("Data already exists, skipping...")
            return

        self.stdout.write("Creating real data...")

        # 1. Create Company
        company = Company.objects.create(
            name="McDonald's Georgia",
            contact_person="",
            email="",
            phone="",
        )
        self.stdout.write(self.style.SUCCESS(f"✅ Company: {company.name}"))

        # 2. Create Site
        site = Site.objects.create(
            company=company,
            name="McDonald's ერისთავი",
            address="ერისთავის 1",
        )
        self.stdout.write(self.style.SUCCESS(f"✅ Site: {site.name}"))

        # 3. Create Categories
        hvac_cat, _ = EquipmentCategory.objects.get_or_create(
            name="HVAC",
            defaults={"description": "გათბობა, ვენტილაცია, კონდიცირება"}
        )
        
        ventilation_cat, _ = EquipmentCategory.objects.get_or_create(
            name="ვენტილაცია",
            defaults={"description": "ვენტილაციის სისტემები"}
        )
        
        split_cat, _ = EquipmentCategory.objects.get_or_create(
            name="სპლიტ სისტემა",
            defaults={"description": "სპლიტ კონდიციონერები"}
        )
        self.stdout.write(self.style.SUCCESS("✅ Categories created"))

        # 4. Create Equipment

        # Rooftop (Clivet) - 3 units
        Equipment.objects.create(
            site=site,
            category=hvac_cat,
            name="Rooftop #1",
            model="Clivet",
            serial_number="AB806M5A0296",
            status="operational",
        )
        Equipment.objects.create(
            site=site,
            category=hvac_cat,
            name="Rooftop #2",
            model="Clivet",
            serial_number="AB806M5A0297",
            status="operational",
        )
        Equipment.objects.create(
            site=site,
            category=hvac_cat,
            name="Rooftop #3",
            model="Clivet",
            serial_number="",
            status="operational",
        )

        # KEF Ventilation (Termofan) - 2 units
        Equipment.objects.create(
            site=site,
            category=ventilation_cat,
            name="KEF Ventilation #1",
            model="Termofan",
            serial_number="TS25-0051-0125",
            status="operational",
        )
        Equipment.objects.create(
            site=site,
            category=ventilation_cat,
            name="KEF Ventilation #2",
            model="Termofan",
            serial_number="",
            status="operational",
        )

        # Split AC - 2 units
        Equipment.objects.create(
            site=site,
            category=split_cat,
            name="სპლიტ კონდიციონერი #1",
            model="",
            serial_number="",
            status="operational",
        )
        Equipment.objects.create(
            site=site,
            category=split_cat,
            name="სპლიტ კონდიციონერი #2",
            model="",
            serial_number="",
            status="operational",
        )
        self.stdout.write(self.style.SUCCESS("✅ 7 Equipment items created"))

        self.stdout.write(self.style.SUCCESS("\n=== All McDonald's data loaded! ==="))
