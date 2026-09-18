from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.authentication import JWTAuthentication

from vehicles.models import Vehicle


class SmartAdviceAPIView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        vehicle_id = request.data.get('vehicle_id')
        distance_km = request.data.get('distance_km')
        fuel_price = request.data.get('fuel_price')

        if vehicle_id is None or distance_km is None or fuel_price is None:
            return Response(
                {
                    'error': (
                        'vehicle_id, distance_km and fuel_price are required'
                    ),
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
                {'error': 'Vehicle not found'},
                status=status.HTTP_404_NOT_FOUND,
            )
        except (TypeError, ValueError):
            return Response(
                {'error': 'Distance and fuel price must be valid numbers'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if distance_km <= 0 or fuel_price <= 0:
            return Response(
                {'error': 'Distance and fuel price must be greater than zero'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if vehicle.fuel_average <= 0:
            return Response(
                {'error': 'Vehicle fuel average must be greater than zero'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        fuel_needed = distance_km / vehicle.fuel_average
        estimated_cost = fuel_needed * fuel_price
        advice = self._build_advice(
            vehicle=vehicle,
            distance_km=distance_km,
            fuel_needed=fuel_needed,
            estimated_cost=estimated_cost,
        )

        return Response(
            {
                'vehicle_name': vehicle.vehicle_name,
                'vehicle_type': vehicle.vehicle_type,
                'fuel_average': round(vehicle.fuel_average, 2),
                'distance_km': round(distance_km, 2),
                'fuel_needed_liters': round(fuel_needed, 2),
                'estimated_cost': round(estimated_cost, 2),
                'advice': advice,
            },
            status=status.HTTP_200_OK,
        )

    def _build_advice(
        self,
        vehicle,
        distance_km,
        fuel_needed,
        estimated_cost,
    ):
        advice = [
            {
                'title': 'Drive Smoothly',
                'message': (
                    'Avoid sudden acceleration and hard braking to reduce '
                    'fuel use.'
                ),
                'icon': 'speed',
            },
            {
                'title': 'Check Tyre Pressure',
                'message': (
                    'Correct tyre pressure can improve fuel efficiency and '
                    'make your journey safer.'
                ),
                'icon': 'tire',
            },
        ]

        if distance_km >= 100:
            advice.insert(
                0,
                {
                    'title': 'Long Trip Alert',
                    'message': (
                        f'Your trip is {distance_km:.0f} KM. Check fuel, '
                        'tyres and engine oil before leaving.'
                    ),
                    'icon': 'route',
                },
            )

        if vehicle.fuel_average < 15:
            advice.append(
                {
                    'title': 'Fuel Efficiency Tip',
                    'message': (
                        f'{vehicle.vehicle_name} has {vehicle.fuel_average:.1f} '
                        'KM/L average. Regular servicing may improve it.'
                    ),
                    'icon': 'car',
                },
            )

        if estimated_cost >= 3000:
            advice.append(
                {
                    'title': 'High Cost Trip',
                    'message': (
                        f'This trip may cost Rs {estimated_cost:.0f}. Compare '
                        'routes and travel at non-peak hours if possible.'
                    ),
                    'icon': 'money',
                },
            )

        if vehicle.vehicle_type == 'bike':
            advice.append(
                {
                    'title': 'Bike Safety',
                    'message': (
                        'Wear a helmet and avoid long-distance travel during '
                        'heavy rain or extreme heat.'
                    ),
                    'icon': 'bike',
                },
            )

        advice.append(
            {
                'title': 'Fuel Plan',
                'message': (
                    f'Keep at least {fuel_needed:.1f} liters available for '
                    'this journey, plus a small safety reserve.'
                ),
                'icon': 'fuel',
            },
        )

        return advice
