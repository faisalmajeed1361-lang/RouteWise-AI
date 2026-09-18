import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AiAssistantScreen extends StatefulWidget {
  final String baseUrl;
  final String accessToken;

  const AiAssistantScreen({
    super.key,
    required this.baseUrl,
    required this.accessToken,
  });

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final distanceController = TextEditingController();
  final fuelPriceController = TextEditingController();
  List<dynamic> vehicles = [];
  int? selectedVehicleId;
  bool isVehiclesLoading = true;
  bool isLoadingAdvice = false;
  String errorMessage = '';
  Map<String, dynamic>? adviceData;

  @override
  void initState() {
    super.initState();
    loadVehicles();
  }

  Map<String, String> get headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer ${widget.accessToken}',
      };

  Future<void> loadVehicles() async {
    try {
      final response = await http
          .get(Uri.parse('${widget.baseUrl}/api/vehicles/'), headers: headers)
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        setState(() {
          vehicles = data;
          selectedVehicleId = data.isEmpty ? null : data.first['id'] as int;
          isVehiclesLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Could not load vehicles.';
          isVehiclesLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          errorMessage = 'Vehicle loading error: $error';
          isVehiclesLoading = false;
        });
      }
    }
  }

  Future<void> getAdvice() async {
    final distance = double.tryParse(distanceController.text.trim());
    final fuelPrice = double.tryParse(fuelPriceController.text.trim());
    if (selectedVehicleId == null || distance == null || distance <= 0 ||
        fuelPrice == null || fuelPrice <= 0) {
      setState(() {
        errorMessage = 'Select a vehicle and enter valid distance and fuel price.';
      });
      return;
    }

    setState(() {
      isLoadingAdvice = true;
      errorMessage = '';
      adviceData = null;
    });

    try {
      final response = await http
          .post(
            Uri.parse('${widget.baseUrl}/api/ai/advice/'),
            headers: headers,
            body: jsonEncode({
              'vehicle_id': selectedVehicleId,
              'distance_km': distance,
              'fuel_price': fuelPrice,
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        setState(() => adviceData = body as Map<String, dynamic>);
      } else {
        setState(() {
          errorMessage = body is Map && body['error'] != null
              ? body['error'].toString()
              : 'Could not get AI advice. Error: ${response.statusCode}';
        });
      }
    } catch (error) {
      if (mounted) setState(() => errorMessage = 'AI Assistant error: $error');
    } finally {
      if (mounted) setState(() => isLoadingAdvice = false);
    }
  }

  IconData adviceIcon(String name) {
    switch (name) {
      case 'speed': return Icons.speed_rounded;
      case 'tire': return Icons.tire_repair_rounded;
      case 'route': return Icons.route_rounded;
      case 'car': return Icons.car_repair_rounded;
      case 'money': return Icons.savings_rounded;
      case 'bike': return Icons.two_wheeler_rounded;
      default: return Icons.local_gas_station_rounded;
    }
  }

  @override
  void dispose() {
    distanceController.dispose();
    fuelPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        title: const Text('AI Assistant', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.auto_awesome_rounded, color: Color(0xFF2563EB), size: 38),
                  SizedBox(height: 10),
                  Text('Smart Trip Advice', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
                  SizedBox(height: 5),
                  Text('Get fuel-saving, safety and cost advice for your journey.'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<int>(
              initialValue: selectedVehicleId,
              decoration: const InputDecoration(labelText: 'Select Vehicle', border: OutlineInputBorder()),
              items: vehicles.map((vehicle) => DropdownMenuItem<int>(
                value: vehicle['id'] as int,
                child: Text(vehicle['vehicle_name'].toString()),
              )).toList(),
              onChanged: isVehiclesLoading ? null : (value) => setState(() => selectedVehicleId = value),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: distanceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Trip Distance (KM)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: fuelPriceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Fuel Price Per Liter', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: isLoadingAdvice ? null : getAdvice,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                icon: isLoadingAdvice
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.auto_awesome_rounded),
                label: Text(isLoadingAdvice ? 'Thinking...' : 'Get Smart Advice', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            if (errorMessage.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(errorMessage, style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
            ],
            if (adviceData != null) ...[
              const SizedBox(height: 22),
              _summaryCard(),
              const SizedBox(height: 14),
              const Text('AI Recommendations', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ...((adviceData!['advice'] as List<dynamic>).map((item) => _adviceCard(Map<String, dynamic>.from(item as Map)))),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${adviceData!['vehicle_name']} • ${adviceData!['fuel_average']} KM/L', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        const SizedBox(height: 8),
        Text('Fuel needed: ${adviceData!['fuel_needed_liters']} Liters'),
        Text('Estimated cost: Rs ${adviceData!['estimated_cost']}', style: const TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold, fontSize: 17)),
      ]),
    );
  }

  Widget _adviceCard(Map<String, dynamic> item) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE2E8F0))),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: const Color(0xFFEFF6FF), child: Icon(adviceIcon(item['icon'].toString()), color: const Color(0xFF2563EB))),
        title: Text(item['title'].toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Padding(padding: const EdgeInsets.only(top: 5), child: Text(item['message'].toString())),
      ),
    );
  }
}