from rest_framework import serializers

from .models import Trip


class TripSerializer(serializers.ModelSerializer):
    class Meta:
        model = Trip
        fields = [
            'id',
            'user',
            'vehicle',
            'start_location',
            'destination',
            'distance_km',
            'fuel_price',
            'fuel_needed',
            'estimated_cost',
            'travel_time',
            'created_at',
        ]

        read_only_fields = [
            'id',
            'user',
            'fuel_needed',
            'estimated_cost',
            'created_at',
        ]

    def validate_vehicle(self, vehicle):
        request = self.context.get('request')

        if request and vehicle.user != request.user:
            raise serializers.ValidationError(
                'You can only create a trip using your own vehicle.'
            )

        return vehicle
