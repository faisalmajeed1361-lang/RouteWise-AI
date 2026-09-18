from rest_framework import serializers
from .models import Vehicle


class VehicleSerializer(serializers.ModelSerializer):
    class Meta:
        model = Vehicle
        fields = [
            'id',
            'user',
            'vehicle_name',
            'vehicle_type',
            'fuel_type',
            'fuel_average',
            'created_at',
        ]

        read_only_fields = [
            'id',
            'user',
            'created_at',
        ]