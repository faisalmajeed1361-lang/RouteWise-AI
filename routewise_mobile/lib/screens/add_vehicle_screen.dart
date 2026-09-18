import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AddVehicleScreen extends StatefulWidget {
  final String baseUrl;
  final String accessToken;

  const AddVehicleScreen({
    super.key,
    required this.baseUrl,
    required this.accessToken,
  });

  @override
  State<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  final vehicleNameController = TextEditingController();
  final fuelAverageController = TextEditingController();

  String vehicleType = 'car';
  String fuelType = 'petrol';
  bool isSaving = false;
  String errorMessage = '';

  Future<void> saveVehicle() async {
    final vehicleName = vehicleNameController.text.trim();
    final fuelAverage = double.tryParse(fuelAverageController.text.trim());

    if (vehicleName.isEmpty) {
      setState(() => errorMessage = 'Please enter vehicle name.');
      return;
    }

    if (fuelAverage == null || fuelAverage <= 0) {
      setState(() => errorMessage = 'Please enter a valid fuel average.');
      return;
    }

    setState(() {
      isSaving = true;
      errorMessage = '';
    });

    try {
      final response = await http
          .post(
            Uri.parse('${widget.baseUrl}/api/vehicles/'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${widget.accessToken}',
            },
            body: jsonEncode({
              'vehicle_name': vehicleName,
              'vehicle_type': vehicleType,
              'fuel_type': fuelType,
              'fuel_average': fuelAverage,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 201) {
        Navigator.pop(context, true);
      } else {
        setState(() {
          errorMessage = 'Could not save vehicle. Error: ${response.statusCode}';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => errorMessage = 'Vehicle save error:\n$e');
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  void dispose() {
    vehicleNameController.dispose();
    fuelAverageController.dispose();
    super.dispose();
  }

  InputDecoration decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF2563EB)),
      filled: true,
      fillColor: const Color(0xFFF7F9FC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFFE4E9F2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        title: const Text('Add Vehicle', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
          child: Column(
            children: [
              const Icon(Icons.directions_car_filled_rounded, color: Color(0xFF2563EB), size: 60),
              const SizedBox(height: 12),
              const Text('Add Your Vehicle', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              TextField(
                controller: vehicleNameController,
                decoration: decoration('Vehicle Name', Icons.drive_eta_rounded),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: vehicleType,
                decoration: decoration('Vehicle Type', Icons.category_rounded),
                items: const [
                  DropdownMenuItem(value: 'car', child: Text('Car')),
                  DropdownMenuItem(value: 'bike', child: Text('Bike')),
                  DropdownMenuItem(value: 'van', child: Text('Van')),
                  DropdownMenuItem(value: 'bus', child: Text('Bus')),
                ],
                onChanged: (value) => setState(() => vehicleType = value!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: fuelType,
                decoration: decoration('Fuel Type', Icons.local_gas_station_rounded),
                items: const [
                  DropdownMenuItem(value: 'petrol', child: Text('Petrol')),
                  DropdownMenuItem(value: 'diesel', child: Text('Diesel')),
                  DropdownMenuItem(value: 'electric', child: Text('Electric')),
                ],
                onChanged: (value) => setState(() => fuelType = value!),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: fuelAverageController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: decoration('Fuel Average (KM/L)', Icons.speed_rounded),
              ),
              if (errorMessage.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(errorMessage, style: const TextStyle(color: Color(0xFFE11D48), fontWeight: FontWeight.bold)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: isSaving ? null : saveVehicle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: isSaving
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.add_rounded),
                  label: Text(isSaving ? 'Saving...' : 'Add Vehicle', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
