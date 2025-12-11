import os
import sys

# Ensure project root is on path so 'config' module is importable
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
if ROOT not in sys.path:
    sys.path.append(ROOT)

import django  # noqa: E402
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()


def list_patterns(resolver, prefix=''):
    for p in resolver.url_patterns:
        if hasattr(p, 'url_patterns'):
            list_patterns(p, prefix + str(p.pattern))
        else:
            name = getattr(p, 'name', None)
            print(prefix + str(p.pattern).lstrip('^').rstrip('$'), ' -> ', name)


if __name__ == '__main__':
    from django.urls import get_resolver

    resolver = get_resolver()
    list_patterns(resolver)
