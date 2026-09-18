import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class RouteMapScreen extends StatelessWidget {
  final List<LatLng> routePoints;
  final LatLng startPoint;
  final LatLng destinationPoint;
  final String startLabel;
  final String destinationLabel;
  final String distance;
  final String travelTime;

  const RouteMapScreen({
    super.key,
    required this.routePoints,
    required this.startPoint,
    required this.destinationPoint,
    required this.startLabel,
    required this.destinationLabel,
    required this.distance,
    required this.travelTime,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        title: const Text('Your Route', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: startPoint,
              initialZoom: 12,
              onMapReady: () {},
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.routewise.routewise_mobile',
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: routePoints,
                    strokeWidth: 5,
                    color: const Color(0xFF2563EB),
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(point: startPoint, width: 50, height: 50, child: const Icon(Icons.location_on_rounded, size: 45, color: Color(0xFF059669))),
                  Marker(point: destinationPoint, width: 50, height: 50, child: const Icon(Icons.location_on_rounded, size: 45, color: Color(0xFFDC2626))),
                ],
              ),
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$distance • $travelTime', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                    const SizedBox(height: 8),
                    Text('From: $startLabel', maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('To: $destinationLabel', maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
