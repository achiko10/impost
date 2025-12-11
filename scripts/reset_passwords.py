"""Reset passwords for all users to known values."""
import os
import sys
import django

# Setup Django
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from apps.accounts.models import User

passwords = {
    'achi': 'achi123',
    'achiko': 'achiko123', 
    'manager1': 'manager123',
    'inspector1': 'inspector123',
    'client1': 'client123',
}

print("=" * 50)
print("RESETTING PASSWORDS")
print("=" * 50)

for username, password in passwords.items():
    try:
        user = User.objects.get(username=username)
        user.set_password(password)
        user.save()
        print(f"✓ {username}: {password}")
    except User.DoesNotExist:
        print(f"✗ {username}: NOT FOUND")

print("=" * 50)
print("DONE!")
