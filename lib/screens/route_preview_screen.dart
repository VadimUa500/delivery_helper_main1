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

  Widget _buildMetricPill(BuildContext context, IconData icon, String label) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C313F) : const Color(0xFFF3F5F8),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final pickup = widget.route['pickup'] as Map<String, dynamic>? ?? {};
    final delivery = widget.route['delivery'] as Map<String, dynamic>? ?? {};

    final pickupAddress = pickup['address']?.toString() ?? 'Адреса забору';
    final deliveryAddress = delivery['address']?.toString() ?? 'Адреса доставки';

    final distance = widget.route['distance_km']?.toString() ?? '0';
    final time = widget.route['estimated_time_min']?.toString() ?? '0';

    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('pickup'),
        position: pickupPoint,
        infoWindow: InfoWindow(
          title: 'Звідки забрати',
          snippet: pickupAddress,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
      Marker(
        markerId: const MarkerId('delivery'),
        position: deliveryPoint,
        infoWindow: InfoWindow(
          title: 'Куди доставити',
          snippet: deliveryAddress,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    };

    final polylines = <Polyline>{
      Polyline(
        polylineId: const PolylineId('road_route'),
        points: routePoints.isNotEmpty ? routePoints : [pickupPoint, deliveryPoint],
        width: 6,
        color: theme.colorScheme.primary,
      ),
    };

    final center = LatLng(
      (pickupPoint.latitude + deliveryPoint.latitude) / 2,
      (pickupPoint.longitude + deliveryPoint.longitude) / 2,
    );

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF13151A) : const Color(0xFFF8F9FD),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: theme.textTheme.titleLarge?.color,
        title: const Text(
          'Маршрут доставки',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
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
                  zoomControlsEnabled: false, // чистий HUD без громіздких кнопок зуму
                  mapToolbarEnabled: true,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    _fitMapToRoute();
                  },
                ),
                // Напівпрозорий скляний лоадер на карті
                if (loadingRoute)
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E222D).withValues(alpha: 0.9)
                            : Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Будуємо дорожній маршрут...',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Напівпрозоре попередження про помилку з'єднання
                if (routeError != null)
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E222D).withValues(alpha: 0.9)
                            : Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.2),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Маршрут не вдалося завантажити. Показано пряму лінію.',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Повністю перероблений плаваючий Bottom Sheet
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: 14,
              left: 24,
              right: 24,
              bottom: MediaQuery.of(context).padding.bottom > 0
                  ? MediaQuery.of(context).padding.bottom + 8
                  : 18,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E222D) : Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                  blurRadius: 16,
                  offset: const Offset(0, -6),
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                ),
              ],
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Тонка плашка Drag handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: theme.hintColor.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                // Рядок таймлайну адрес
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        const SizedBox(height: 4),
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Color(0xFF34C759),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Container(
                          width: 1.5,
                          height: 38,
                          color: isDark ? Colors.white10 : Colors.black12,
                        ),
                        const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFFFF3B30)),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pickupAddress,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text('Звідки забрати посилку', style: TextStyle(fontSize: 11.5, color: theme.hintColor)),
                          const SizedBox(height: 16),
                          Text(
                            deliveryAddress,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text('Куди доставити посилку', style: TextStyle(fontSize: 11.5, color: theme.hintColor)),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                Divider(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05), height: 1),
                const SizedBox(height: 16),

                // Чипи швидких метрик
                Row(
                  children: [
                    _buildMetricPill(context, Icons.navigation_rounded, '$distance км'),
                    const SizedBox(width: 10),
                    _buildMetricPill(context, Icons.access_time_filled_rounded, '$time хв'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}