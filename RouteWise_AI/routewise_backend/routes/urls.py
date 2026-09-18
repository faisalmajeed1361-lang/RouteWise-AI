from django.urls import path

from .views import RouteEstimateAPIView


urlpatterns = [
    path(
        'estimate/',
        RouteEstimateAPIView.as_view(),
        name='route-estimate',
    ),
]
