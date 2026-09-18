import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class MyVehiclesScreen extends StatefulWidget {
  final String baseUrl;
  final String accessToken;

  const MyVehiclesScreen({
    super.key,
    required this.baseUrl,
    required this.accessToken,
  });

  @override
  State<MyVehiclesScreen> createState() => _MyVehiclesScreenState();
}

class _MyVehiclesScreenState extends State<MyVehiclesScreen> {
  bool isLoading = true;
  bool isUpdating = false;
  String errorMessage = '';
  List<dynamic> vehicles = [];

  Map<String, String> get headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer ${widget.accessToken}',
      };

  @override
  void initState() {
    super.initState();
    loadVehicles();
  }

  Future<void> loadVehicles() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final response = await http
          .get(Uri.parse('${widget.baseUrl}/api/vehicles/'), headers: headers)
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          vehicles = jsonDecode(response.body) as List<dynamic>;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = response.statusCode == 401
              ? 'Your login session has expired. Please login again.'
              : 'Could not load vehicles. Error: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Vehicle loading error:\n$error';
        isLoading = false;
      });
    }
  }

  Future<void> deleteVehicle(Map<String, dynamic> vehicle) async {
    final name = vehicle['vehicle_name'].toString();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Vehicle?'),
        content: Text('Do you want to delete "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    setState(() => isUpdating = true);
    try {
      final response = await http
          .delete(
            Uri.parse('${widget.baseUrl}/api/vehicles/${vehicle['id']}/'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (response.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name deleted successfully.')),
        );
        await loadVehicles();
      } else {
        setState(() {
          errorMessage = 'Could not delete vehicle. Error: ${response.statusCode}';
        });
      }
    } catch (error) {
      if (mounted) setState(() => errorMessage = 'Delete error:\n$error');
    } finally {
      if (mounted) setState(() => isUpdating = false);
    }
  }

  Future<void> editVehicle(Map<String, dynamic> vehicle) async {
    final nameController = TextEditingController(
      text: vehicle['vehicle_name'].toString(),
    );
    final averageController = TextEditingController(
      text: (vehicle['fuel_average'] as num).toString(),
    );
    String type = vehicle['vehicle_type'].toString();
    String fuelType = vehicle['fuel_type'].toString();
    String? dialogError;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Vehicle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Vehicle Name'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Vehicle Type'),
                  items: const [
                    DropdownMenuItem(value: 'car', child: Text('Car')),
                    DropdownMenuItem(value: 'bike', child: Text('Bike')),
                    DropdownMenuItem(value: 'van', child: Text('Van')),
                    DropdownMenuItem(value: 'bus', child: Text('Bus')),
                  ],
                  onChanged: (value) => setDialogState(() => type = value!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: fuelType,
                  decoration: const InputDecoration(labelText: 'Fuel Type'),
                  items: const [
                    DropdownMenuItem(value: 'petrol', child: Text('Petrol')),
                    DropdownMenuItem(value: 'diesel', child: Text('Diesel')),
                    DropdownMenuItem(value: 'electric', child: Text('Electric')),
                  ],
                  onChanged: (value) => setDialogState(() => fuelType = value!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: averageController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Fuel Average (KM/L)'),
                ),
                if (dialogError != null) ...[
                  const SizedBox(height: 10),
                  Text(dialogError!, style: const TextStyle(color: Color(0xFFDC2626))),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final average = double.tryParse(averageController.text.trim());
                if (nameController.text.trim().isEmpty ||
                    average == null ||
                    average <= 0) {
                  setDialogState(() {
                    dialogError = 'Enter a valid name and fuel average.';
                  });
                  return;
                }
                final response = await http.put(
                  Uri.parse('${widget.baseUrl}/api/vehicles/${vehicle['id']}/'),
                  headers: headers,
                  body: jsonEncode({
                    'vehicle_name': nameController.text.trim(),
                    'vehicle_type': type,
                    'fuel_type': fuelType,
                    'fuel_average': average,
                  }),
                );
                if (!dialogContext.mounted) return;
                if (response.statusCode == 200) {
                  Navigator.pop(dialogContext, true);
                } else {
                  setDialogState(() {
                    dialogError = 'Could not update. Error: ${response.statusCode}';
                  });
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
    averageController.dispose();
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vehicle updated successfully.')),
      );
      await loadVehicles();
    }
  }

  IconData vehicleIcon(String type) {
    switch (type.toLowerCase()) {
      case 'bike': return Icons.two_wheeler_rounded;
      case 'bus': return Icons.directions_bus_rounded;
      case 'van': return Icons.airport_shuttle_rounded;
      default: return Icons.directions_car_rounded;
    }
  }

  String titleCase(String value) => value.isEmpty
      ? value
      : '${value[0].toUpperCase()}${value.substring(1)}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        title: const Text('My Vehicles', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [IconButton(onPressed: loadVehicles, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(errorMessage, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFE11D48), fontWeight: FontWeight.bold))))
              : vehicles.isEmpty
                  ? const Center(child: Text('No vehicles added yet.', style: TextStyle(fontSize: 18)))
                  : RefreshIndicator(
                      onRefresh: loadVehicles,
                      child: Stack(
                        children: [
                          ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: vehicles.length,
                            itemBuilder: (context, index) {
                              final vehicle = vehicles[index] as Map<String, dynamic>;
                              final type = vehicle['vehicle_type'].toString();
                              final fuelType = vehicle['fuel_type'].toString();
                              final average = (vehicle['fuel_average'] as num).toDouble();
                              return Card(
                                margin: const EdgeInsets.only(bottom: 14),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFFE2E8F0))),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(children: [
                                    Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(14)), child: Icon(vehicleIcon(type), color: const Color(0xFF2563EB), size: 30)),
                                    const SizedBox(width: 14),
                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(vehicle['vehicle_name'].toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 5),
                                      Text('${titleCase(type)} • ${titleCase(fuelType)}', style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                                    ])),
                                    Text('${average.toStringAsFixed(1)}\nKM/L', textAlign: TextAlign.right, style: const TextStyle(color: Color(0xFF059669), fontSize: 16, fontWeight: FontWeight.bold)),
                                    PopupMenuButton<String>(
                                      onSelected: (action) => action == 'edit' ? editVehicle(vehicle) : deleteVehicle(vehicle),
                                      itemBuilder: (_) => const [
                                        PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_rounded), title: Text('Edit'))),
                                        PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)), title: Text('Delete', style: TextStyle(color: Color(0xFFDC2626))))),
                                      ],
                                    ),
                                  ]),
                                ),
                              );
                            },
                          ),
                          if (isUpdating) const ColoredBox(color: Color(0x22000000), child: Center(child: CircularProgressIndicator())),
                        ],
                      ),
                    ),
    );
  }
}
