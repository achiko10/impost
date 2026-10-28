from django.apps import AppConfig
import os


class AccountsConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.accounts"

    def ready(self):
        # Create initial users on startup (only when requested via env)
        if os.environ.get("RENDER") or os.environ.get("CREATE_USERS"):
            try:
                from django.contrib.auth import get_user_model
                from apps.accounts.models import Tenant

                User = get_user_model()

                # Check if users table exists and is empty
                if User.objects.count() == 0:
                    tenant, _ = Tenant.objects.get_or_create(name="IMPOSTI")

                    # Create superuser
                    User.objects.create_superuser(
                        username="admin",
                        email="admin@imposti.ge",
                        password="admin123secure",
                        role="manager",
                        tenant=tenant,
                        first_name="Admin",
                        last_name="User",
                    )
                    print("[OK] Superuser 'admin' created")

                    # Create manager
                    User.objects.create_user(
                        username="manager1",
                        email="manager@imposti.ge",
                        password="manager123",
                        role="manager",
                        tenant=tenant,
                        first_name="მენეჯერი",
                        last_name="პირველი",
                    )
                    print("[OK] Manager 'manager1' created")

                    # Create inspector
                    User.objects.create_user(
                        username="inspector1",
                        email="inspector@imposti.ge",
                        password="inspector123",
                        role="inspector",
                        tenant=tenant,
                        first_name="ინსპექტორი",
                        last_name="პირველი",
                    )
                    print("[OK] Inspector 'inspector1' created")

                    # Create client
                    User.objects.create_user(
                        username="client1",
                        email="client@imposti.ge",
                        password="client123",
                        role="client",
                        tenant=tenant,
                        first_name="კლიენტი",
                        last_name="პირველი",
                    )
                    print("[OK] Client 'client1' created")
                    print("=== All users created! ===")
            except Exception as e:
                print(f"User creation skipped: {e}")
