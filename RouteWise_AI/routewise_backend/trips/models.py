from django.db import models
from django.contrib.auth.models import User
from vehicles.models import Vehicle

class Trip(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    vehicle = models.ForeignKey(Vehicle, on_delete=models.CASCADE)

    start_location = models.CharField(max_length=255)
    destination = models.CharField(max_length=255)

    distance_km = models.FloatField()
    fuel_price = models.FloatField()
    fuel_needed = models.FloatField(blank=True, null=True)
    estimated_cost = models.FloatField(blank=True, null=True)

    travel_time = models.CharField(max_length=100, blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def save(self, *args, **kwargs):
        if self.vehicle.fuel_average > 0:
            self.fuel_needed = self.distance_km / self.vehicle.fuel_average
            self.estimated_cost = self.fuel_needed * self.fuel_price
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.start_location} to {self.destination}"