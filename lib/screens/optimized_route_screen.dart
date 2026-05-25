import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/map_service.dart';

class OptimizedRouteScreen extends StatefulWidget {
  final List<Map<String, dynamic>> orders;

  const OptimizedRouteScreen({
    super.key,
    required this.orders,
  });

  @override
  State<OptimizedRouteScreen> createState() => _OptimizedRouteScreenState();
}

class _OptimizedRouteScreenState extends State<OptimizedRouteScreen> {
  GoogleMapController? mapController;

  bool loading = true;
  String? error;

  bool routeStarted = false;
  bool routeFinished = false;
  int currentStepIndex = 0;

  List<Map<String, dynamic>> optimizedSteps = [];
  Set<Polyline> polylines = {};
  Set<Marker> markers = {};

  double totalDistanceKm = 0;
  int totalTimeMin = 0;

  final List<Color> routeColors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.red,
  ];

  double _toDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  @override
  void initState() {
    super.initState();
    _buildOptimizedRoute();
  }

  Future<void> _buildOptimizedRoute() async {
    try {
      final orders = [...widget.orders];

      orders.sort((a, b) {
        final da = _toDouble(a['distance_km']);
        final db = _toDouble(b['distance_km']);
        return da.compareTo(db);
      });

      final steps = <Map<String, dynamic>>[];

      for (int i = 0; i < orders.length; i++) {
        final o = orders[i];

        steps.add({
          'label': 'P${i + 1}',
          'orderNumber': i + 1,
          'type': 'pickup',
          'title': 'Забрати замовлення ${i + 1}',
          'address': o['pickup_address']?.toString() ?? '',
          'lat': _toDouble(o['pickup_lat']),
          'lng': _toDouble(o['pickup_lng']),
        });

        steps.add({
          'label': 'D${i + 1}',
          'orderNumber': i + 1,
          'type': 'delivery',
          'title': 'Доставити замовлення ${i + 1}',
          'address': o['delivery_address']?.toString() ?? '',
          'lat': _toDouble(o['delivery_lat']),
          'lng': _toDouble(o['delivery_lng']),
        });
      }

      final newPolylines = <Polyline>{};
      double distanceSum = 0;
      int timeSum = 0;

      for (int i = 0; i < steps.length - 1; i++) {
        final start = steps[i];
        final end = steps[i + 1];

        final part = await MapService.getRoutePolyline(
          originLat: start['lat'],
          originLng: start['lng'],
          destinationLat: end['lat'],
          destinationLng: end['lng'],
        );

        newPolylines.add(
          Polyline(
            polylineId: PolylineId('segment_$i'),
            points: part,
            width: 6,
            color: routeColors[i % routeColors.length],
          ),
        );

        try {
          final info = await MapService.getRouteInfo(
            originLat: start['lat'],
            originLng: start['lng'],
            destinationLat: end['lat'],
            destinationLng: end['lng'],
          );

          final meters = _toDouble(info['distance_meters']);
          final seconds = _toDouble(info['duration_seconds']);

          distanceSum += meters / 1000;
          timeSum += (seconds / 60).round();
        } catch (_) {}
      }

      if (!mounted) return;

      setState(() {
        optimizedSteps = steps;
        polylines = newPolylines;
        totalDistanceKm = distanceSum;
        totalTimeMin = timeSum;
        loading = false;
      });

      _updateMarkers();
      _focusCurrentStep();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  void _updateMarkers() {
    if (optimizedSteps.isEmpty) return;

    final newMarkers = <Marker>{};

    for (int i = 0; i < optimizedSteps.length; i++) {
      final s = optimizedSteps[i];
      final isPickup = s['type'] == 'pickup';
      final isCurrent = i == currentStepIndex;
      final isCompleted = i < currentStepIndex || routeFinished;

      double hue;

      if (isCompleted) {
        hue = BitmapDescriptor.hueViolet;
      } else if (isCurrent) {
        hue = BitmapDescriptor.hueGreen;
      } else if (isPickup) {
        hue = BitmapDescriptor.hueAzure;
      } else {
        hue = BitmapDescriptor.hueRed;
      }

      newMarkers.add(
        Marker(
          markerId: MarkerId(s['label']),
          position: LatLng(s['lat'], s['lng']),
          infoWindow: InfoWindow(
            title: isCurrent ? 'Поточна точка: ${s['label']}' : s['label'],
            snippet: s['address'],
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        ),
      );
    }

    setState(() {
      markers = newMarkers;
    });
  }

  void _focusCurrentStep() {
    if (optimizedSteps.isEmpty || mapController == null) return;

    final current = optimizedSteps[currentStepIndex];
    final currentPoint = LatLng(current['lat'], current['lng']);

    mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: currentPoint,
          zoom: 15,
        ),
      ),
    );
  }

  void _fitWholeRoute() {
    if (optimizedSteps.isEmpty || mapController == null) return;

    final points = optimizedSteps.map((s) => LatLng(s['lat'], s['lng'])).toList();

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

    mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        90,
      ),
    );
  }

  void _startRoute() {
    setState(() {
      routeStarted = true;
      routeFinished = false;
      currentStepIndex = 0;
    });

    _updateMarkers();
    _focusCurrentStep();
  }

  void _completeCurrentStep() {
    if (optimizedSteps.isEmpty) return;

    if (currentStepIndex >= optimizedSteps.length - 1) {
      setState(() {
        routeFinished = true;
        routeStarted = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Оптимізований маршрут завершено'),
        ),
      );

      _updateMarkers();
      return;
    }

    setState(() {
      currentStepIndex++;
    });

    _updateMarkers();
    _focusCurrentStep();
  }

  Color _stepColor(String type, bool isCurrent, bool isCompleted) {
    if (isCompleted) return Colors.grey;
    if (isCurrent) return Colors.green;
    return type == 'pickup' ? Colors.blue : Colors.red;
  }

  IconData _stepIcon(String type) {
    return type == 'pickup'
        ? Icons.inventory_2_outlined
        : Icons.location_on_outlined;
  }

  Widget _buildHeader() {
    final deliveryCount = widget.orders.length;

    String currentText = 'Маршрут ще не розпочато';

    if (routeFinished) {
      currentText = 'Маршрут завершено';
    } else if (routeStarted && optimizedSteps.isNotEmpty) {
      final current = optimizedSteps[currentStepIndex];
      currentText =
      'Зараз: ${current['label']} — ${current['type'] == 'pickup' ? 'забрати' : 'доставити'}';
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Оптимізовано $deliveryCount доставки',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.route_outlined, size: 18),
                const SizedBox(width: 6),
                Text(
                  totalDistanceKm > 0
                      ? '${totalDistanceKm.toStringAsFixed(2)} км'
                      : 'відстань рахується',
                ),
                const SizedBox(width: 16),
                const Icon(Icons.timer_outlined, size: 18),
                const SizedBox(width: 6),
                Text(
                  totalTimeMin > 0 ? '$totalTimeMin хв' : 'час рахується',
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.navigation_outlined, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    currentText,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: routeFinished ? Colors.green : null,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Поточна точка — це наступна адреса, яку кур’єру потрібно виконати.',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: loading || optimizedSteps.isEmpty
                        ? null
                        : routeStarted
                        ? _completeCurrentStep
                        : _startRoute,
                    icon: Icon(
                      routeStarted
                          ? Icons.check_circle_outline
                          : Icons.play_arrow,
                    ),
                    label: Text(
                      routeStarted ? 'Завершити точку' : 'Почати маршрут',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _fitWholeRoute,
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Весь маршрут'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Positioned(
      top: 12,
      left: 12,
      right: 12,
      child: Card(
        elevation: 4,
        color: Colors.black.withOpacity(0.78),
        child: const Padding(
          padding: EdgeInsets.all(10),
          child: Row(
            children: [
              Icon(Icons.location_on, color: Colors.green),
              SizedBox(width: 4),
              Text('Поточна', style: TextStyle(color: Colors.white)),
              SizedBox(width: 12),
              Icon(Icons.location_on, color: Colors.blue),
              SizedBox(width: 4),
              Text('Pickup', style: TextStyle(color: Colors.white)),
              SizedBox(width: 12),
              Icon(Icons.location_on, color: Colors.red),
              SizedBox(width: 4),
              Text('Delivery', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepCard(Map<String, dynamic> s, int index) {
    final type = s['type']?.toString() ?? '';
    final isCurrent = routeStarted && index == currentStepIndex;
    final isCompleted = index < currentStepIndex || routeFinished;
    final color = _stepColor(type, isCurrent, isCompleted);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isCurrent
          ? Colors.green.withOpacity(0.12)
          : isCompleted
          ? Colors.grey.withOpacity(0.12)
          : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color,
          child: Text(
            s['label'],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          s['title']?.toString() ?? '',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text(
          s['address']?.toString() ?? '',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(
          isCompleted ? Icons.done_all : _stepIcon(type),
          color: color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initialPoint = optimizedSteps.isNotEmpty
        ? LatLng(optimizedSteps.first['lat'], optimizedSteps.first['lng'])
        : const LatLng(50.6199, 26.2516);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Оптимізований маршрут'),
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: initialPoint,
                    zoom: 13,
                  ),
                  markers: markers,
                  polylines: polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: true,
                  mapToolbarEnabled: true,
                  onMapCreated: (controller) {
                    mapController = controller;
                    Future.delayed(
                      const Duration(milliseconds: 500),
                      _fitWholeRoute,
                    );
                  },
                ),
                _buildLegend(),
                if (loading)
                  const Center(child: CircularProgressIndicator()),
                if (error != null)
                  Positioned(
                    top: 70,
                    left: 12,
                    right: 12,
                    child: Card(
                      color: Colors.orange.shade100,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          error!,
                          style: const TextStyle(color: Colors.black87),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Рекомендований порядок виконання',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: optimizedSteps.isEmpty
                        ? const Center(
                      child: Text('Маршрут ще будується...'),
                    )
                        : ListView.builder(
                      itemCount: optimizedSteps.length,
                      itemBuilder: (context, index) {
                        return _buildStepCard(
                          optimizedSteps[index],
                          index,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}