from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIClient
from rest_framework import status
from apps.accounts.models import Tenant, User
from apps.companies.models import Company, Site, Equipment, EquipmentCategory
from apps.tasks.models import MaintenanceSchedule, Task


class FullMaintenanceAPITestCase(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.tenant = Tenant.objects.create(name="IMPOSTI")

        self.manager = User.objects.create_user(
            username="test_manager",
            password="password123",
            role="manager",
            tenant=self.tenant,
        )
        self.inspector = User.objects.create_user(
            username="test_inspector",
            password="password123",
            role="inspector",
            tenant=self.tenant,
        )
        self.company = Company.objects.create(
            name="Test Client Co",
            tenant=self.tenant,
        )
        self.client_user = User.objects.create_user(
            username="test_client",
            password="password123",
            role="client",
            tenant=self.tenant,
            company=self.company,
        )
        self.site = Site.objects.create(
            company=self.company,
            name="Main Branch",
            address="Rustaveli 1",
        )
        self.category = EquipmentCategory.objects.create(
            name="HVAC",
            code="HVAC_TEST",
            system_type="hvac",
        )
        self.equipment = Equipment.objects.create(
            site=self.site,
            category=self.category,
            name="Chiller #1",
            system_type="heating_cooling",
            status="active",
        )
        self.schedule = MaintenanceSchedule.objects.create(
            equipment=self.equipment,
            task_name="Monthly Filter Check",
            frequency="monthly",
        )
        self.task = Task.objects.create(
            schedule=self.schedule,
            assigned_to=self.inspector,
            scheduled_date=timezone.now(),
            status="pending",
        )

    def authenticate_as(self, username, password="password123"):
        res = self.client.post(
            "/api/login/", {"username": username, "password": password}, format="json"
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        token = res.data["access"]
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {token}")
        return res.data

    def test_manager_api_endpoints(self):
        self.authenticate_as("test_manager")

        # 1. Manager Dashboard API
        res = self.client.get("/api/manager/dashboard/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data["stats"]["companies"], 1)
        self.assertEqual(res.data["stats"]["equipment"], 1)

        # 2. Companies CRUD & nested endpoints
        res = self.client.get("/api/companies/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(len(res.data), 1)

        res = self.client.get(f"/api/companies/{self.company.id}/sites/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(len(res.data), 1)

        res = self.client.get(f"/api/companies/{self.company.id}/equipment/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(len(res.data), 1)

        # 3. Equipment CRUD
        res = self.client.get(f"/api/equipment/{self.equipment.id}/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data["name"], "Chiller #1")

        # 4. Users API
        res = self.client.get("/api/users/?role=inspector")
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(len(res.data), 1)

    def test_inspector_and_client_task_workflow_api(self):
        # 1. Inspector starts and completes task
        self.authenticate_as("test_inspector")

        # Inspector cannot create/delete companies or self-approve a task
        res_forbidden_co = self.client.post("/api/companies/", {"name": "Hack Co"})
        self.assertEqual(res_forbidden_co.status_code, status.HTTP_403_FORBIDDEN)
        res_forbidden_approve = self.client.patch(
            f"/api/tasks/{self.task.id}/", {"status": "approved"}, format="json"
        )
        self.assertEqual(res_forbidden_approve.status_code, status.HTTP_403_FORBIDDEN)
        res_forbidden_del = self.client.delete(f"/api/tasks/{self.task.id}/")
        self.assertEqual(res_forbidden_del.status_code, status.HTTP_403_FORBIDDEN)

        res = self.client.post(f"/api/tasks/{self.task.id}/start/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data["status"], "in_progress")

        res = self.client.post(
            f"/api/tasks/{self.task.id}/complete/",
            {"comment": "Filters cleaned and tested"},
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data["status"], "completed")
        self.assertIsNotNone(res.data["completed_date"])
        self.assertEqual(res.data["report"]["comment"], "Filters cleaned and tested")

        # 2. Client views dashboard and approves task
        self.authenticate_as("test_client")

        res = self.client.get("/api/client/dashboard/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data["stats"]["tasks_completed"], 1)

        res = self.client.post(f"/api/tasks/{self.task.id}/approve/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data["status"], "approved")

        # 3. Inspector checks notifications
        self.authenticate_as("test_inspector")
        res = self.client.get("/api/notifications/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertGreaterEqual(res.data["unread_count"], 1)

    def test_web_edit_endpoints(self):
        self.client.login(username="test_manager", password="password123")

        # Edit company
        res = self.client.post(
            f"/companies/{self.company.id}/edit/", {"name": "Updated Co"}
        )
        self.assertEqual(res.status_code, 302)
        self.company.refresh_from_db()
        self.assertEqual(self.company.name, "Updated Co")

        # Edit site
        res = self.client.post(
            f"/sites/{self.site.id}/edit/",
            {
                "company": self.company.id,
                "name": "Updated Branch",
                "address": "Vake 10",
            },
        )
        self.assertEqual(res.status_code, 302)
        self.site.refresh_from_db()
        self.assertEqual(self.site.name, "Updated Branch")

        # Edit schedule
        res = self.client.post(
            f"/schedules/{self.schedule.id}/edit/",
            {
                "equipment": self.equipment.id,
                "frequency": "quarterly",
                "task_name": "Quarterly Deep Check",
            },
        )
        self.assertEqual(res.status_code, 302)
        self.schedule.refresh_from_db()
        self.assertEqual(self.schedule.frequency, "quarterly")
        self.assertEqual(self.schedule.task_name, "Quarterly Deep Check")

        # Edit tenant user
        res = self.client.post(
            f"/manager/users/edit/{self.inspector.id}/",
            {
                "username": "test_inspector",
                "role": "inspector",
                "first_name": "Giorgi",
                "last_name": "Beridze",
                "phone": "599001122",
            },
        )
        self.assertEqual(res.status_code, 302)
        self.inspector.refresh_from_db()
        self.assertEqual(self.inspector.first_name, "Giorgi")
        self.assertEqual(self.inspector.phone, "599001122")

        # Test Reports (Company PDF view & download, Monthly, Equipment History, Excel)
        res = self.client.get(f"/reports/pdf/{self.company.id}/")
        self.assertEqual(res.status_code, 200)

        res = self.client.get(f"/reports/pdf/{self.company.id}/?download=pdf")
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res["Content-Type"], "application/pdf")

        res = self.client.get("/reports/monthly/")
        self.assertEqual(res.status_code, 200)

        res = self.client.get(f"/reports/equipment/{self.equipment.id}/")
        self.assertEqual(res.status_code, 200)

        res = self.client.get("/reports/excel/")
        self.assertEqual(res.status_code, 200)

    def test_draft_save_and_rejection_rework_workflow(self):
        # 1. Inspector logs in on Web and saves draft (action="save")
        self.client.login(username="test_inspector", password="password123")
        res = self.client.post(
            f"/tasks/{self.task.id}/",
            {"comment": "დაწყებულია შემოწმება", "action": "save"},
        )
        self.assertEqual(res.status_code, 302)
        self.task.refresh_from_db()
        self.assertEqual(self.task.status, "in_progress")
        self.assertEqual(self.task.report.comment, "დაწყებულია შემოწმება")

        # 2. Inspector completes task (action="complete")
        res = self.client.post(
            f"/tasks/{self.task.id}/",
            {"comment": "შემოწმება დასრულებულია", "action": "complete"},
        )
        self.assertEqual(res.status_code, 302)
        self.task.refresh_from_db()
        self.assertEqual(self.task.status, "completed")

        # 3. Client views dashboard and rejects with reason
        self.client.login(username="test_client", password="password123")
        res = self.client.get("/client/")
        self.assertEqual(res.status_code, 200)

        res = self.client.post(
            f"/client/approve/{self.task.id}/",
            {"action": "reject", "reason": "აკლია ფილტრის სურათი"},
        )
        self.assertEqual(res.status_code, 302)
        self.task.refresh_from_db()
        self.task.report.refresh_from_db()
        self.assertEqual(self.task.status, "rejected")
        self.assertIn("აკლია ფილტრის სურათი", self.task.report.comment)

        # 4. Inspector views rejected task page and re-completes it
        self.client.login(username="test_inspector", password="password123")
        res = self.client.get(f"/tasks/{self.task.id}/")
        self.assertEqual(res.status_code, 200)

        res = self.client.post(
            f"/tasks/{self.task.id}/",
            {"comment": "ფილტრის სურათი დამატებულია და გასწორებულია", "action": "complete"},
        )
        self.assertEqual(res.status_code, 302)
        self.task.refresh_from_db()
        self.assertEqual(self.task.status, "completed")
