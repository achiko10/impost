from django.core.management.base import BaseCommand
from apps.companies.models import Company, Site, Equipment
from apps.tasks.models import MaintenanceSchedule


class Command(BaseCommand):
    help = "Load real McDonald's data"

    def handle(self, *args, **kwargs):
        self.stdout.write("🚀 Loading real data...")

        # 1. Company
        company, _ = Company.objects.get_or_create(name="McDonald's")
        self.stdout.write(f"✅ Company: {company.name}")

        # 2. Site
        site, _ = Site.objects.get_or_create(
            company=company,
            name="ერისთავი",
            defaults={"address": "თბილისი, ერისთავის ქუჩა"},
        )
        self.stdout.write(f"✅ Site: {site.name}")

        # 3. Equipment - Rooftop (3 units)
        rooftops = [
            {"name": "Rooftop #1", "brand": "Clivet", "serial": "AB806M5A0296"},
            {"name": "Rooftop #2", "brand": "Clivet", "serial": "AB806M5A0297"},
            {"name": "Rooftop #3", "brand": "Clivet", "serial": "AB806M5A0298"},
        ]

        for data in rooftops:
            equip, _ = Equipment.objects.get_or_create(
                site=site,
                name=data["name"],
                defaults={
                    "brand": data["brand"],
                    "serial_number": data["serial"],
                    "system_type": "heating_cooling",
                },
            )
            self.stdout.write(f"✅ Equipment: {equip.name}")

        # 4. Equipment - KEF Ventilation (2 units)
        kef_units = [
            {
                "name": "KEF Ventilation #1",
                "brand": "Termofan",
                "serial": "TS25-0051-0125",
            },
            {
                "name": "KEF Ventilation #2",
                "brand": "Termofan",
                "serial": "TS25-0051-0127",
            },
        ]

        for data in kef_units:
            equip, _ = Equipment.objects.get_or_create(
                site=site,
                name=data["name"],
                defaults={
                    "brand": data["brand"],
                    "serial_number": data["serial"],
                    "system_type": "ventilation",
                },
            )
            self.stdout.write(f"✅ Equipment: {equip.name}")

        # 5. Equipment - Split Conditioners (2 units)
        splits = [
            {"name": "სპლიტ კონდიციონერი #1"},
            {"name": "სპლიტ კონდიციონერი #2"},
        ]

        for data in splits:
            equip, _ = Equipment.objects.get_or_create(
                site=site,
                name=data["name"],
                defaults={"system_type": "heating_cooling"},
            )
            self.stdout.write(f"✅ Equipment: {equip.name}")

        self.stdout.write("\n📋 Creating maintenance schedules...")

        # Rooftop schedules
        rooftop_monthly = [
            "მექანიკურ დაზიანებაზე შემოწმება",
            "ელექტრო დაზიანებაზე შემოწმება",
            "ვიზუალური დაზიანებაზე შემოწმება",
            "ჰაერის ფილტრების ქიმიური საშუალებით წმენდა",
            "ამძრავი ღვედის დაჭიმულობის შემოწმება",
            "შემსვლელი ტემპერატურის და წნევის შემოწმება",
        ]

        rooftop_quarterly = [
            "დრენაჟის შემოწმება",
            "ტემპერატურული მონაცემების შემოწმება",
            "მაცივარაგენტის წნევის შემოწმება",
            "მოწოდებული ელ.ენერგიის პარამეტრების შემოწმება",
        ]

        rooftop_biannual = [
            "დანადგარის გარეცხვა ანტიბაქტერიული ხსნარით",
            "სეზონური გადართვები",
        ]

        # Add schedules for all Rooftops
        for i in range(1, 4):
            equip = Equipment.objects.get(site=site, name=f"Rooftop #{i}")

            for task_name in rooftop_monthly:
                MaintenanceSchedule.objects.get_or_create(
                    equipment=equip, task_name=task_name, frequency="monthly"
                )

            for task_name in rooftop_quarterly:
                MaintenanceSchedule.objects.get_or_create(
                    equipment=equip, task_name=task_name, frequency="quarterly"
                )

            for task_name in rooftop_biannual:
                MaintenanceSchedule.objects.get_or_create(
                    equipment=equip, task_name=task_name, frequency="biannual"
                )

        self.stdout.write("✅ Rooftop schedules created")

        # KEF Ventilation schedules
        kef_monthly = [
            "მექანიკურ დაზიანებაზე შემოწმება",
            "ელექტრო დაზიანებაზე შემოწმება",
            "ვიზუალური დაზიანებაზე შემოწმება",
        ]

        kef_quarterly = [
            "ტემპერატურული მონაცემების შემოწმება",
            "მაცივარაგენტის წნევის შემოწმება",
            "მოწოდებული ელ.ენერგიის პარამეტრების შემოწმება",
        ]

        kef_biannual = [
            "დანადგარის გარეცხვა ანტიბაქტერიული ხსნარით",
            "ჰაერის ფილტრების ქიმიური საშუალებით წმენდა",
            "სეზონური გადართვები",
        ]

        for i in range(1, 3):
            equip = Equipment.objects.get(site=site, name=f"KEF Ventilation #{i}")

            for task_name in kef_monthly:
                MaintenanceSchedule.objects.get_or_create(
                    equipment=equip, task_name=task_name, frequency="monthly"
                )

            for task_name in kef_quarterly:
                MaintenanceSchedule.objects.get_or_create(
                    equipment=equip, task_name=task_name, frequency="quarterly"
                )

            for task_name in kef_biannual:
                MaintenanceSchedule.objects.get_or_create(
                    equipment=equip, task_name=task_name, frequency="biannual"
                )

        self.stdout.write("✅ KEF Ventilation schedules created")

        # Split Conditioner schedules
        split_monthly = [
            "მექანიკურ დაზიანებაზე შემოწმება",
            "ელექტრო დაზიანებაზე შემოწმება",
            "ვიზუალური დაზიანებაზე შემოწმება",
            "შეერთებების შემოწმება",
            "მართვის პულტის შემოწმება",
        ]

        split_quarterly = [
            "ფილტრების გაწმენდა",
            "ვენტილატორის მუშა მდგომარეობის შემოწმება",
            "გარე აგრეგატის რადიატორების გაწმენდა",
            "ტემპერატურული მონაცემების შემოწმება",
            "მაცივარაგენტის წნევის შემოწმება",
            "მოწოდებული ელ.ენერგიის პარამეტრების შემოწმება",
        ]

        split_biannual = [
            "დანადგარის გარეცხვა ანტიბაქტერიული ხსნარით",
            "ჰაერის ფილტრების ქიმიური საშუალებით წმენდა",
            "სეზონური გადართვები",
        ]

        for i in range(1, 3):
            equip = Equipment.objects.get(site=site, name=f"სპლიტ კონდიციონერი #{i}")

            for task_name in split_monthly:
                MaintenanceSchedule.objects.get_or_create(
                    equipment=equip, task_name=task_name, frequency="monthly"
                )

            for task_name in split_quarterly:
                MaintenanceSchedule.objects.get_or_create(
                    equipment=equip, task_name=task_name, frequency="quarterly"
                )

            for task_name in split_biannual:
                MaintenanceSchedule.objects.get_or_create(
                    equipment=equip, task_name=task_name, frequency="biannual"
                )

        self.stdout.write("✅ Split Conditioner schedules created")

        self.stdout.write(self.style.SUCCESS("\n🎉 All data loaded successfully!"))
        self.stdout.write(f"Total Equipment: {Equipment.objects.count()}")
        self.stdout.write(f"Total Schedules: {MaintenanceSchedule.objects.count()}")
