import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/map_service.dart';

class RoutePreviewScreen extends StatefulWidget {
  final Map<String, dynamic> route;

  const RoutePreviewScreen({
    super.key,
    required this.route,
  });

  @override
  State<RoutePreviewScreen> createState() => _RoutePreviewScreenState();
}

class _RoutePreviewScreenState extends State<RoutePreviewScreen> {
  GoogleMapController? _mapController;

  List<LatLng> routePoints = [];
  bool loadingRoute = true;
  String? routeError;

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  late LatLng pickupPoint;
  late LatLng deliveryPoint;

  @override
  void initState() {
    super.initState();

    final pickup = widget.route['pickup'] as Map<String, dynamic>? ?? {};
    final delivery = widget.route['delivery'] as Map<String, dynamic>? ?? {};

    pickupPoint = LatLng(
      _toDouble(pickup['lat']),
      _toDouble(pickup['lng']),
    );

    deliveryPoint = LatLng(
      _toDouble(delivery['lat']),
      _toDouble(delivery['lng']),
    );

    _loadRoadRoute();
  }

  Future<void> _loadRoadRoute() async {
    try {
      final points = await MapService.getRoutePolyline(
        originLat: pickupPoint.latitude,
        originLng: pickupPoint.longitude,
        destinationLat: deliveryPoint.latitude,
        destinationLng: deliveryPoint.longitude,
      );

      if (!mounted) return;

      setState(() {
        routePoints = points;
        loadingRoute = false;
      });

      _fitMapToRoute();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        routeError = e.toString();
        loadingRoute = false;
        routePoints = [pickupPoint, deliveryPoint];
      });

      _fitMapToRoute();
    }
  }

  void _fitMapToRoute() {
    final points = routePoints.isNotEmpty
        ? routePoints
        : [pickupPoint, deliveryPoint];

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    Future.delayed(const Duration(milliseconds: 500), () {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          80,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final pickup = widget.route['pickup'] as Map<String, dynamic>? ?? {};
    final delivery = widget.route['delivery'] as Map<String, dynamic>? ?? {};

    final pickupAddress = pickup['address']?.toString() ?? 'Pickup point';
    final deliveryAddress = delivery['address']?.toString() ?? 'Delivery point';

    final distance = widget.route['distance_km']?.toString() ?? '0';
    final time = widget.route['estimated_time_min']?.toString() ?? '0';

    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('pickup'),
        position: pickupPoint,
        infoWindow: InfoWindow(
          title: 'Pickup',
          snippet: pickupAddress,
        ),
      ),
      Marker(
        markerId: const MarkerId('delivery'),
        position: deliveryPoint,
        infoWindow: InfoWindow(
          title: 'Delivery',
          snippet: deliveryAddress,
        ),
      ),
    };

    final polylines = <Polyline>{
      Polyline(
        polylineId: const PolylineId('road_route'),
        points: routePoints.isNotEmpty ? routePoints : [pickupPoint, deliveryPoint],
        width: 6,
      ),
    };

    final center = LatLng(
      (pickupPoint.latitude + deliveryPoint.latitude) / 2,
      (pickupPoint.longitude + deliveryPoint.longitude) / 2,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery route'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: center,
                    zoom: 13,
                  ),
                  markers: markers,
                  polylines: polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: true,
                  mapToolbarEnabled: true,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    _fitMapToRoute();
                  },
                ),
                if (loadingRoute)
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: const [
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text('Building route on roads...'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (routeError != null)
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Card(
                      color: Colors.orange.shade100,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'Road route was not loaded. Straight line is shown.\n$routeError',
                          style: const TextStyle(color: Colors.black87),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: const [
                BoxShadow(
                  blurRadius: 8,
                  offset: Offset(0, -2),
                  color: Colors.black26,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row(Icons.my_location_outlined, 'Pickup', pickupAddress),
                _row(Icons.location_on_outlined, 'Delivery', deliveryAddress),
                _row(Icons.route_outlined, 'Distance', '$distance km'),
                _row(Icons.timer_outlined, 'Estimated time', '$time min'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$title: $value',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}