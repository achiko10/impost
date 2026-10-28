from rest_framework import permissions


class IsManagerOrReadOnly(permissions.BasePermission):
    """
    Allow read-only access for any authenticated user,
    and write access (POST, PUT, PATCH, DELETE) only for managers.
    """

    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        if request.method in permissions.SAFE_METHODS:
            return True
        return getattr(request.user, "role", None) == "manager"


class IsManagerOrAssignedOrReadOnly(permissions.BasePermission):
    """
    Manager can do everything. Assigned inspector can update/complete own tasks (but not delete).
    Read-only for authenticated users.
    """

    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        # Allow safe methods for authenticated users
        if request.method in permissions.SAFE_METHODS:
            return True
        # Creation and deletion are allowed only for managers
        if getattr(view, "action", None) in ("create", "destroy") or request.method == "DELETE":
            return getattr(request.user, "role", None) == "manager"
        # For other methods, require authentication and let object permission decide
        return True

    def has_object_permission(self, request, view, obj):
        user_role = getattr(request.user, "role", None)
        if user_role == "manager":
            return True
        if request.method in permissions.SAFE_METHODS:
            return True
        if request.method == "DELETE" or getattr(view, "action", None) == "destroy":
            return False
        # assigned inspector can update/complete their own tasks
        if getattr(obj, "assigned_to", None) == request.user:
            return True
        return False
