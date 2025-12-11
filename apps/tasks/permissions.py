from rest_framework import permissions


class IsManagerOrAssignedOrReadOnly(permissions.BasePermission):
    """
    Manager can do everything. Assigned inspector can update/complete own tasks.
    Read-only for authenticated users.
    """

    def has_permission(self, request, view):
        # Allow safe methods for authenticated users
        if request.method in permissions.SAFE_METHODS:
            return request.user.is_authenticated
        # Creation is allowed only for managers (view.action may not be set on function views)
        if getattr(view, "action", None) == "create":
            return getattr(request.user, "role", None) == "manager"
        # For other methods, require authentication and let object permission decide
        return request.user.is_authenticated

    def has_object_permission(self, request, view, obj):
        user_role = getattr(request.user, "role", None)
        if user_role == "manager":
            return True
        if request.method in permissions.SAFE_METHODS:
            return True
        # assigned inspector can update/delete/complete their own tasks
        if getattr(obj, "assigned_to", None) == request.user:
            return True
        return False
