import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class TripHistoryScreen extends StatefulWidget {
  final String baseUrl;
  final String accessToken;

  const TripHistoryScreen({
    super.key,
    required this.baseUrl,
    required this.accessToken,
  });

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  bool isLoading = true;
  bool isDeleting = false;
  String errorMessage = '';
  List<dynamic> trips = [];

  Map<String, String> get headers => {
        'Accept': 'application/json',
        'Authorization': 'Bearer ${widget.accessToken}',
      };

  @override
  void initState() {
    super.initState();
    loadTrips();
  }

  Future<void> loadTrips() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });
    try {
      final response = await http
          .get(Uri.parse('${widget.baseUrl}/api/trips/'), headers: headers)
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          trips = jsonDecode(response.body) as List<dynamic>;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = response.statusCode == 401
              ? 'Your login session has expired. Please login again.'
              : 'Could not load Trip History. Error: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          errorMessage = 'Trip History error:\n$error';
          isLoading = false;
        });
      }
    }
  }

  Future<void> deleteTrip(Map<String, dynamic> trip) async {
    final route = '${trip['start_location']} → ${trip['destination']}';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Trip?'),
        content: Text('Do you want to delete this trip?\n$route'),
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

    setState(() => isDeleting = true);
    try {
      final response = await http
          .delete(
            Uri.parse('${widget.baseUrl}/api/trips/${trip['id']}/'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (response.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip deleted successfully.')),
        );
        await loadTrips();
      } else {
        setState(() {
          errorMessage = 'Could not delete trip. Error: ${response.statusCode}';
        });
      }
    } catch (error) {
      if (mounted) setState(() => errorMessage = 'Delete error:\n$error');
    } finally {
      if (mounted) setState(() => isDeleting = false);
    }
  }

  String money(dynamic value) {
    final amount = (value as num?)?.toDouble() ?? 0;
    return 'Rs ${amount.toStringAsFixed(2)}';
  }

  String liters(dynamic value) {
    final amount = (value as num?)?.toDouble() ?? 0;
    return '${amount.toStringAsFixed(2)} L';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        title: const Text('Trip History', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [IconButton(onPressed: loadTrips, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(errorMessage, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFE11D48), fontWeight: FontWeight.bold))))
              : trips.isEmpty
                  ? const Center(child: Text('No trips saved yet.', style: TextStyle(fontSize: 18)))
                  : RefreshIndicator(
                      onRefresh: loadTrips,
                      child: Stack(
                        children: [
                          ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: trips.length,
                            itemBuilder: (context, index) {
                              final trip = trips[index] as Map<String, dynamic>;
                              return Card(
                                elevation: 0,
                                margin: const EdgeInsets.only(bottom: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFFE2E8F0))),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Row(children: [
                                      const Icon(Icons.route_rounded, color: Color(0xFF2563EB)),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text('${trip['start_location']} → ${trip['destination']}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
                                      IconButton(
                                        tooltip: 'Delete Trip',
                                        onPressed: () => deleteTrip(trip),
                                        icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
                                      ),
                                    ]),
                                    const SizedBox(height: 14),
                                    Row(children: [
                                      _info(Icons.straighten_rounded, '${trip['distance_km']} KM'),
                                      const SizedBox(width: 18),
                                      _info(Icons.local_gas_station_rounded, liters(trip['fuel_needed'])),
                                      const Spacer(),
                                      Text(money(trip['estimated_cost']), style: const TextStyle(color: Color(0xFF059669), fontSize: 17, fontWeight: FontWeight.bold)),
                                    ]),
                                  ]),
                                ),
                              );
                            },
                          ),
                          if (isDeleting) const ColoredBox(color: Color(0x22000000), child: Center(child: CircularProgressIndicator())),
                        ],
                      ),
                    ),
    );
  }

  Widget _info(IconData icon, String text) => Row(children: [
    Icon(icon, size: 18, color: const Color(0xFF64748B)),
    const SizedBox(width: 5),
    Text(text, style: const TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w600)),
  ]);
}
