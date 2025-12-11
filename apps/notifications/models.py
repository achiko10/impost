from django.db import models
from django.conf import settings


class Notification(models.Model):
    NOTIFICATION_TYPES = [
        ('task_assigned', 'დავალება მინიჭებული'),
        ('task_due', 'ვადა იწურება'),
        ('task_overdue', 'ვადა გასული'),
        ('task_completed', 'დავალება დასრულდა'),
        ('task_approved', 'დავალება დამტკიცდა'),
        ('task_rejected', 'დავალება უარყოფილია'),
        ('system', 'სისტემური'),
    ]
    
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="notifications"
    )
    notification_type = models.CharField(max_length=20, choices=NOTIFICATION_TYPES, default='system')
    title = models.CharField(max_length=200)
    message = models.TextField()
    link = models.CharField(max_length=500, blank=True, null=True)  # URL to related object
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.user.username} - {self.title}"

    class Meta:
        ordering = ["-created_at"]
    
    @classmethod
    def create_notification(cls, user, notification_type, title, message, link=None):
        """Helper method to create notifications"""
        return cls.objects.create(
            user=user,
            notification_type=notification_type,
            title=title,
            message=message,
            link=link
        )
