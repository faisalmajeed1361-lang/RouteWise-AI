from django.contrib import admin

from .models import Trip


@admin.register(Trip)
class TripAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'user',
        'vehicle',
        'start_location',
        'destination',
        'distance_km',
        'fuel_needed',
        'estimated_cost',
        'created_at',
    )
    list_filter = ('created_at', 'vehicle__vehicle_type', 'vehicle__fuel_type')
    search_fields = (
        'user__username',
        'vehicle__vehicle_name',
        'start_location',
        'destination',
    )
    ordering = ('-created_at',)
    list_select_related = ('user', 'vehicle')
