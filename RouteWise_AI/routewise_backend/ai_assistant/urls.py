from django.urls import path

from .views import SmartAdviceAPIView


urlpatterns = [
    path('advice/', SmartAdviceAPIView.as_view(), name='smart-advice'),
]
