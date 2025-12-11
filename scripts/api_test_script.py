import requests

BASE_URL = "http://127.0.0.1:8000"

# 1. Login
login_data = {"username": "inspector1", "password": "achiachi1997"}

response = requests.post(f"{BASE_URL}/api/login/", json=login_data)
print("Login Response:")
try:
    print(response.json())
except Exception:
    print(response.text)
print("\n" + "=" * 50 + "\n")

# შეინახე token
if response.status_code != 200:
    print("Login failed:", response.status_code, response.text)
    raise SystemExit(1)

token = response.json().get("access")
if not token:
    print("No token returned; aborting")
    raise SystemExit(1)

# 2. Get Tasks
headers = {"Authorization": f"Bearer {token}"}
response = requests.get(f"{BASE_URL}/api/tasks/", headers=headers)
print("Tasks Response:")
print(response.json())
