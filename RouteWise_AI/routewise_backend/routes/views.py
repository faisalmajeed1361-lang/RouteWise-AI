import requests

from django.conf import settings
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.authentication import JWTAuthentication


ORS_BASE_URL = 'https://api.openrouteservice.org'


class RouteEstimateAPIView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        start_location = str(request.data.get('start_location', '')).strip()
        destination = str(request.data.get('destination', '')).strip()
        vehicle_type = str(request.data.get('vehicle_type', 'car')).lower()
        start_lat = request.data.get('start_lat')
        start_lng = request.data.get('start_lng')
        has_current_coordinates = start_lat is not None and start_lng is not None

        if not destination or (not start_location and not has_current_coordinates):
            return Response(
                {'error': 'A start location and destination are required'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if not settings.ORS_API_KEY:
            return Response({'error': 'Route service API key is not configured'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

        try:
            if has_current_coordinates:
                latitude = float(start_lat)
                longitude = float(start_lng)
                if not (-90 <= latitude <= 90 and -180 <= longitude <= 180):
                    raise ValueError
                start = {
                    'coordinates': [longitude, latitude],
                    'label': start_location or 'Current Location',
                }
            else:
                start = self._geocode(start_location)

            end = self._geocode(destination)
            profile = 'cycling-regular' if vehicle_type == 'bike' else 'driving-car'
            route_data = self._get_directions(start['coordinates'], end['coordinates'], profile)
            route = route_data['routes'][0]
            summary = route['summary']

            return Response({
                'start_location': start['label'],
                'destination': end['label'],
                'start_coordinates': start['coordinates'],
                'destination_coordinates': end['coordinates'],
                'route_coordinates': self._decode_polyline(route['geometry']),
                'distance_km': round(summary['distance'] / 1000, 2),
                'duration_minutes': round(summary['duration'] / 60),
                'travel_time': self._format_duration(round(summary['duration'] / 60)),
                'routing_profile': profile,
            }, status=status.HTTP_200_OK)
        except requests.RequestException as error:
            return Response({'error': 'Could not connect to the route service', 'details': str(error)}, status=status.HTTP_503_SERVICE_UNAVAILABLE)
        except (ValueError, OverflowError):
            return Response(
                {'error': 'Current location coordinates are invalid'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        except (KeyError, IndexError, TypeError):
            return Response({'error': 'Could not find a route for these locations'}, status=status.HTTP_404_NOT_FOUND)

    def _headers(self):
        return {'Authorization': settings.ORS_API_KEY, 'Content-Type': 'application/json', 'Accept': 'application/json'}

    def _geocode(self, location):
        response = requests.get(f'{ORS_BASE_URL}/geocode/search', headers=self._headers(), params={'text': location, 'size': 1}, timeout=15)
        response.raise_for_status()
        feature = response.json()['features'][0]
        return {'coordinates': feature['geometry']['coordinates'], 'label': feature['properties'].get('label', location)}

    def _get_directions(self, start_coordinates, end_coordinates, profile):
        response = requests.post(
            f'{ORS_BASE_URL}/v2/directions/{profile}/json',
            headers=self._headers(),
            json={
                'coordinates': [start_coordinates, end_coordinates],
            },
            timeout=20,
        )
        response.raise_for_status()
        return response.json()

    def _format_duration(self, total_minutes):
        hours, minutes = divmod(total_minutes, 60)
        return f'{hours} hr {minutes} min' if hours else f'{minutes} min'

    def _decode_polyline(self, encoded_polyline):
        """Convert the OpenRouteService encoded route line to [longitude, latitude]."""
        coordinates = []
        index = 0
        latitude = 0
        longitude = 0

        while index < len(encoded_polyline):
            result = 0
            shift = 0
            while True:
                byte = ord(encoded_polyline[index]) - 63
                index += 1
                result |= (byte & 0x1F) << shift
                shift += 5
                if byte < 0x20:
                    break
            latitude += ~(result >> 1) if result & 1 else result >> 1

            result = 0
            shift = 0
            while True:
                byte = ord(encoded_polyline[index]) - 63
                index += 1
                result |= (byte & 0x1F) << shift
                shift += 5
                if byte < 0x20:
                    break
            longitude += ~(result >> 1) if result & 1 else result >> 1

            coordinates.append([
                round(longitude / 100000, 6),
                round(latitude / 100000, 6),
            ])

        return coordinates
