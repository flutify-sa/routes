import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:open_route_service/open_route_service.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:math' as math;

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: RoutePlanner(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class RoutePlanner extends StatefulWidget {
  const RoutePlanner({super.key});

  @override
  State<RoutePlanner> createState() => _RoutePlannerState();
}

class _RoutePlannerState extends State<RoutePlanner> {
  final List<LatLng> points = [];
  List<LatLng> routePoints = [];
  final OpenRouteService client = OpenRouteService(
    apiKey: '5b3ce3597851110001cf624806097e1c15154e2db4c098e7d2db5f3b',
  );

  LatLng? currentLocation;
  final MapController mapController = MapController();
  double? routeDistance;
  String? startAddress;
  String? endAddress;

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint("Location service is disabled.");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint("Location permission denied.");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint("Location permission permanently denied.");
      return;
    }

    try {
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      setState(() {
        currentLocation = LatLng(position.latitude, position.longitude);
      });

      // Defer map movement until after the first frame
      if (currentLocation != null) {
        Future.microtask(() {
          try {
            mapController.move(currentLocation!, 14);
          } catch (e) {
            debugPrint("Failed to move map: $e");
          }
        });
      }
    } catch (e) {
      debugPrint("Failed to get location: $e");
    }
  }

  Future<void> getRoute() async {
    if (points.length == 2) {
      try {
        final List<ORSCoordinate> coords = await client.directionsRouteCoordsGet(
          startCoordinate: ORSCoordinate(
            latitude: points[0].latitude,
            longitude: points[0].longitude,
          ),
          endCoordinate: ORSCoordinate(
            latitude: points[1].latitude,
            longitude: points[1].longitude,
          ),
        );

        String? tempStartAddress;
        String? tempEndAddress;

        try {
          List<Placemark> startPlacemarks = await placemarkFromCoordinates(
            points[0].latitude,
            points[0].longitude,
          );
          List<Placemark> endPlacemarks = await placemarkFromCoordinates(
            points[1].latitude,
            points[1].longitude,
          );

          tempStartAddress = startPlacemarks.isNotEmpty
              ? _formatAddress(startPlacemarks.first)
              : 'Unknown address';
          tempEndAddress = endPlacemarks.isNotEmpty
              ? _formatAddress(endPlacemarks.first)
              : 'Unknown address';
        } catch (e) {
          debugPrint("Failed to fetch addresses: $e");
          tempStartAddress = 'Unknown address';
          tempEndAddress = 'Unknown address';
        }

        setState(() {
          routePoints = coords.map((e) => LatLng(e.latitude, e.longitude)).toList();
          startAddress = tempStartAddress;
          endAddress = tempEndAddress;

          double totalDistance = 0;
          for (int i = 0; i < routePoints.length - 1; i++) {
            totalDistance += _calculateDistance(
              routePoints[i].latitude, routePoints[i].longitude,
              routePoints[i + 1].latitude, routePoints[i + 1].longitude,
            );
          }
          routeDistance = totalDistance;
        });
      } catch (e) {
        debugPrint("Failed to fetch route: $e");
      }
    }
  }

  String _formatAddress(Placemark placemark) {
    List<String> addressParts = [
      placemark.street ?? '',
      placemark.locality ?? '',
      placemark.administrativeArea ?? '',
      placemark.country ?? '',
    ].where((part) => part.isNotEmpty).toList();
    return addressParts.join(', ');
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371;
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) * math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) * math.sin(dLon / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final double distance = earthRadius * c;

    return distance;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  String getPointLabel(int index) {
    if (index == 0) return 'A';
    if (index == 1) return 'B';
    return '$index';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
     appBar: AppBar(
  title: const Text('Flutify Route Planner'),
  centerTitle: true,
  leading: Padding(
    padding: const EdgeInsets.all(8.0),
    child: Image.asset(
      'assets/valknut.png',
      width: 32,
      height: 32,
    ),
  ),
  actions: [
    IconButton(
      icon: const Icon(Icons.clear),
      tooltip: 'Clear Markers',
      onPressed: () {
        setState(() {
          points.clear();
          routePoints.clear();
          routeDistance = null;
          startAddress = null;
          endAddress = null;
        });
      },
    ),
  ],
),
      body: Column(
        children: [
          Expanded(
            child: currentLocation == null
                ? const Center(child: CircularProgressIndicator())
                : FlutterMap(
                    mapController: mapController,
                    options: MapOptions(
                      initialCenter: currentLocation!,
                      initialZoom: 16,
                      onTap: (tapPosition, point) {
                        setState(() {
                          if (points.length == 2) {
                            points.clear();
                            routePoints.clear();
                            routeDistance = null;
                            startAddress = null;
                            endAddress = null;
                          }
                          points.add(point);
                          if (points.length == 2) getRoute();
                        });
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.routeplanner',
                      ),
                      MarkerLayer(
                        markers: [
                          if (currentLocation != null)
                            Marker(
                              point: currentLocation!,
                              width: 40,
                              height: 40,
                              child: const Icon(Icons.my_location, color: Colors.blue),
                            ),
                        ],
                      ),
                      MarkerLayer(
                        markers: points.asMap().entries.map(
                          (entry) {
                            int idx = entry.key;
                            LatLng point = entry.value;
                            return Marker(
                              point: point,
                              width: 30,
                              height: 50,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: idx == 0 ? Colors.green : Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      getPointLabel(idx),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.location_on,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                ],
                              ),
                            );
                          },
                        ).toList(),
                      ),
                      if (routePoints.isNotEmpty)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: routePoints,
                              color: Colors.blue,
                              strokeWidth: 4,
                            ),
                          ],
                        ),
                    ],
                  ),
          ),
          if (routeDistance != null || startAddress != null || endAddress != null)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (startAddress != null)
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Start: $startAddress',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (endAddress != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'End: $endAddress',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (routeDistance != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.directions, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(
                            'Distance: ${routeDistance!.toStringAsFixed(2)} km',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}