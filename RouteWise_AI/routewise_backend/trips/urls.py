from django.urls import path
from .views import (
    TripListCreateAPIView,
    TripDetailAPIView,
    FuelCalculationAPIView,
)

urlpatterns = [
    path(
        '',
        TripListCreateAPIView.as_view(),
        name='trip-list-create'
    ),

    path(
        'calculate-fuel/',
        FuelCalculationAPIView.as_view(),
        name='calculate-fuel'
    ),

    path(
        '<int:pk>/',
        TripDetailAPIView.as_view(),
        name='trip-detail'
    ),
]