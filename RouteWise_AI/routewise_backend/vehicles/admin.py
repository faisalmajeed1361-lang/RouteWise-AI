from django.contrib import admin

from .models import Vehicle


@admin.register(Vehicle)
class VehicleAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'vehicle_name',
        'user',
        'vehicle_type',
        'fuel_type',
        'fuel_average',
        'created_at',
    )
    list_filter = ('vehicle_type', 'fuel_type', 'created_at')
    search_fields = ('vehicle_name', 'user__username', 'user__email')
    ordering = ('-created_at',)
    list_select_related = ('user',)
