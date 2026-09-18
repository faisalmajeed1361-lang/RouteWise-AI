import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/trip_history_screen.dart';
import 'screens/add_vehicle_screen.dart';
import 'screens/my_vehicles_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/route_map_screen.dart';
import 'screens/ai_assistant_screen.dart';

const String appBaseUrl = 'http://192.168.1.40:8000';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RouteWiseApp());
}

class RouteWiseApp extends StatefulWidget {
  const RouteWiseApp({super.key});

  @override
  State<RouteWiseApp> createState() => _RouteWiseAppState();
}

class _RouteWiseAppState extends State<RouteWiseApp> {
  bool isSessionLoading = true;
  int? userId;
  String? username;
  String? accessToken;

  @override
  void initState() {
    super.initState();
    loadSavedSession();
  }

  Future<void> loadSavedSession() async {
    final preferences = await SharedPreferences.getInstance();
    final savedUserId = preferences.getInt('user_id');
    final savedUsername = preferences.getString('username');
    final savedToken = preferences.getString('access_token');

    if (!mounted) return;
    setState(() {
      userId = savedUserId;
      username = savedUsername;
      accessToken = savedToken;
      isSessionLoading = false;
    });
  }

  Future<void> saveSession({
    required int newUserId,
    required String newUsername,
    required String newToken,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt('user_id', newUserId);
    await preferences.setString('username', newUsername);
    await preferences.setString('access_token', newToken);

    if (!mounted) return;
    setState(() {
      userId = newUserId;
      username = newUsername;
      accessToken = newToken;
    });
  }

  Future<void> logout() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('user_id');
    await preferences.remove('username');
    await preferences.remove('access_token');

    if (!mounted) return;
    setState(() {
      userId = null;
      username = null;
      accessToken = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RouteWise AI',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
      ),
      home: isSessionLoading
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            )
          : accessToken != null && userId != null && username != null
              ? HomeScreen(
                  userId: userId!,
                  username: username!,
                  accessToken: accessToken!,
                  onLogout: logout,
                )
              : AuthScreen(
                  baseUrl: appBaseUrl,
                  onAuthenticated: ({
                    required int userId,
                    required String username,
                    required String token,
                  }) => saveSession(
                    newUserId: userId,
                    newUsername: username,
                    newToken: token,
                  ),
                ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final int userId;
  final String username;
  final String accessToken;
  final Future<void> Function() onLogout;

  const HomeScreen({
    super.key,
    required this.userId,
    required this.username,
    required this.accessToken,
    required this.onLogout,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Phone testing ke waqt laptop ka current Wi-Fi IPv4 yahan update karna.
  static const String baseUrl = appBaseUrl;

  final startController = TextEditingController();
  final destinationController = TextEditingController();
  final distanceController = TextEditingController();
  final fuelPriceController = TextEditingController();

  List<Map<String, dynamic>> vehicles = [];
  int? selectedVehicleId;

  bool isVehiclesLoading = true;
  bool isLoading = false;
  bool isLocationLoading = false;
  bool isRouteLoading = false;
  bool isSavingTrip = false;
  String successMessage = '';

  String errorMessage = '';
  String? vehicleName;
  String? vehicleType;
  String? fuelType;
  double? fuelAverage;
  double? fuelNeeded;
  double? estimatedCost;
  String? routeTravelTime;
  List<LatLng> routePoints = [];
  LatLng? routeStartPoint;
  LatLng? routeDestinationPoint;
  String routeStartLabel = '';
  String routeDestinationLabel = '';
  double? currentLatitude;
  double? currentLongitude;

  @override
  void initState() {
    super.initState();
    loadVehicles();
  }

  Future<void> loadVehicles() async {
    setState(() {
      isVehiclesLoading = true;
      errorMessage = '';
    });

    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/vehicles/'),
            headers: {
              'Authorization': 'Bearer ${widget.accessToken}',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        setState(() {
          vehicles = data
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();

          if (vehicles.isNotEmpty) {
            selectedVehicleId = vehicles.first['id'] as int;
          }

          isVehiclesLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Could not load vehicles from server.';
          isVehiclesLoading = false;
        });
      }
    } catch (e) {
  if (!mounted) return;

  setState(() {
    errorMessage = 'Vehicle loading error:\n$e';
    isVehiclesLoading = false;
  });
}
  }

  Future<void> calculateFuel() async {
    FocusScope.of(context).unfocus();

    final distance = double.tryParse(distanceController.text.trim());
    final fuelPrice = double.tryParse(fuelPriceController.text.trim());

    if (selectedVehicleId == null) {
      setState(() => errorMessage = 'Please select a vehicle.');
      return;
    }

    if (distance == null || distance <= 0) {
      setState(() => errorMessage = 'Please enter a valid distance in KM.');
      return;
    }

    if (fuelPrice == null || fuelPrice <= 0) {
      setState(() => errorMessage = 'Please enter a valid fuel price.');
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = '';
      fuelNeeded = null;
      estimatedCost = null;
    });

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/trips/calculate-fuel/'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${widget.accessToken}',
            },
            body: jsonEncode({
              'vehicle_id': selectedVehicleId,
              'distance_km': distance,
              'fuel_price': fuelPrice,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      final decodedBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final data = decodedBody as Map<String, dynamic>;

        setState(() {
          vehicleName = data['vehicle_name']?.toString();
          vehicleType = data['vehicle_type']?.toString();
          fuelType = data['fuel_type']?.toString();
          fuelAverage = (data['fuel_average'] as num?)?.toDouble();
          fuelNeeded = (data['fuel_needed_liters'] as num?)?.toDouble();
          estimatedCost = (data['estimated_cost'] as num?)?.toDouble();
        });
      } else {
        setState(() {
          errorMessage = decodedBody is Map && decodedBody['error'] != null
              ? decodedBody['error'].toString()
              : 'Server error: ${response.statusCode}';
        });
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        errorMessage =
            'Cannot connect to Django server. Check server, Wi-Fi and IP.';
      });
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  String selectedVehicleType() {
    for (final vehicle in vehicles) {
      if (vehicle['id'] == selectedVehicleId) {
        return vehicle['vehicle_type']?.toString() ?? 'car';
      }
    }
    return 'car';
  }

  Future<void> getRealRoute() async {
    FocusScope.of(context).unfocus();

    final startLocation = startController.text.trim();
    final destination = destinationController.text.trim();

    if (startLocation.isEmpty || destination.isEmpty) {
      setState(() {
        errorMessage = 'Please enter start location and destination.';
      });
      return;
    }

    if (selectedVehicleId == null) {
      setState(() => errorMessage = 'Please select a vehicle first.');
      return;
    }

    setState(() {
      isRouteLoading = true;
      errorMessage = '';
      successMessage = '';
    });

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/routes/estimate/'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${widget.accessToken}',
            },
            body: jsonEncode({
              'start_location': startLocation,
              'destination': destination,
              'vehicle_type': selectedVehicleType(),
              if (currentLatitude != null) 'start_lat': currentLatitude,
              if (currentLongitude != null) 'start_lng': currentLongitude,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (!mounted) return;

      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final data = body as Map<String, dynamic>;
        final distance = (data['distance_km'] as num).toDouble();
        final rawRoute = data['route_coordinates'] as List<dynamic>;
        final rawStart = data['start_coordinates'] as List<dynamic>;
        final rawDestination =
            data['destination_coordinates'] as List<dynamic>;
        final points = rawRoute.map((point) {
          final coordinates = point as List<dynamic>;
          return LatLng(
            (coordinates[1] as num).toDouble(),
            (coordinates[0] as num).toDouble(),
          );
        }).toList();

        setState(() {
          distanceController.text = distance.toStringAsFixed(2);
          routeTravelTime = data['travel_time']?.toString();
          routePoints = points;
          routeStartPoint = LatLng(
            (rawStart[1] as num).toDouble(),
            (rawStart[0] as num).toDouble(),
          );
          routeDestinationPoint = LatLng(
            (rawDestination[1] as num).toDouble(),
            (rawDestination[0] as num).toDouble(),
          );
          routeStartLabel = data['start_location'].toString();
          routeDestinationLabel = data['destination'].toString();
          fuelNeeded = null;
          estimatedCost = null;
          successMessage =
              'Real route found: ${distance.toStringAsFixed(2)} KM • '
              '${routeTravelTime ?? ''}';
        });
      } else {
        setState(() {
          if (body is Map && body['error'] != null) {
            final details = body['details']?.toString();
            errorMessage = details != null && details.isNotEmpty
                ? '${body['error']}\n$details'
                : body['error'].toString();
          } else {
            errorMessage =
                'Could not find a route. Error: ${response.statusCode}';
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Route loading error:\n$e';
      });
    } finally {
      if (mounted) setState(() => isRouteLoading = false);
    }
  }

  Future<void> saveTrip() async {
  final startLocation = startController.text.trim();
  final destination = destinationController.text.trim();
  final distance = double.tryParse(distanceController.text.trim());
  final fuelPrice = double.tryParse(fuelPriceController.text.trim());

  if (startLocation.isEmpty || destination.isEmpty) {
    setState(() {
      errorMessage = 'Please enter start location and destination.';
    });
    return;
  }

  if (selectedVehicleId == null ||
      distance == null ||
      fuelPrice == null ||
      fuelNeeded == null ||
      estimatedCost == null) {
    setState(() {
      errorMessage = 'Calculate the trip before saving it.';
    });
    return;
  }

  setState(() {
    isSavingTrip = true;
    errorMessage = '';
    successMessage = '';
  });

  try {
    final response = await http
        .post(
          Uri.parse('$baseUrl/api/trips/'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${widget.accessToken}',
          },
          body: jsonEncode({
            'user': widget.userId,
            'vehicle': selectedVehicleId,
            'start_location': startLocation,
            'destination': destination,
            'distance_km': distance,
            'fuel_price': fuelPrice,
            'travel_time': routeTravelTime ?? 'Not calculated yet',
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (!mounted) return;

    if (response.statusCode == 201) {
      setState(() {
        successMessage = 'Trip saved successfully in your Trip History.';
      });
    } else {
      final body = jsonDecode(response.body);

      setState(() {
        errorMessage = body is Map
            ? body.toString()
            : 'Could not save trip. Error: ${response.statusCode}';
      });
    }
  } catch (e) {
    if (!mounted) return;

    setState(() {
      errorMessage = 'Could not save trip:\n$e';
    });
  } finally {
    if (mounted) {
      setState(() {
        isSavingTrip = false;
      });
    }
  }
}

  @override
  void dispose() {
    startController.dispose();
    destinationController.dispose();
    distanceController.dispose();
    fuelPriceController.dispose();
    super.dispose();
  }

  Future<void> useCurrentLocation() async {
    FocusScope.of(context).unfocus();
    setState(() {
      isLocationLoading = true;
      errorMessage = '';
      successMessage = '';
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Please turn on Location/GPS on your phone.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        throw Exception('Location permission was denied.');
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission is permanently denied. Open app settings and allow Location.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );

      if (!mounted) return;
      setState(() {
        currentLatitude = position.latitude;
        currentLongitude = position.longitude;
        startController.text = 'Current Location';
        routePoints = [];
        routeStartPoint = null;
        routeDestinationPoint = null;
        successMessage =
            'Current location found: '
            '${position.latitude.toStringAsFixed(5)}, '
            '${position.longitude.toStringAsFixed(5)}';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => isLocationLoading = false);
    }
  }

  Future<void> _handleAppBarAction(String action) async {
    if (action == 'vehicles') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MyVehiclesScreen(
            baseUrl: baseUrl,
            accessToken: widget.accessToken,
          ),
        ),
      );
      if (mounted) loadVehicles();
      return;
    }

    if (action == 'add_vehicle') {
      final vehicleAdded = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => AddVehicleScreen(
            baseUrl: baseUrl,
            accessToken: widget.accessToken,
          ),
        ),
      );
      if (vehicleAdded == true && mounted) loadVehicles();
      return;
    }

    if (action == 'history') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TripHistoryScreen(
            baseUrl: baseUrl,
            accessToken: widget.accessToken,
          ),
        ),
      );
      return;
    }

    if (action == 'refresh') {
      await loadVehicles();
      return;
    }

    if (action == 'logout') {
      final shouldLogout = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Logout?'),
          content: Text('Do you want to logout, ${widget.username}?'),
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
              child: const Text('Logout'),
            ),
          ],
        ),
      );

      if (shouldLogout == true && mounted) {
        await widget.onLogout();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        titleSpacing: 16,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.route_rounded, size: 27),
            SizedBox(width: 8),
            Text(
              'RouteWise AI',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'AI Assistant',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AiAssistantScreen(
                    baseUrl: baseUrl,
                    accessToken: widget.accessToken,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.auto_awesome_rounded),
          ),
          PopupMenuButton<String>(
            tooltip: 'Menu',
            onSelected: _handleAppBarAction,
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'vehicles',
                child: ListTile(
                  leading: Icon(Icons.directions_car_rounded),
                  title: Text('My Vehicles'),
                ),
              ),
              PopupMenuItem(
                value: 'add_vehicle',
                child: ListTile(
                  leading: Icon(Icons.add_circle_outline_rounded),
                  title: Text('Add Vehicle'),
                ),
              ),
              PopupMenuItem(
                value: 'history',
                child: ListTile(
                  leading: Icon(Icons.history_rounded),
                  title: Text('Trip History'),
                ),
              ),
              PopupMenuItem(
                value: 'refresh',
                child: ListTile(
                  leading: Icon(Icons.refresh_rounded),
                  title: Text('Refresh'),
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout_rounded, color: Color(0xFFDC2626)),
                  title: Text(
                    'Logout',
                    style: TextStyle(color: Color(0xFFDC2626)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _welcomeCard(),
              const SizedBox(height: 22),
              const Text(
                'Plan Your Journey',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF172033),
                ),
              ),
              const SizedBox(height: 14),
              _inputCard(),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton.icon(
                  onPressed: isRouteLoading ? null : getRealRoute,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    side: const BorderSide(
                      color: Color(0xFF2563EB),
                      width: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: isRouteLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.route_rounded),
                  label: Text(
                    isRouteLoading ? 'Finding Route...' : 'Get Real Route',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (routePoints.isNotEmpty &&
                  routeStartPoint != null &&
                  routeDestinationPoint != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RouteMapScreen(
                            routePoints: routePoints,
                            startPoint: routeStartPoint!,
                            destinationPoint: routeDestinationPoint!,
                            startLabel: routeStartLabel,
                            destinationLabel: routeDestinationLabel,
                            distance: '${distanceController.text} KM',
                            travelTime: routeTravelTime ?? '',
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.map_rounded),
                    label: const Text(
                      'View Route on Map',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: isLoading ? null : calculateFuel,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.auto_awesome_rounded),
                  label: Text(
                    isLoading ? 'Calculating...' : 'Calculate Smart Trip',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (errorMessage.isNotEmpty) ...[
                const SizedBox(height: 16),
                _errorCard(),
              ],

              if (successMessage.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF34D399)),
                  ),
                  child: Text(
                    successMessage,
                    style: const TextStyle(
                      color: Color(0xFF047857),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],

              if (fuelNeeded != null && estimatedCost != null) ...[
                const SizedBox(height: 22),
                _resultCard(),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton.icon(
                    onPressed: isSavingTrip ? null : saveTrip,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                      side: const BorderSide(
                        color: Color(0xFF2563EB),
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: isSavingTrip
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(
                      isSavingTrip ? 'Saving Trip...' : 'Save This Trip',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              const Text(
                'Quick Features',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF172033),
                ),
              ),
              const SizedBox(height: 14),
              _quickFeatures(),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _welcomeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF14B8A6)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Smart Journey Planner',
            style: TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Find smarter routes and estimate your fuel cost before travelling.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _field(
            startController,
            'Start Location',
            'Ali Town Lahore',
            Icons.my_location_rounded,
            onChanged: (_) {
              currentLatitude = null;
              currentLongitude = null;
            },
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isLocationLoading ? null : useCurrentLocation,
              icon: isLocationLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.gps_fixed_rounded),
              label: Text(
                isLocationLoading
                    ? 'Getting Current Location...'
                    : 'Use My Current Location',
              ),
            ),
          ),
          const SizedBox(height: 14),
          _field(
            destinationController,
            'Destination',
            'Data Darbar Lahore',
            Icons.location_on_rounded,
          ),
          const SizedBox(height: 14),
          _vehicleDropdown(),
          const SizedBox(height: 14),
          _field(
            distanceController,
            'Distance (KM)',
            '30',
            Icons.route_rounded,
            numeric: true,
          ),
          const SizedBox(height: 14),
          _field(
            fuelPriceController,
            'Fuel Price Per Liter',
            '300',
            Icons.local_gas_station_rounded,
            numeric: true,
          ),
        ],
      ),
    );
  }

  Widget _vehicleDropdown() {
    return DropdownButtonFormField<int>(
      initialValue: selectedVehicleId,
      isExpanded: true,
      decoration: _inputDecoration(
        isVehiclesLoading ? 'Loading vehicles...' : 'Select Vehicle',
        Icons.directions_car_rounded,
      ),
      hint: const Text('Choose your vehicle'),
      items: vehicles.map((vehicle) {
        final average = (vehicle['fuel_average'] as num).toDouble();

        return DropdownMenuItem<int>(
          value: vehicle['id'] as int,
          child: Text(
            '${vehicle['vehicle_name']} - ${average.toStringAsFixed(1)} KM/L',
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: isVehiclesLoading
          ? null
          : (value) => setState(() => selectedVehicleId = value),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String hint,
    IconData icon, {
    bool numeric = false,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: _inputDecoration(label, icon, hint),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, [String? hint]) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
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
        borderSide: const BorderSide(
          color: Color(0xFF2563EB),
          width: 2,
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      boxShadow: const [
        BoxShadow(
          color: Color(0x14000000),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
      ],
    );
  }

  Widget _resultCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEFFDF8),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF14B8A6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF059669)),
              SizedBox(width: 8),
              Text(
                'Trip Calculation Result',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF065F46),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _resultRow('Vehicle', vehicleName ?? '-'),
          _resultRow('Vehicle Type', vehicleType ?? '-'),
          _resultRow('Fuel Type', fuelType ?? '-'),
          _resultRow(
            'Fuel Average',
            '${fuelAverage?.toStringAsFixed(2) ?? '-'} KM/L',
          ),
          _resultRow(
            'Fuel Needed',
            '${fuelNeeded?.toStringAsFixed(2) ?? '-'} Liters',
          ),
          if (routeTravelTime != null)
            _resultRow('Travel Time', routeTravelTime!),
          const Divider(height: 28),
          _resultRow(
            'Estimated Cost',
            'Rs ${estimatedCost?.toStringAsFixed(2) ?? '-'}',
            highlight: true,
          ),
        ],
      ),
    );
  }

  Widget _resultRow(String title, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: highlight ? 17 : 15,
              fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
              color: const Color(0xFF475569),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: highlight ? 19 : 15,
                fontWeight: FontWeight.bold,
                color: highlight
                    ? const Color(0xFF059669)
                    : const Color(0xFF172033),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDA4AF)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFE11D48)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              errorMessage,
              style: const TextStyle(
                color: Color(0xFFBE123C),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickFeatures() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      childAspectRatio: 1.05,
      children: const [
        FeatureCard(
          icon: Icons.map_rounded,
          title: 'Smart Route',
          subtitle: 'Best route finder',
        ),
        FeatureCard(
          icon: Icons.local_gas_station_rounded,
          title: 'Fuel Cost',
          subtitle: 'Estimate expense',
        ),
        FeatureCard(
          icon: Icons.history_rounded,
          title: 'Trip History',
          subtitle: 'Previous journeys',
        ),
        FeatureCard(
          icon: Icons.auto_awesome_rounded,
          title: 'AI Assistant',
          subtitle: 'Smart suggestions',
        ),
      ],
    );
  }
}

class FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const FeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF2563EB),
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
