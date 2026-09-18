from rest_framework import generics, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.authentication import JWTAuthentication

from vehicles.models import Vehicle
from .models import Trip
from .serializers import TripSerializer


class TripListCreateAPIView(generics.ListCreateAPIView):
    serializer_class = TripSerializer
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Trip.objects.filter(
            user=self.request.user
        ).select_related('vehicle').order_by('-created_at')

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


class TripDetailAPIView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = TripSerializer
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Trip.objects.filter(
            user=self.request.user
        ).select_related('vehicle')


class FuelCalculationAPIView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        vehicle_id = request.data.get('vehicle_id')
        distance_km = request.data.get('distance_km')
        fuel_price = request.data.get('fuel_price')

        if not vehicle_id or distance_km is None or fuel_price is None:
            return Response(
                {
                    'error': (
                        'vehicle_id, distance_km and '
                        'fuel_price are required'
                    )
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            vehicle = Vehicle.objects.get(
                id=vehicle_id,
                user=request.user,
            )
            distance_km = float(distance_km)
            fuel_price = float(fuel_price)
        except Vehicle.DoesNotExist:
            return Response(
                {'error': 'Vehicle not found or does not belong to you'},
                status=status.HTTP_404_NOT_FOUND,
            )
        except (TypeError, ValueError):
            return Response(
                {'error': 'distance_km and fuel_price must be valid numbers'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if distance_km < 0:
            return Response(
                {'error': 'Distance cannot be negative'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if fuel_price < 0:
            return Response(
                {'error': 'Fuel price cannot be negative'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if vehicle.fuel_average <= 0:
            return Response(
                {'error': 'Fuel average must be greater than zero'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        fuel_needed = distance_km / vehicle.fuel_average
        estimated_cost = fuel_needed * fuel_price

        return Response(
            {
                'vehicle_id': vehicle.id,
                'vehicle_name': vehicle.vehicle_name,
                'vehicle_type': vehicle.vehicle_type,
                'fuel_type': vehicle.fuel_type,
                'fuel_average': vehicle.fuel_average,
                'distance_km': round(distance_km, 2),
                'fuel_price': round(fuel_price, 2),
                'fuel_needed_liters': round(fuel_needed, 2),
                'estimated_cost': round(estimated_cost, 2),
            },
            status=status.HTTP_200_OK,
        )
