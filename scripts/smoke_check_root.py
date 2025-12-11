from django.test import Client
from django.conf import settings

print('DEBUG=', settings.DEBUG)
client = Client()
resp = client.get('/')
print('Status code:', resp.status_code)
print('Location header:', resp.headers.get('Location'))
