from django.contrib import admin
from django.urls import include, path


urlpatterns = [
    path('admin/', admin.site.urls),

    path(
        'api/accounts/',
        include('accounts.urls'),
    ),

    path(
        'api/vehicles/',
        include('vehicles.urls'),
    ),

    path(
        'api/trips/',
        include('trips.urls'),
    ),

    path(
        'api/routes/',
        include('routes.urls'),
    ),
    path(
    'api/ai/',
    include('ai_assistant.urls')
),
]