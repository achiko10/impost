import pytest
from django.urls import reverse
from rest_framework.test import APIClient
from apps.accounts.models import User
from apps.companies.models import Company, Site, Equipment
from apps.tasks.models import MaintenanceSchedule, Task
from rest_framework_simplejwt.tokens import RefreshToken


@pytest.fixture
def api_client():
    return APIClient()


@pytest.fixture
def manager(db):
    return User.objects.create_user(
        username="manager1", password="pass", role="manager"
    )


@pytest.fixture
def inspector(db):
    return User.objects.create_user(
        username="inspector1", password="pass", role="inspector"
    )


@pytest.mark.django_db
def test_manager_can_create_task(api_client, manager, inspector):
    token = str(RefreshToken.for_user(manager).access_token)
    api_client.credentials(HTTP_AUTHORIZATION=f"Bearer {token}")

    company = Company.objects.create(name="TestCo")
    site = Site.objects.create(company=company, name="TestSite", address="Addr")
    equip = Equipment.objects.create(
        site=site, name="Equip", system_type="heating_cooling"
    )
    schedule = MaintenanceSchedule.objects.create(
        equipment=equip, task_name="Check", frequency="monthly"
    )

    resp = api_client.post(
        reverse("create_task"),
        data={
            "schedule": schedule.id,
            "inspector": inspector.id,
            "date": "2025-12-10T10:00:00Z",
        },
        format="json",
    )
    assert resp.status_code == 201
    assert Task.objects.filter(schedule=schedule).exists()


@pytest.mark.django_db
def test_inspector_cannot_create_task(api_client, inspector):
    token = str(RefreshToken.for_user(inspector).access_token)
    api_client.credentials(HTTP_AUTHORIZATION=f"Bearer {token}")
    # Attempt to create without manager rights
    resp = api_client.post(
        reverse("create_task"),
        data={
            "schedule": 1,
            "inspector": inspector.id,
            "date": "2025-12-10T10:00:00Z",
        },
        format="json",
    )
    # Inspectors cannot create tasks (manager-only), expect 403 Forbidden
    assert resp.status_code == 403


@pytest.mark.django_db
def test_inspector_can_complete_own_task(api_client, inspector, manager):
    # Create schedule and task assigned to inspector
    token_mgr = str(RefreshToken.for_user(manager).access_token)
    api_client.credentials(HTTP_AUTHORIZATION=f"Bearer {token_mgr}")

    company = Company.objects.create(name="TestCo2")
    site = Site.objects.create(company=company, name="Site2", address="Addr2")
    equip = Equipment.objects.create(site=site, name="Equip2", system_type="heating_cooling")
    schedule = MaintenanceSchedule.objects.create(equipment=equip, task_name="Check2", frequency="monthly")
    task = Task.objects.create(schedule=schedule, assigned_to=inspector, scheduled_date="2025-12-10T10:00:00Z", status="pending")

    token = str(RefreshToken.for_user(inspector).access_token)
    api_client.credentials(HTTP_AUTHORIZATION=f"Bearer {token}")
    resp = api_client.post(reverse("task-complete", kwargs={"pk": task.id}))
    # expecting 200 OK
    assert resp.status_code == 200
    task.refresh_from_db()
    assert task.status == 'completed' or task.status == 'completed'


@pytest.mark.django_db
def test_other_inspector_cannot_complete_task(api_client, manager):
    inspector1 = User.objects.create_user(username="inspectorX", password="pass", role="inspector")
    inspector2 = User.objects.create_user(username="inspectorY", password="pass", role="inspector")
    token_mgr = str(RefreshToken.for_user(manager).access_token)
    api_client.credentials(HTTP_AUTHORIZATION=f"Bearer {token_mgr}")

    company = Company.objects.create(name="TestCo3")
    site = Site.objects.create(company=company, name="Site3", address="Addr3")
    equip = Equipment.objects.create(site=site, name="Equip3", system_type="heating_cooling")
    schedule = MaintenanceSchedule.objects.create(equipment=equip, task_name="Check3", frequency="monthly")
    task = Task.objects.create(
        schedule=schedule,
        assigned_to=inspector1,
        scheduled_date="2025-12-11T10:00:00Z",
        status="pending",
    )

    token = str(RefreshToken.for_user(inspector2).access_token)
    api_client.credentials(HTTP_AUTHORIZATION=f"Bearer {token}")
    resp = api_client.post(reverse("task-complete", kwargs={"pk": task.id}))
    # Other inspectors will not find the object (queryset filters by assigned_to) -> 404 Not Found
    assert resp.status_code == 404
