from django.urls import path

from .views import (
    VehicleListCreateAPIView,
    VehicleDetailAPIView,
)

urlpatterns = [
    path(
        '',
        VehicleListCreateAPIView.as_view(),
        name='vehicle-list-create',
    ),
    path(
        '<int:pk>/',
        VehicleDetailAPIView.as_view(),
        name='vehicle-detail',
    ),
]