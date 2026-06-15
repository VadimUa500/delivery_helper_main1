import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/api_service.dart';
import '../services/map_service.dart';

class ClientTrackingScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const ClientTrackingScreen({
    super.key,
    required this.order,
  });

  @override
  State<ClientTrackingScreen> createState() =>
      _ClientTrackingScreenState();
}

class _ClientTrackingScreenState extends State<ClientTrackingScreen> {
  GoogleMapController? _mapController;

  Timer? _pollingTimer;
  Timer? _markerAnimationTimer;

  Map<String, dynamic>? _trackingData;

  LatLng? _courierPosition;
  LatLng? _displayedCourierPosition;
  LatLng? _lastRouteOrigin;
  LatLng? _lastRouteTarget;

  DateTime? _lastRouteBuiltAt;

  Set<Marker> _markers = <Marker>{};
  Set<Polyline> _polylines = <Polyline>{};

  bool _loading = true;
  bool _requestInProgress = false;
  bool _routeRequestInProgress = false;
  bool _firstCameraPositioning = true;

  String? _errorMessage;
  String? _pollingWarning;
  String? _routeWarning;

  String _travelMode = 'driving';
  String? _lastRouteTravelMode;

  double _currentRoadDistanceKm = 0;
  int _currentRoadTimeMinutes = 0;

  static const Duration _pollingInterval = Duration(seconds: 5);
  static const Duration _minimumRouteRefreshInterval =
  Duration(seconds: 30);
  static const double _routeRefreshDistanceMeters = 100;

  String get _orderId {
    return (widget.order['id'] ?? widget.order['_id'] ?? '')
        .toString()
        .trim();
  }

  String get _currentStatus {
    return _trackingData?['status']?.toString() ??
        widget.order['status']?.toString() ??
        'new';
  }

  bool get _isTerminalStatus {
    return _currentStatus == 'delivered' ||
        _currentStatus == 'cancelled';
  }

  @override
  void initState() {
    super.initState();

    unawaited(_loadTracking(initialLoad: true));

    _pollingTimer = Timer.periodic(
      _pollingInterval,
          (_) => unawaited(_loadTracking()),
    );
  }

  double _toDouble(dynamic value) {
    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.round();
    }

    return double.tryParse(value?.toString() ?? '')?.round() ?? 0;
  }

  Map<String, dynamic> _toMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return <String, dynamic>{};
  }

  bool _validCoordinates(double latitude, double longitude) {
    if (!latitude.isFinite || !longitude.isFinite) {
      return false;
    }

    if (latitude < -90 || latitude > 90) {
      return false;
    }

    if (longitude < -180 || longitude > 180) {
      return false;
    }

    return latitude != 0 || longitude != 0;
  }

  LatLng? _orderPickupPosition() {
    final latitude = _toDouble(widget.order['pickup_lat']);
    final longitude = _toDouble(widget.order['pickup_lng']);

    if (!_validCoordinates(latitude, longitude)) {
      return null;
    }

    return LatLng(latitude, longitude);
  }

  LatLng? _orderDeliveryPosition() {
    final latitude = _toDouble(widget.order['delivery_lat']);
    final longitude = _toDouble(widget.order['delivery_lng']);

    if (!_validCoordinates(latitude, longitude)) {
      return null;
    }

    return LatLng(latitude, longitude);
  }

  String _pickupAddress() {
    return widget.order['pickup_address']?.toString().trim() ?? '';
  }

  String _deliveryAddress() {
    return widget.order['delivery_address']?.toString().trim() ?? '';
  }

  Future<void> _loadTracking({bool initialLoad = false}) async {
    if (_requestInProgress || _orderId.isEmpty) {
      return;
    }

    _requestInProgress = true;

    if (initialLoad && mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
        _pollingWarning = null;
      });
    }

    try {
      final response = await ApiService.getOrderTracking(_orderId);

      if (!mounted) {
        return;
      }

      final courier = _toMap(response['courier']);
      final route = _toMap(response['route']);

      final receivedMode = MapService.normalizeTravelMode(
        route['travel_mode']?.toString(),
      );

      final modeChanged = receivedMode != _travelMode;

      final latitude = _toDouble(courier['lat']);
      final longitude = _toDouble(courier['lng']);

      LatLng? newCourierPosition;

      if (_validCoordinates(latitude, longitude)) {
        newCourierPosition = LatLng(latitude, longitude);
      }

      final target = _determineRouteTarget(
        trackingResponse: response,
        route: route,
      );

      setState(() {
        _trackingData = Map<String, dynamic>.from(response);
        _travelMode = receivedMode;
        _loading = false;
        _errorMessage = null;
        _pollingWarning = null;

        if (modeChanged) {
          _lastRouteOrigin = null;
          _lastRouteTarget = null;
          _lastRouteBuiltAt = null;
          _lastRouteTravelMode = null;
        }
      });

      if (_isTerminalStatus) {
        _pollingTimer?.cancel();
        _pollingTimer = null;
      }

      if (newCourierPosition != null) {
        final previousPosition =
            _displayedCourierPosition ?? _courierPosition;

        _courierPosition = newCourierPosition;

        if (previousPosition == null) {
          setState(() {
            _displayedCourierPosition = newCourierPosition;
            _markers = _createMarkers();
          });
        } else {
          _animateCourierMarker(
            from: previousPosition,
            to: newCourierPosition,
          );
        }

        await _refreshRoadRouteIfNeeded(
          courierPosition: newCourierPosition,
          target: target,
          force: modeChanged,
        );
      } else {
        _refreshMarkers();
      }

      if (_firstCameraPositioning) {
        _firstCameraPositioning = false;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _fitVisiblePoints();
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;

        if (_trackingData == null) {
          _errorMessage = error.toString();
        } else {
          _pollingWarning =
          'Не вдалося отримати свіже GPS-оновлення: $error';
        }
      });
    } finally {
      _requestInProgress = false;
    }
  }

  LatLng? _determineRouteTarget({
    required Map<String, dynamic> trackingResponse,
    required Map<String, dynamic> route,
  }) {
    final status = trackingResponse['status']?.toString() ??
        widget.order['status']?.toString() ??
        'new';

    if (status == 'delivered') {
      return _orderDeliveryPosition();
    }

    final currentStepType =
    route['current_step_type']?.toString().trim().toLowerCase();

    if (currentStepType == 'pickup') {
      return _orderPickupPosition();
    }

    if (currentStepType == 'delivery') {
      return _orderDeliveryPosition();
    }

    if (status == 'in_progress') {
      return _orderDeliveryPosition();
    }

    return _orderPickupPosition();
  }

  void _animateCourierMarker({
    required LatLng from,
    required LatLng to,
  }) {
    _markerAnimationTimer?.cancel();

    final movementDistance = Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );

    if (movementDistance < 1) {
      if (!mounted) {
        return;
      }

      setState(() {
        _displayedCourierPosition = to;
        _markers = _createMarkers();
      });

      return;
    }

    const animationSteps = 20;
    int animationIndex = 0;

    _markerAnimationTimer = Timer.periodic(
      const Duration(milliseconds: 50),
          (timer) {
        animationIndex++;

        final progress = animationIndex / animationSteps;

        final latitude =
            from.latitude + ((to.latitude - from.latitude) * progress);

        final longitude =
            from.longitude + ((to.longitude - from.longitude) * progress);

        if (!mounted) {
          timer.cancel();
          return;
        }

        setState(() {
          _displayedCourierPosition = LatLng(latitude, longitude);
          _markers = _createMarkers();
        });

        if (animationIndex >= animationSteps) {
          timer.cancel();

          if (!mounted) {
            return;
          }

          setState(() {
            _displayedCourierPosition = to;
            _markers = _createMarkers();
          });
        }
      },
    );
  }

  Future<void> _refreshRoadRouteIfNeeded({
    required LatLng courierPosition,
    required LatLng? target,
    bool force = false,
  }) async {
    if (target == null ||
        _routeRequestInProgress ||
        _isTerminalStatus) {
      return;
    }

    bool shouldRefresh = force;

    if (!shouldRefresh &&
        (_lastRouteOrigin == null ||
            _lastRouteTarget == null ||
            _lastRouteBuiltAt == null ||
            _lastRouteTravelMode == null)) {
      shouldRefresh = true;
    }

    if (!shouldRefresh) {
      final movedDistance = Geolocator.distanceBetween(
        _lastRouteOrigin!.latitude,
        _lastRouteOrigin!.longitude,
        courierPosition.latitude,
        courierPosition.longitude,
      );

      final targetChanged = Geolocator.distanceBetween(
        _lastRouteTarget!.latitude,
        _lastRouteTarget!.longitude,
        target.latitude,
        target.longitude,
      ) >
          10;

      final modeChanged = _lastRouteTravelMode != _travelMode;

      final routeAge = DateTime.now().difference(_lastRouteBuiltAt!);

      shouldRefresh =
          movedDistance >= _routeRefreshDistanceMeters ||
              targetChanged ||
              modeChanged ||
              routeAge >= _minimumRouteRefreshInterval;
    }

    if (!shouldRefresh) {
      return;
    }

    _routeRequestInProgress = true;

    try {
      final details = await MapService.getRouteDetails(
        originLat: courierPosition.latitude,
        originLng: courierPosition.longitude,
        destinationLat: target.latitude,
        destinationLng: target.longitude,
        travelMode: _travelMode,
        forceRefresh: true,
      );

      List<LatLng> routePoints = <LatLng>[
        courierPosition,
        target,
      ];

      final rawPoints = details['points'];

      if (rawPoints is List) {
        final convertedPoints = rawPoints.whereType<LatLng>().toList();

        if (convertedPoints.isNotEmpty) {
          routePoints = convertedPoints;
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _currentRoadDistanceKm =
            _toDouble(details['distance_meters']) / 1000;

        _currentRoadTimeMinutes =
            (_toDouble(details['duration_seconds']) / 60).ceil();

        _polylines = <Polyline>{
          Polyline(
            polylineId: const PolylineId('courier_to_target'),
            points: routePoints,
            color: const Color(0xFF007AFF),
            width: 6,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            jointType: JointType.round,
          ),
        };

        _lastRouteOrigin = courierPosition;
        _lastRouteTarget = target;
        _lastRouteBuiltAt = DateTime.now();
        _lastRouteTravelMode = _travelMode;
        _routeWarning = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _polylines = <Polyline>{
          Polyline(
            polylineId: const PolylineId('courier_to_target_direct'),
            points: <LatLng>[
              courierPosition,
              target,
            ],
            color: Colors.orange,
            width: 4,
          ),
        };

        _routeWarning =
        'Не вдалося оновити дорожній маршрут: $error';
      });
    } finally {
      _routeRequestInProgress = false;
    }
  }

  Set<Marker> _createMarkers() {
    final result = <Marker>{};

    final courier = _displayedCourierPosition ?? _courierPosition;

    if (courier != null) {
      result.add(
        Marker(
          markerId: const MarkerId('courier'),
          position: courier,
          infoWindow: InfoWindow(
            title: 'Кур’єр',
            snippet:
            'Режим: ${MapService.travelModeLabel(_travelMode)}',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          rotation: _courierHeading(),
          anchor: const Offset(0.5, 0.5),
        ),
      );
    }

    final pickup = _orderPickupPosition();

    if (pickup != null) {
      result.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: pickup,
          infoWindow: InfoWindow(
            title: 'Адреса забору',
            snippet: _pickupAddress(),
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        ),
      );
    }

    final delivery = _orderDeliveryPosition();

    if (delivery != null) {
      result.add(
        Marker(
          markerId: const MarkerId('delivery'),
          position: delivery,
          infoWindow: InfoWindow(
            title: 'Адреса доставки',
            snippet: _deliveryAddress(),
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueRed,
          ),
        ),
      );
    }

    return result;
  }

  double _courierHeading() {
    final courier = _toMap(_trackingData?['courier']);
    final heading = _toDouble(courier['heading']);

    if (!heading.isFinite) {
      return 0;
    }

    return heading % 360;
  }

  void _refreshMarkers() {
    if (!mounted) {
      return;
    }

    setState(() {
      _markers = _createMarkers();
    });
  }

  void _fitVisiblePoints() {
    final controller = _mapController;

    if (controller == null) {
      return;
    }

    final points = <LatLng>[];

    final courier = _displayedCourierPosition ?? _courierPosition;

    if (courier != null) {
      points.add(courier);
    }

    final pickup = _orderPickupPosition();
    final delivery = _orderDeliveryPosition();

    if (pickup != null) {
      points.add(pickup);
    }

    if (delivery != null) {
      points.add(delivery);
    }

    if (points.isEmpty) {
      return;
    }

    if (points.length == 1) {
      unawaited(
        controller.animateCamera(
          CameraUpdate.newLatLngZoom(points.first, 15),
        ),
      );
      return;
    }

    double minLatitude = points.first.latitude;
    double maxLatitude = points.first.latitude;
    double minLongitude = points.first.longitude;
    double maxLongitude = points.first.longitude;

    for (final point in points) {
      if (point.latitude < minLatitude) {
        minLatitude = point.latitude;
      }

      if (point.latitude > maxLatitude) {
        maxLatitude = point.latitude;
      }

      if (point.longitude < minLongitude) {
        minLongitude = point.longitude;
      }

      if (point.longitude > maxLongitude) {
        maxLongitude = point.longitude;
      }
    }

    if ((maxLatitude - minLatitude).abs() < 0.0001) {
      maxLatitude += 0.001;
      minLatitude -= 0.001;
    }

    if ((maxLongitude - minLongitude).abs() < 0.0001) {
      maxLongitude += 0.001;
      minLongitude -= 0.001;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLatitude, minLongitude),
      northeast: LatLng(maxLatitude, maxLongitude),
    );

    Future<void>.delayed(
      const Duration(milliseconds: 300),
          () {
        if (!mounted || _mapController == null) {
          return;
        }

        unawaited(
          _mapController!.animateCamera(
            CameraUpdate.newLatLngBounds(bounds, 80),
          ),
        );
      },
    );
  }

  void _focusCourier() {
    final courier = _displayedCourierPosition ?? _courierPosition;

    if (courier == null || _mapController == null) {
      return;
    }

    unawaited(
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(courier, 16),
      ),
    );
  }

  String _statusText() {
    switch (_currentStatus) {
      case 'new':
        return 'Очікує кур’єра';
      case 'in_progress':
        return 'Кур’єр виконує доставку';
      case 'delivered':
        return 'Замовлення доставлено';
      case 'cancelled':
        return 'Замовлення скасовано';
      default:
        return 'Статус оновлюється';
    }
  }

  Color _statusColor() {
    switch (_currentStatus) {
      case 'in_progress':
        return const Color(0xFF007AFF);
      case 'delivered':
        return const Color(0xFF34C759);
      case 'cancelled':
        return const Color(0xFFFF3B30);
      default:
        return const Color(0xFFFF9500);
    }
  }

  String _liveStatusText() {
    final trackingAvailable =
        _trackingData?['tracking_available'] == true;
    final isLive = _trackingData?['is_live'] == true;

    if (!trackingAvailable) {
      return 'GPS кур’єра ще недоступний';
    }

    if (isLive) {
      return 'Місцезнаходження оновлюється';
    }

    final seconds = _toInt(
      _trackingData?['seconds_since_update'],
    );

    if (seconds > 0) {
      if (seconds < 60) {
        return 'Останнє оновлення $seconds с тому';
      }

      final minutes = (seconds / 60).floor();
      return 'Останнє оновлення $minutes хв тому';
    }

    return 'GPS тимчасово не оновлюється';
  }

  String _remainingDistanceText() {
    final route = _toMap(_trackingData?['route']);

    double distance = _toDouble(
      route['remaining_distance_km'],
    );

    if (distance <= 0 && _currentRoadDistanceKm > 0) {
      distance = _currentRoadDistanceKm;
    }

    if (distance <= 0) {
      return '—';
    }

    if (distance < 1) {
      return '${(distance * 1000).round()} м';
    }

    return '${distance.toStringAsFixed(1)} км';
  }

  String _estimatedArrivalText() {
    final route = _toMap(_trackingData?['route']);

    int minutes = _toInt(
      route['estimated_arrival_min'],
    );

    if (minutes <= 0 && _currentRoadTimeMinutes > 0) {
      minutes = _currentRoadTimeMinutes;
    }

    if (minutes <= 0) {
      return '—';
    }

    if (minutes < 60) {
      return '$minutes хв';
    }

    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    if (remainingMinutes == 0) {
      return '$hours год';
    }

    return '$hours год $remainingMinutes хв';
  }

  String _currentStepText() {
    final route = _toMap(_trackingData?['route']);
    final stepType = route['current_step_type']?.toString();

    if (stepType == 'pickup') {
      return 'Кур’єр прямує до адреси забору';
    }

    if (stepType == 'delivery') {
      return 'Кур’єр прямує до адреси доставки';
    }

    if (_currentStatus == 'new') {
      return 'Замовлення ще не прийняте';
    }

    if (_currentStatus == 'delivered') {
      return 'Доставку завершено';
    }

    if (_currentStatus == 'cancelled') {
      return 'Замовлення більше не виконується';
    }

    return 'Маршрут уточнюється';
  }

  IconData get _travelModeIcon {
    switch (_travelMode) {
      case 'walking':
        return Icons.directions_walk_rounded;
      case 'bicycling':
        return Icons.directions_bike_rounded;
      case 'driving':
      default:
        return Icons.directions_car_rounded;
    }
  }

  Widget _metricCard({
    required IconData icon,
    required String value,
    required String label,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E222D) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.03),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 9),
            Text(
              value,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: theme.hintColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _warningBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.orange,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildInformationCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final statusColor = _statusColor();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222D) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.03),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  _statusText(),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Оновити',
                onPressed: _requestInProgress
                    ? null
                    : () => unawaited(_loadTracking()),
                icon: _requestInProgress
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _currentStepText(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.textTheme.bodyMedium?.color?.withValues(
                alpha: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                _travelModeIcon,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 7),
              Text(
                MapService.travelModeLabel(_travelMode),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                _trackingData?['is_live'] == true
                    ? Icons.gps_fixed_rounded
                    : Icons.gps_not_fixed_rounded,
                size: 15,
                color: _trackingData?['is_live'] == true
                    ? const Color(0xFF34C759)
                    : Colors.orange,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _liveStatusText(),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: theme.hintColor,
                  ),
                ),
              ),
            ],
          ),
          if (_pollingWarning != null) ...[
            const SizedBox(height: 10),
            _warningBox(_pollingWarning!),
          ],
          if (_routeWarning != null) ...[
            const SizedBox(height: 10),
            _warningBox(_routeWarning!),
          ],
        ],
      ),
    );
  }

  Widget _buildNoTrackingScreen() {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _currentStatus == 'delivered'
                  ? Icons.task_alt_rounded
                  : Icons.delivery_dining_rounded,
              size: 70,
              color: _currentStatus == 'delivered'
                  ? const Color(0xFF34C759)
                  : theme.colorScheme.primary.withValues(alpha: 0.75),
            ),
            const SizedBox(height: 20),
            Text(
              _statusText(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _trackingData?['message']?.toString() ??
                  'Місцезнаходження кур’єра з’явиться після початку маршруту.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: theme.hintColor,
              ),
            ),
            if (!_isTerminalStatus) ...[
              const SizedBox(height: 22),
              ElevatedButton.icon(
                onPressed: () => unawaited(_loadTracking()),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Оновити'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 64,
              color: Colors.orange,
            ),
            const SizedBox(height: 18),
            Text(
              _errorMessage ?? 'Не вдалося завантажити відстеження.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () => unawaited(
                _loadTracking(initialLoad: true),
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Повторити'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackingContent({
    required bool isDark,
    required LatLng fallbackPosition,
  }) {
    return Column(
      children: [
        _buildInformationCard(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _metricCard(
                icon: Icons.navigation_rounded,
                value: _remainingDistanceText(),
                label: 'До доставки',
              ),
              const SizedBox(width: 10),
              _metricCard(
                icon: Icons.access_time_filled_rounded,
                value: _estimatedArrivalText(),
                label: 'Орієнтовний час',
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.03),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _courierPosition ?? fallbackPosition,
                      zoom: 13,
                    ),
                    markers: _markers,
                    polylines: _polylines,
                    zoomControlsEnabled: false,
                    myLocationButtonEnabled: false,
                    mapToolbarEnabled: true,
                    compassEnabled: true,
                    trafficEnabled: _travelMode == 'driving',
                    onMapCreated: (controller) {
                      _mapController = controller;
                      _refreshMarkers();
                      _fitVisiblePoints();
                    },
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Column(
                      children: [
                        FloatingActionButton.small(
                          heroTag: 'client_courier_position',
                          tooltip: 'Показати кур’єра',
                          onPressed: _focusCourier,
                          child: const Icon(
                            Icons.delivery_dining_rounded,
                          ),
                        ),
                        const SizedBox(height: 8),
                        FloatingActionButton.small(
                          heroTag: 'client_whole_route',
                          tooltip: 'Показати всі точки',
                          onPressed: _fitVisiblePoints,
                          child: const Icon(
                            Icons.zoom_out_map_rounded,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _markerAnimationTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final fallbackPosition = _orderDeliveryPosition() ??
        _orderPickupPosition() ??
        const LatLng(50.6199, 26.2516);

    final trackingAvailable =
        _trackingData?['tracking_available'] == true;

    Widget body;

    if (_loading) {
      body = const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 14),
            Text('Отримуємо дані про кур’єра...'),
          ],
        ),
      );
    } else if (_errorMessage != null && _trackingData == null) {
      body = _buildErrorScreen();
    } else if (!trackingAvailable) {
      body = Column(
        children: [
          _buildInformationCard(),
          Expanded(
            child: _buildNoTrackingScreen(),
          ),
        ],
      );
    } else {
      body = _buildTrackingContent(
        isDark: isDark,
        fallbackPosition: fallbackPosition,
      );
    }

    return Scaffold(
      backgroundColor:
      isDark ? const Color(0xFF13151A) : const Color(0xFFF8F9FD),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: theme.textTheme.titleLarge?.color,
        title: const Text(
          'Відстеження доставки',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: body,
    );
  }
}
