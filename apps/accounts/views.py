from rest_framework import status
from rest_framework.decorators import api_view, permission_classes, authentication_classes
from rest_framework.response import Response
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.authentication import SessionAuthentication
from rest_framework_simplejwt.authentication import JWTAuthentication
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth import authenticate, login, logout
from django.contrib.auth.decorators import login_required
from django.shortcuts import render, redirect, get_object_or_404
from django.contrib import messages
from django.db import transaction
from .serializers import UserSerializer
from .models import Tenant, User, get_user_tenant


# ==================== REST API VIEWS ====================


@api_view(["POST"])
@permission_classes([AllowAny])
def login_view(request):
    username = request.data.get("username")
    password = request.data.get("password")

    user = authenticate(username=username, password=password)

    if user:
        get_user_tenant(user)
        refresh = RefreshToken.for_user(user)
        serializer = UserSerializer(user)

        return Response(
            {
                "user": serializer.data,
                "access": str(refresh.access_token),
                "refresh": str(refresh),
            }
        )

    return Response(
        {"error": "არასწორი მომხმარებელი ან პაროლი"},
        status=status.HTTP_401_UNAUTHORIZED,
    )


@api_view(["POST"])
@permission_classes([AllowAny])
def signup_api(request):
    """ახალი სააგენტოს (Tenant) და მენეჯერის რეგისტრაცია API-ით (Flutter/Mobile)"""
    company_name = request.data.get("company_name")
    username = request.data.get("username")
    password = request.data.get("password")
    first_name = request.data.get("first_name", "")
    last_name = request.data.get("last_name", "")
    phone = request.data.get("phone", "")

    if not company_name or not username or not password:
        return Response(
            {
                "error": "გთხოვთ შეავსოთ ყველა სავალდებულო ველი (company_name, username, password)"
            },
            status=status.HTTP_400_BAD_REQUEST,
        )

    if User.objects.filter(username=username).exists():
        return Response(
            {"error": f"მომხმარებელი სახელით '{username}' უკვე არსებობს"},
            status=status.HTTP_400_BAD_REQUEST,
        )

    try:
        with transaction.atomic():
            tenant = Tenant.objects.create(name=company_name)
            user = User.objects.create_user(
                username=username,
                password=password,
                role="manager",
                tenant=tenant,
                first_name=first_name,
                last_name=last_name,
                phone=phone,
            )
        refresh = RefreshToken.for_user(user)
        return Response(
            {
                "user": UserSerializer(user).data,
                "access": str(refresh.access_token),
                "refresh": str(refresh),
            },
            status=status.HTTP_201_CREATED,
        )
    except Exception as e:
        return Response({"error": str(e)}, status=status.HTTP_400_BAD_REQUEST)


@api_view(["POST"])
@authentication_classes([JWTAuthentication, SessionAuthentication])
@permission_classes([IsAuthenticated])
def logout_view(request):
    try:
        refresh_token = request.data.get("refresh")
        if refresh_token:
            token = RefreshToken(refresh_token)
            token.blacklist()
            return Response(
                {"message": "Logged out successfully"}, status=status.HTTP_200_OK
            )
        return Response(
            {"error": "Refresh token is required"}, status=status.HTTP_400_BAD_REQUEST
        )
    except Exception as e:
        return Response({"error": str(e)}, status=status.HTTP_400_BAD_REQUEST)


@api_view(["GET", "PATCH", "PUT"])
@authentication_classes([JWTAuthentication, SessionAuthentication])
@permission_classes([IsAuthenticated])
def profile_view(request):
    get_user_tenant(request.user)
    if request.method in ("PATCH", "PUT"):
        serializer = UserSerializer(request.user, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    serializer = UserSerializer(request.user)
    return Response(serializer.data)


@api_view(["GET", "POST"])
@authentication_classes([JWTAuthentication, SessionAuthentication])
@permission_classes([IsAuthenticated])
def users_api(request):
    """მენეჯერის მიერ მომხმარებლების (ინსპექტორები, კლიენტები) სიის ნახვა და შექმნა API-ით"""
    if request.user.role != "manager":
        return Response(
            {"error": "მხოლოდ მენეჯერს აქვს წვდომა"},
            status=status.HTTP_403_FORBIDDEN,
        )

    user_tenant = get_user_tenant(request.user)

    if request.method == "GET":
        users = (
            User.objects.filter(tenant=user_tenant)
            .select_related("company", "tenant")
            .order_by("role", "username")
        )
        role_filter = request.GET.get("role")
        if role_filter:
            users = users.filter(role=role_filter)
        return Response(UserSerializer(users, many=True).data)

    # POST - create user
    username = request.data.get("username")
    password = request.data.get("password")
    role = request.data.get("role")
    first_name = request.data.get("first_name", "")
    last_name = request.data.get("last_name", "")
    phone = request.data.get("phone", "")
    email = request.data.get("email", "")
    company_id = request.data.get("company")

    if not username or not password or role not in ("inspector", "client", "manager"):
        return Response(
            {"error": "username, password და ვალიდური role სავალდებულოა"},
            status=status.HTTP_400_BAD_REQUEST,
        )

    if User.objects.filter(username=username).exists():
        return Response(
            {"error": f"მომხმარებელი '{username}' უკვე არსებობს"},
            status=status.HTTP_400_BAD_REQUEST,
        )

    from apps.companies.models import Company

    company = None
    if role == "client" and company_id:
        company = get_object_or_404(Company, id=company_id, tenant=user_tenant)

    new_user = User.objects.create_user(
        username=username,
        password=password,
        email=email,
        role=role,
        tenant=user_tenant,
        company=company,
        first_name=first_name,
        last_name=last_name,
        phone=phone,
    )
    return Response(UserSerializer(new_user).data, status=status.HTTP_201_CREATED)


@api_view(["GET", "PATCH", "DELETE"])
@authentication_classes([JWTAuthentication, SessionAuthentication])
@permission_classes([IsAuthenticated])
def user_detail_api(request, user_id):
    """მენეჯერის მიერ კონკრეტული მომხმარებლის ნახვა, რედაქტირება ან წაშლა API-ით"""
    if request.user.role != "manager":
        return Response(
            {"error": "მხოლოდ მენეჯერს აქვს წვდომა"},
            status=status.HTTP_403_FORBIDDEN,
        )

    user_tenant = get_user_tenant(request.user)
    target_user = get_object_or_404(User, id=user_id, tenant=user_tenant)

    if request.method == "GET":
        return Response(UserSerializer(target_user).data)

    if request.method == "PATCH":
        serializer = UserSerializer(target_user, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            new_password = request.data.get("password")
            if new_password:
                target_user.set_password(new_password)
                target_user.save(update_fields=["password"])
            return Response(UserSerializer(target_user).data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    # DELETE
    if target_user.id == request.user.id:
        return Response(
            {"error": "საკუთარი ექაუნთის წაშლა შეუძლებელია"},
            status=status.HTTP_400_BAD_REQUEST,
        )
    target_user.delete()
    return Response(status=status.HTTP_204_NO_CONTENT)


# ==================== WEB VIEWS ====================


def login_page(request):
    if request.method == "POST":
        username = request.POST.get("username")
        password = request.POST.get("password")
        user = authenticate(request, username=username, password=password)

        if user:
            get_user_tenant(user)
            login(request, user)
            return redirect("dashboard")
        else:
            messages.error(request, "არასწორი მომხმარებელი ან პაროლი")

    return render(request, "auth/login.html")


def logout_page(request):
    logout(request)
    return redirect("login")


@login_required
def dashboard(request):
    get_user_tenant(request.user)
    if request.user.role == "inspector":
        return redirect("inspector_dashboard")
    elif request.user.role == "manager":
        return redirect("manager_dashboard")
    else:
        return redirect("client_dashboard")


def signup_page(request):
    if request.user.is_authenticated:
        return redirect("dashboard")

    if request.method == "POST":
        company_name = request.POST.get("company_name")
        username = request.POST.get("username")
        password = request.POST.get("password")
        first_name = request.POST.get("first_name", "")
        last_name = request.POST.get("last_name", "")
        phone = request.POST.get("phone", "")

        if not company_name or not username or not password:
            messages.error(request, "გთხოვთ შეავსოთ ყველა აუცილებელი ველი")
            return render(request, "auth/signup.html")

        try:
            if User.objects.filter(username=username).exists():
                messages.error(request, f"მომხმარებელი სახელით '{username}' უკვე არსებობს")
                return render(request, "auth/signup.html")

            with transaction.atomic():
                tenant = Tenant.objects.create(name=company_name)
                user = User.objects.create_user(
                    username=username,
                    password=password,
                    role="manager",
                    tenant=tenant,
                    first_name=first_name,
                    last_name=last_name,
                    phone=phone,
                )
            messages.success(request, "სააგენტო და მენეჯერი წარმატებით დარეგისტრირდა!")
            login(request, user)
            return redirect("dashboard")
        except Exception as e:
            messages.error(request, f"რეგისტრაციისას დაფიქსირდა შეცდომა: {str(e)}")

    return render(request, "auth/signup.html")


@login_required
def users_list(request):
    """სააგენტოს მომხმარებლების სია (ინსპექტორები და კლიენტები)"""
    if request.user.role != "manager":
        return redirect("dashboard")

    user_tenant = get_user_tenant(request.user)

    users = (
        User.objects.filter(tenant=user_tenant)
        .select_related("company")
        .exclude(id=request.user.id)
        .order_by("role", "username")
    )

    from apps.companies.models import Company

    companies = Company.objects.filter(tenant=user_tenant).order_by("name")

    return render(
        request,
        "manager/users.html",
        {
            "users_list": users,
            "companies": companies,
        },
    )


@login_required
def create_tenant_user(request):
    """სააგენტოს მომხმარებლის შექმნა მენეჯერის მიერ"""
    if request.user.role != "manager":
        return redirect("dashboard")

    user_tenant = get_user_tenant(request.user)

    if request.method == "POST":
        username = request.POST.get("username")
        password = request.POST.get("password")
        role = request.POST.get("role")
        first_name = request.POST.get("first_name", "")
        last_name = request.POST.get("last_name", "")
        phone = request.POST.get("phone", "")
        company_id = request.POST.get("company")

        if not username or not password or not role:
            messages.error(request, "გთხოვთ შეავსოთ სავალდებულო ველები")
            return redirect("users_list")

        if User.objects.filter(username=username).exists():
            messages.error(request, f"მომხმარებელი სახელით '{username}' უკვე არსებობს")
            return redirect("users_list")

        from apps.companies.models import Company

        company = None
        if role == "client" and company_id:
            company = get_object_or_404(Company, id=company_id, tenant=user_tenant)

        try:
            User.objects.create_user(
                username=username,
                password=password,
                role=role,
                tenant=user_tenant,
                company=company,
                first_name=first_name,
                last_name=last_name,
                phone=phone,
            )
            role_display = "ინსპექტორი" if role == "inspector" else "კლიენტი"
            messages.success(request, f"{role_display} '{username}' წარმატებით დაემატა!")
        except Exception as e:
            messages.error(request, f"მომხმარებლის შექმნისას დაფიქსირდა შეცდომა: {str(e)}")

    return redirect("users_list")


@login_required
def edit_tenant_user(request, user_id):
    """სააგენტოს მომხმარებლის რედაქტირება მენეჯერის მიერ"""
    if request.user.role != "manager":
        return redirect("dashboard")

    user_tenant = get_user_tenant(request.user)
    target_user = get_object_or_404(User, id=user_id, tenant=user_tenant)

    if request.method == "POST":
        username = request.POST.get("username", "").strip()
        role = request.POST.get("role", target_user.role)
        first_name = request.POST.get("first_name", "").strip()
        last_name = request.POST.get("last_name", "").strip()
        phone = request.POST.get("phone", "").strip()
        company_id = request.POST.get("company")
        password = request.POST.get("password", "").strip()

        if (
            username
            and username != target_user.username
            and User.objects.filter(username=username).exclude(id=target_user.id).exists()
        ):
            messages.error(request, f"მომხმარებელი სახელით '{username}' უკვე არსებობს")
            return redirect("users_list")

        from apps.companies.models import Company

        if username:
            target_user.username = username
        if role in ("inspector", "client"):
            target_user.role = role
        target_user.first_name = first_name
        target_user.last_name = last_name
        target_user.phone = phone

        if target_user.role == "client" and company_id:
            target_user.company = get_object_or_404(
                Company, id=company_id, tenant=user_tenant
            )
        elif target_user.role != "client":
            target_user.company = None

        if password:
            target_user.set_password(password)

        target_user.save()
        messages.success(request, f"მომხმარებელი '{target_user.username}' განახლდა!")

    return redirect("users_list")


@login_required
def delete_tenant_user(request, user_id):
    """სააგენტოს მომხმარებლის წაშლა"""
    if request.user.role != "manager":
        return redirect("dashboard")

    user_tenant = get_user_tenant(request.user)
    user_to_delete = get_object_or_404(User, id=user_id, tenant=user_tenant)

    if user_to_delete.id == request.user.id:
        messages.error(request, "საკუთარი ექაუნთის წაშლა შეუძლებელია")
        return redirect("users_list")

    username = user_to_delete.username
    user_to_delete.delete()
    messages.success(request, f"მომხმარებელი '{username}' წაშლილია!")
    return redirect("users_list")
