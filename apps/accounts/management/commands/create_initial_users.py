from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model

User = get_user_model()


class Command(BaseCommand):
    help = "Create initial superuser and test users"

    def handle(self, *args, **options):
        # Try to get McDonald's company for client
        mcdonalds = None
        try:
            from apps.companies.models import Company
            mcdonalds = Company.objects.filter(name="McDonald's Georgia").first()
        except Exception:
            pass

        # Create superuser
        if not User.objects.filter(username="admin").exists():
            User.objects.create_superuser(
                username="admin",
                email="admin@imposti.ge",
                password="admin123secure",
                role="manager",
                first_name="Admin",
                last_name="User",
            )
            self.stdout.write(self.style.SUCCESS("Superuser 'admin' created"))
        else:
            self.stdout.write("Superuser 'admin' already exists")

        # Create manager
        if not User.objects.filter(username="manager1").exists():
            User.objects.create_user(
                username="manager1",
                email="manager@imposti.ge",
                password="manager123",
                role="manager",
                first_name="მენეჯერი",
                last_name="პირველი",
            )
            self.stdout.write(self.style.SUCCESS("Manager 'manager1' created"))

        # Create inspector
        if not User.objects.filter(username="inspector1").exists():
            User.objects.create_user(
                username="inspector1",
                email="inspector@imposti.ge",
                password="inspector123",
                role="inspector",
                first_name="ინსპექტორი",
                last_name="პირველი",
            )
            self.stdout.write(self.style.SUCCESS("Inspector 'inspector1' created"))

        # Create client (with company)
        if not User.objects.filter(username="client1").exists():
            client = User.objects.create_user(
                username="client1",
                email="client@imposti.ge",
                password="client123",
                role="client",
                first_name="კლიენტი",
                last_name="პირველი",
                company=mcdonalds,
            )
            self.stdout.write(self.style.SUCCESS(f"Client 'client1' created (company: {mcdonalds})"))
        else:
            # Update existing client with company
            client = User.objects.get(username="client1")
            if mcdonalds and not client.company:
                client.company = mcdonalds
                client.save()
                self.stdout.write(self.style.SUCCESS(f"Client 'client1' updated with company: {mcdonalds}"))


        self.stdout.write(self.style.SUCCESS("\n=== All users created successfully! ==="))
        self.stdout.write("Admin: admin / admin123secure")
        self.stdout.write("Manager: manager1 / manager123")
        self.stdout.write("Inspector: inspector1 / inspector123")
        self.stdout.write("Client: client1 / client123")
