import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/map_service.dart';

class OptimizedRouteScreen extends StatefulWidget {
final List<Map<String, dynamic>> orders;

const OptimizedRouteScreen({
super.key,
required this.orders,
});

@override
State<OptimizedRouteScreen> createState() =>
_OptimizedRouteScreenState();
}

class _OptimizedRouteScreenState extends State<OptimizedRouteScreen> {
final LocationService _locationService = LocationService.instance;

GoogleMapController? _mapController;
StreamSubscription<Position>? _positionSubscription;

Position? _currentPosition;
Position? _lastTrackingSentPosition;
Position? _lastRoadRefreshPosition;

DateTime? _lastTrackingSentAt;
DateTime? _lastRoadRefreshAt;

List<Map<String, dynamic>> _optimizedSteps =
<Map<String, dynamic>>[];

List<_RouteSegment> _routeSegments = <_RouteSegment>[];
List<Map<String, dynamic>> _navigationSteps =
<Map<String, dynamic>>[];

Set<Marker> _markers = <Marker>{};
Set<Polyline> _polylines = <Polyline>{};

bool _loading = true;
bool _routeStarted = false;
bool _routeFinished = false;
bool _processingStep = false;
bool _trackingRequestInProgress = false;
bool _roadRefreshInProgress = false;
bool _movementUpdateInProgress = false;

String? _errorMessage;
String? _trackingWarning;
String? _routeWarning;

String _travelMode = 'driving';

int _currentStepIndex = 0;

double _totalDistanceKm = 0;
int _totalTimeMinutes = 0;

double _currentSegmentDistanceKm = 0;
int _currentSegmentTimeMinutes = 0;

double _distanceToCurrentPointMeters = 0;

static const Duration _trackingSendInterval =
Duration(seconds: 10);

static const Duration _roadRefreshInterval =
Duration(seconds: 30);

static const double _trackingSendDistanceMeters = 25;
static const double _roadRefreshDistanceMeters = 80;
static const double _arrivalWarningRadiusMeters = 200;

static const List<Color> _routeColors = <Color>[
Color(0xFF007AFF),
Color(0xFF34C759),
Color(0xFFFF9500),
Color(0xFFAF52DE),
Color(0xFF00A7A7),
Color(0xFFFF3B30),
];

@override
void initState() {
super.initState();
_initializeRoute();
}

String _orderId(Map<String, dynamic> order) {
return (order['id'] ?? order['_id'] ?? '').toString().trim();
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

bool _validCoordinates(
double latitude,
double longitude,
) {
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

Map<String, dynamic>? get _currentStep {
if (_optimizedSteps.isEmpty) {
return null;
}

if (_currentStepIndex < 0 ||
_currentStepIndex >= _optimizedSteps.length) {
return null;
}

return _optimizedSteps[_currentStepIndex];
}

LatLng _positionToLatLng(Position position) {
return LatLng(
position.latitude,
position.longitude,
);
}

Future<void> _initializeRoute() async {
if (mounted) {
setState(() {
_loading = true;
_errorMessage = null;
_routeWarning = null;
});
}

try {
final position = await _locationService.getCurrentPosition();

final steps = _createOptimizedSteps(
startPosition: position,
);

if (steps.isEmpty) {
throw const LocationServiceException(
'Не знайдено замовлень із коректними координатами.',
);
}

final result = await _buildRoadRoute(
startPosition: position,
steps: steps,
travelMode: _travelMode,
);

if (!mounted) {
return;
}

setState(() {
_currentPosition = position;
_optimizedSteps = steps;
_routeSegments = result.segments;
_polylines = result.polylines;

_totalDistanceKm = result.distanceKm;
_totalTimeMinutes = result.timeMinutes;

_currentStepIndex = 0;

if (result.segments.isNotEmpty) {
_currentSegmentDistanceKm =
result.segments.first.distanceKm;

_currentSegmentTimeMinutes =
result.segments.first.durationMinutes;

_navigationSteps =
result.segments.first.navigationSteps;
}

_distanceToCurrentPointMeters = _distanceToStep(
position,
steps.first,
);

_loading = false;
});

_refreshMarkers();

WidgetsBinding.instance.addPostFrameCallback((_) {
_fitWholeRoute();
});
} catch (error) {
if (!mounted) {
return;
}

setState(() {
_loading = false;
_errorMessage = error.toString();
});
}
}

List<Map<String, dynamic>> _createOptimizedSteps({
required Position startPosition,
}) {
final nodes = <Map<String, dynamic>>[];

for (int index = 0; index < widget.orders.length; index++) {
final order = widget.orders[index];
final orderId = _orderId(order);

final pickupLat = _toDouble(order['pickup_lat']);
final pickupLng = _toDouble(order['pickup_lng']);

final deliveryLat = _toDouble(order['delivery_lat']);
final deliveryLng = _toDouble(order['delivery_lng']);

if (orderId.isEmpty) {
continue;
}

if (!_validCoordinates(pickupLat, pickupLng) ||
!_validCoordinates(deliveryLat, deliveryLng)) {
continue;
}

nodes.add(
<String, dynamic>{
'node_id': '${orderId}_pickup',
'order_id': orderId,
'order_number': index + 1,
'type': 'pickup',
'label': 'З${index + 1}',
'title': 'Забрати відправлення №${index + 1}',
'address': order['pickup_address']?.toString() ?? '',
'lat': pickupLat,
'lng': pickupLng,
},
);
nodes.add(
<String, dynamic>{
'node_id': '${orderId}_delivery',
'order_id': orderId,
'order_number': index + 1,
'type': 'delivery',
'label': 'Д${index + 1}',
'title': 'Доставити відправлення №${index + 1}',
'address': order['delivery_address']?.toString() ?? '',
'lat': deliveryLat,
'lng': deliveryLng,
},
);
}
final initialRoute = _nearestNeighbourRoute(
nodes: nodes,
startLatitude: startPosition.latitude,
startLongitude: startPosition.longitude,
);
return _improveRouteWithTwoOpt(
route: initialRoute,
startPoint: _positionToLatLng(startPosition),
);
}

List<Map<String, dynamic>> _nearestNeighbourRoute({
required List<Map<String, dynamic>> nodes,
required double startLatitude,
required double startLongitude,
}) {
final remaining = nodes
    .map(
(node) => Map<String, dynamic>.from(node),
)
    .toList();

final route = <Map<String, dynamic>>[];
final pickedUpOrders = <String>{};

double currentLatitude = startLatitude;
double currentLongitude = startLongitude;

while (remaining.isNotEmpty) {
final candidates = remaining.where((node) {
final type = node['type']?.toString() ?? '';
final orderId = node['order_id']?.toString() ?? '';

if (type == 'pickup') {
return true;
}

return pickedUpOrders.contains(orderId);
}).toList();

if (candidates.isEmpty) {
break;
}

Map<String, dynamic>? nearestNode;
double nearestDistance = double.infinity;
for (final candidate in candidates) {
final latitude = _toDouble(candidate['lat']);
final longitude = _toDouble(candidate['lng']);
final distance = Geolocator.distanceBetween(
currentLatitude,
currentLongitude,
latitude,
longitude,
);
if (distance < nearestDistance) {
nearestDistance = distance;
nearestNode = candidate;
}
}
if (nearestNode == null) {
break;
}
route.add(nearestNode);
remaining.removeWhere(
(node) => node['node_id'] == nearestNode?['node_id'],
);
if (nearestNode['type'] == 'pickup') {
pickedUpOrders.add(
nearestNode['order_id'].toString(),
);
}
currentLatitude = _toDouble(nearestNode['lat']);
currentLongitude = _toDouble(nearestNode['lng']);
}
return route;
}

List<Map<String, dynamic>> _improveRouteWithTwoOpt({
required List<Map<String, dynamic>> route,
required LatLng startPoint,
}) {
if (route.length < 4 || route.length > 16) {
return route;
}

var bestRoute = route
    .map(
(step) => Map<String, dynamic>.from(step),
)
    .toList();

var bestCost = _routeCost(
route: bestRoute,
startPoint: startPoint,
);

for (int pass = 0; pass < 2; pass++) {
bool improved = false;

for (int startIndex = 0;
startIndex < bestRoute.length - 1;
startIndex++) {
for (int endIndex = startIndex + 1;
endIndex < bestRoute.length;
endIndex++) {
final candidate = bestRoute
    .map(
(step) => Map<String, dynamic>.from(step),
)
    .toList();

final reversed = candidate
    .sublist(startIndex, endIndex + 1)
    .reversed
    .toList();

candidate.replaceRange(
startIndex,
endIndex + 1,
reversed,
);

if (!_isPickupDeliveryOrderValid(candidate)) {
continue;
}

final candidateCost = _routeCost(
route: candidate,
startPoint: startPoint,
);

if (candidateCost + 1 < bestCost) {
bestRoute = candidate;
bestCost = candidateCost;
improved = true;
}
}
}

if (!improved) {
break;
}
}

return bestRoute;
}

bool _isPickupDeliveryOrderValid(
List<Map<String, dynamic>> route,
) {
final pickupIndexes = <String, int>{};
final deliveryIndexes = <String, int>{};

for (int index = 0; index < route.length; index++) {
final orderId =
route[index]['order_id']?.toString() ?? '';

if (route[index]['type'] == 'pickup') {
pickupIndexes[orderId] = index;
}

if (route[index]['type'] == 'delivery') {
deliveryIndexes[orderId] = index;
}
}

for (final orderId in pickupIndexes.keys) {
final pickupIndex = pickupIndexes[orderId];
final deliveryIndex = deliveryIndexes[orderId];

if (pickupIndex == null ||
deliveryIndex == null ||
pickupIndex >= deliveryIndex) {
return false;
}
}

return true;
}

double _routeCost({
required List<Map<String, dynamic>> route,
required LatLng startPoint,
}) {
double result = 0;

double currentLatitude = startPoint.latitude;
double currentLongitude = startPoint.longitude;

for (final step in route) {
final latitude = _toDouble(step['lat']);
final longitude = _toDouble(step['lng']);

result += Geolocator.distanceBetween(
currentLatitude,
currentLongitude,
latitude,
longitude,
);

currentLatitude = latitude;
currentLongitude = longitude;
}

return result;
}

Future<_RouteBuildResult> _buildRoadRoute({
required Position startPosition,
required List<Map<String, dynamic>> steps,
required String travelMode,
}) async {
final resultPolylines = <Polyline>{};
final segments = <_RouteSegment>[];

final routePoints = <LatLng>[
_positionToLatLng(startPosition),
...steps.map(
(step) => LatLng(
_toDouble(step['lat']),
_toDouble(step['lng']),
),
),
];

double distanceKm = 0;
int timeMinutes = 0;

for (int index = 0;
index < routePoints.length - 1;
index++) {
final origin = routePoints[index];
final destination = routePoints[index + 1];

List<LatLng> segmentPoints = <LatLng>[
origin,
destination,
];

double segmentDistanceKm = 0;
int segmentTimeMinutes = 0;

List<Map<String, dynamic>> navigationSteps =
<Map<String, dynamic>>[];

try {
final details = await MapService.getRouteDetails(
originLat: origin.latitude,
originLng: origin.longitude,
destinationLat: destination.latitude,
destinationLng: destination.longitude,
travelMode: travelMode,
);

final receivedPoints = details['points'];

if (receivedPoints is List) {
final converted =
receivedPoints.whereType<LatLng>().toList();

if (converted.isNotEmpty) {
segmentPoints = converted;
}
}

segmentDistanceKm =
_toDouble(details['distance_meters']) / 1000;

segmentTimeMinutes =
(_toDouble(details['duration_seconds']) / 60).ceil();

final rawNavigationSteps = details['steps'];

if (rawNavigationSteps is List) {
navigationSteps = rawNavigationSteps
    .whereType<Map>()
    .map(
(item) => Map<String, dynamic>.from(item),
)
    .toList();
}
} catch (_) {
final directDistance = Geolocator.distanceBetween(
origin.latitude,
origin.longitude,
destination.latitude,
destination.longitude,
);

segmentDistanceKm = directDistance / 1000;

segmentTimeMinutes = _estimateMinutesByMode(
segmentDistanceKm,
);
}

distanceKm += segmentDistanceKm;
timeMinutes += segmentTimeMinutes;

segments.add(
_RouteSegment(
index: index,
points: segmentPoints,
distanceKm: segmentDistanceKm,
durationMinutes: segmentTimeMinutes,
navigationSteps: navigationSteps,
),
);

resultPolylines.add(
Polyline(
polylineId: PolylineId('segment_$index'),
points: segmentPoints,
width: 6,
color: _routeColors[index % _routeColors.length],
startCap: Cap.roundCap,
endCap: Cap.roundCap,
jointType: JointType.round,
),
);
}

return _RouteBuildResult(
polylines: resultPolylines,
segments: segments,
distanceKm: distanceKm,
timeMinutes: timeMinutes,
);
}

Future<void> _changeTravelMode(
String selectedMode,
) async {
if (_routeStarted || _loading || selectedMode == _travelMode) {
return;
}

final position = _currentPosition ??
await _locationService.getCurrentPosition();

if (!mounted) {
return;
}

setState(() {
_travelMode = selectedMode;
_loading = true;
_errorMessage = null;
_routeWarning = null;
});

try {
final steps = _createOptimizedSteps(
startPosition: position,
);

final result = await _buildRoadRoute(
startPosition: position,
steps: steps,
travelMode: selectedMode,
);

if (!mounted) {
return;
}

setState(() {
_currentPosition = position;
_optimizedSteps = steps;
_routeSegments = result.segments;
_polylines = result.polylines;

_totalDistanceKm = result.distanceKm;
_totalTimeMinutes = result.timeMinutes;

_currentStepIndex = 0;
_routeFinished = false;

if (result.segments.isNotEmpty) {
_currentSegmentDistanceKm =
result.segments.first.distanceKm;

_currentSegmentTimeMinutes =
result.segments.first.durationMinutes;

_navigationSteps =
result.segments.first.navigationSteps;
}

_distanceToCurrentPointMeters = _distanceToStep(
position,
steps.first,
);

_loading = false;
});

_refreshMarkers();

WidgetsBinding.instance.addPostFrameCallback((_) {
_fitWholeRoute();
});
} catch (error) {
if (!mounted) {
return;
}

setState(() {
_loading = false;
_errorMessage = error.toString();
});
}
}

Future<void> _startRoute() async {
if (_loading ||
_routeStarted ||
_optimizedSteps.isEmpty) {
return;
}

setState(() {
_routeStarted = true;
_routeFinished = false;
_currentStepIndex = 0;
_errorMessage = null;
_trackingWarning = null;
});

_positionSubscription =
_locationService.positionStream.listen(
_handlePositionUpdate,
onError: (Object error) {
if (!mounted) {
return;
}

setState(() {
_trackingWarning = error.toString();
});
},
);

try {
await _locationService.startTracking(
distanceFilter: 8,
interval: const Duration(seconds: 5),
);

final position = _locationService.lastPosition ??
await _locationService.getCurrentPosition();

_handlePositionUpdate(position);

await _refreshCurrentSegmentRoute(
position,
force: true,
);

await _sendTrackingUpdate(
position,
force: true,
);

_focusCurrentStep();
} catch (error) {
await _positionSubscription?.cancel();
_positionSubscription = null;

if (!mounted) {
return;
}

setState(() {
_routeStarted = false;
_errorMessage = error.toString();
});
}
}

void _handlePositionUpdate(Position position) {
if (!mounted) {
return;
}

final step = _currentStep;

setState(() {
_currentPosition = position;

if (step != null) {
_distanceToCurrentPointMeters = _distanceToStep(
position,
step,
);
}

_markers = _createMarkers(
currentPosition: position,
);
});

unawaited(
_processMovementUpdate(position),
);
}

Future<void> _processMovementUpdate(
Position position,
) async {
if (_movementUpdateInProgress) {
return;
}

_movementUpdateInProgress = true;

try {
await _refreshCurrentSegmentRoute(position);
await _sendTrackingUpdate(position);
} finally {
_movementUpdateInProgress = false;
}
}

double _distanceToStep(
Position position,
Map<String, dynamic> step,
) {
return Geolocator.distanceBetween(
position.latitude,
position.longitude,
_toDouble(step['lat']),
_toDouble(step['lng']),
);
}

bool _shouldRefreshRoadRoute(
Position position,
) {
if (!_routeStarted || _routeFinished) {
return false;
}

if (_lastRoadRefreshAt == null ||
_lastRoadRefreshPosition == null) {
return true;
}

final elapsed = DateTime.now().difference(
_lastRoadRefreshAt!,
);

final movedMeters = Geolocator.distanceBetween(
_lastRoadRefreshPosition!.latitude,
_lastRoadRefreshPosition!.longitude,
position.latitude,
position.longitude,
);

return elapsed >= _roadRefreshInterval ||
movedMeters >= _roadRefreshDistanceMeters;
}

Future<void> _refreshCurrentSegmentRoute(
Position position, {
bool force = false,
}) async {
final step = _currentStep;

if (step == null || _roadRefreshInProgress) {
return;
}

if (!force && !_shouldRefreshRoadRoute(position)) {
return;
}

_roadRefreshInProgress = true;

try {
final details = await MapService.getRouteDetails(
originLat: position.latitude,
originLng: position.longitude,
destinationLat: _toDouble(step['lat']),
destinationLng: _toDouble(step['lng']),
travelMode: _travelMode,
forceRefresh: true,
);

List<LatLng> activePoints = <LatLng>[
LatLng(
position.latitude,
position.longitude,
),
LatLng(
_toDouble(step['lat']),
_toDouble(step['lng']),
),
];

final receivedPoints = details['points'];

if (receivedPoints is List) {
final converted =
receivedPoints.whereType<LatLng>().toList();

if (converted.isNotEmpty) {
activePoints = converted;
}
}

final rawNavigationSteps = details['steps'];

final navigationSteps = rawNavigationSteps is List
? rawNavigationSteps
    .whereType<Map>()
    .map(
(item) => Map<String, dynamic>.from(item),
)
    .toList()
    : <Map<String, dynamic>>[];

if (!mounted) {
return;
}

setState(() {
_currentSegmentDistanceKm =
_toDouble(details['distance_meters']) / 1000;

_currentSegmentTimeMinutes =
(_toDouble(details['duration_seconds']) / 60).ceil();

_navigationSteps = navigationSteps;

_polylines.removeWhere(
(polyline) =>
polyline.polylineId.value == 'active_segment',
);

_polylines.add(
Polyline(
polylineId: const PolylineId('active_segment'),
points: activePoints,
width: 8,
color: const Color(0xFF007AFF),
zIndex: 10,
startCap: Cap.roundCap,
endCap: Cap.roundCap,
jointType: JointType.round,
),
);

_routeWarning = null;
});

_lastRoadRefreshAt = DateTime.now();
_lastRoadRefreshPosition = position;
} catch (error) {
if (mounted) {
setState(() {
_routeWarning =
'Не вдалося оновити дорожній маршрут: $error';
});
}
} finally {
_roadRefreshInProgress = false;
}
}

bool _shouldSendTracking(
Position position,
) {
if (!_routeStarted || _routeFinished) {
return false;
}

if (_lastTrackingSentAt == null ||
_lastTrackingSentPosition == null) {
return true;
}

final elapsed = DateTime.now().difference(
_lastTrackingSentAt!,
);

final movedMeters = Geolocator.distanceBetween(
_lastTrackingSentPosition!.latitude,
_lastTrackingSentPosition!.longitude,
position.latitude,
position.longitude,
);

return elapsed >= _trackingSendInterval ||
movedMeters >= _trackingSendDistanceMeters;
}

Future<void> _sendTrackingUpdate(
Position position, {
bool force = false,
}) async {
if (_trackingRequestInProgress) {
return;
}

if (!force && !_shouldSendTracking(position)) {
return;
}

_trackingRequestInProgress = true;

try {
await ApiService.updateCourierLocation(
latitude: position.latitude,
longitude: position.longitude,
accuracy: position.accuracy,
speedMps: position.speed,
heading: position.heading,
travelMode: _travelMode,
currentStepType: _currentStep?['type']?.toString(),
currentStepAddress:
_currentStep?['address']?.toString(),
orderUpdates: _buildOrderTrackingUpdates(
position,
),
);

_lastTrackingSentAt = DateTime.now();
_lastTrackingSentPosition = position;

if (mounted && _trackingWarning != null) {
setState(() {
_trackingWarning = null;
});
}
} catch (error) {
if (mounted) {
setState(() {
_trackingWarning =
'Не вдалося передати GPS на сервер: $error';
});
}
} finally {
_trackingRequestInProgress = false;
}
}

List<Map<String, dynamic>> _buildOrderTrackingUpdates(
Position position,
) {
final result = <Map<String, dynamic>>[];

for (final order in widget.orders) {
final orderId = _orderId(order);

if (orderId.isEmpty) {
continue;
}

final remaining = _remainingRouteForOrder(
position: position,
orderId: orderId,
);

result.add(
<String, dynamic>{
'order_id': orderId,
'remaining_distance_km': double.parse(
remaining.distanceKm.toStringAsFixed(2),
),
'estimated_arrival_min': remaining.timeMinutes,
},
);
}

return result;
}

_RemainingRoute _remainingRouteForOrder({
required Position position,
required String orderId,
}) {
final deliveryIndex = _optimizedSteps.indexWhere(
(step) =>
step['order_id']?.toString() == orderId &&
step['type'] == 'delivery',
);

if (deliveryIndex < 0 ||
deliveryIndex < _currentStepIndex) {
return const _RemainingRoute(
distanceKm: 0,
timeMinutes: 0,
);
}

double distanceKm = _currentSegmentDistanceKm;
int timeMinutes = _currentSegmentTimeMinutes;

if (distanceKm <= 0) {
final currentStep = _currentStep;

if (currentStep != null) {
distanceKm = _distanceToStep(
position,
currentStep,
) /
1000;

timeMinutes = _estimateMinutesByMode(
distanceKm,
);
}
}

for (int index = _currentStepIndex + 1;
index <= deliveryIndex;
index++) {
if (index >= _routeSegments.length) {
break;
}

distanceKm += _routeSegments[index].distanceKm;
timeMinutes += _routeSegments[index].durationMinutes;
}

return _RemainingRoute(
distanceKm: distanceKm,
timeMinutes: timeMinutes,
);
}

int _estimateMinutesByMode(
double distanceKm,
) {
if (distanceKm <= 0) {
return 0;
}

double averageSpeedKmH;

switch (_travelMode) {
case 'walking':
averageSpeedKmH = 5;
break;

case 'bicycling':
averageSpeedKmH = 15;
break;

case 'driving':
default:
averageSpeedKmH = 30;
break;
}

final minutes =
(distanceKm / averageSpeedKmH * 60).ceil();

return minutes < 1 ? 1 : minutes;
}

Future<void> _completeCurrentStep() async {
final step = _currentStep;

if (step == null ||
_processingStep ||
!_routeStarted) {
return;
}

if (_distanceToCurrentPointMeters >
_arrivalWarningRadiusMeters) {
final continueAnyway = await _showFarFromPointDialog();

if (!continueAnyway) {
return;
}
}

if (!mounted) {
return;
}

setState(() {
_processingStep = true;
});

try {
final isDelivery = step['type'] == 'delivery';

if (isDelivery) {
final orderId =
step['order_id']?.toString() ?? '';

if (orderId.isEmpty) {
throw Exception(
'Відсутній ID замовлення.',
);
}

await ApiService.deliverOrder(orderId);
}

final isLastStep =
_currentStepIndex >= _optimizedSteps.length - 1;

if (isLastStep) {
await _finishRoute();
return;
}

if (!mounted) {
return;
}

setState(() {
_currentStepIndex++;
_processingStep = false;

_polylines.removeWhere(
(polyline) =>
polyline.polylineId.value == 'active_segment',
);

final position = _currentPosition;

if (position != null) {
_distanceToCurrentPointMeters = _distanceToStep(
position,
_optimizedSteps[_currentStepIndex],
);
}

if (_currentStepIndex < _routeSegments.length) {
final segment = _routeSegments[_currentStepIndex];

_currentSegmentDistanceKm = segment.distanceKm;
_currentSegmentTimeMinutes =
segment.durationMinutes;
_navigationSteps = segment.navigationSteps;
}
});

_lastRoadRefreshAt = null;
_lastRoadRefreshPosition = null;

_refreshMarkers();
_focusCurrentStep();

final position = _currentPosition;

if (position != null) {
await _refreshCurrentSegmentRoute(
position,
force: true,
);

await _sendTrackingUpdate(
position,
force: true,
);
}

if (!mounted) {
return;
}

ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
behavior: SnackBarBehavior.floating,
content: Text(
isDelivery
? 'Замовлення доставлено. Переходимо до наступної точки.'
    : 'Відправлення забрано. Переходимо до наступної точки.',
),
),
);
} catch (error) {
if (!mounted) {
return;
}

setState(() {
_processingStep = false;
});

ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
behavior: SnackBarBehavior.floating,
backgroundColor: Colors.red,
content: Text(
'Не вдалося виконати точку: $error',
),
),
);
}
}

Future<bool> _showFarFromPointDialog() async {
final distanceText =
_distanceToCurrentPointMeters < 1000
? '${_distanceToCurrentPointMeters.round()} м'
    : '${(_distanceToCurrentPointMeters / 1000).toStringAsFixed(1)} км';

final result = await showDialog<bool>(
context: context,
builder: (dialogContext) {
return AlertDialog(
title: const Text(
'Ви далеко від точки',
),
content: Text(
'До поточної точки ще приблизно $distanceText. '
'Позначити її виконаною вручну?',
),
actions: [
TextButton(
onPressed: () {
Navigator.pop(dialogContext, false);
},
child: const Text('Скасувати'),
),
ElevatedButton(
onPressed: () {
Navigator.pop(dialogContext, true);
},
child: const Text('Продовжити'),
),
],
);
},
);

return result ?? false;
}

Future<void> _finishRoute() async {
await _positionSubscription?.cancel();
_positionSubscription = null;

await _locationService.stopTracking();

if (!mounted) {
return;
}

setState(() {
_routeFinished = true;
_routeStarted = false;
_processingStep = false;
_currentStepIndex = _optimizedSteps.length - 1;
});

_refreshMarkers();

await showDialog<void>(
context: context,
barrierDismissible: false,
builder: (dialogContext) {
return AlertDialog(
icon: const Icon(
Icons.task_alt_rounded,
size: 54,
color: Color(0xFF34C759),
),
title: const Text(
'Маршрут завершено',
textAlign: TextAlign.center,
),
content: const Text(
'Усі точки виконано, а замовлення переведено '
'у статус «Доставлено».',
textAlign: TextAlign.center,
),
actionsAlignment: MainAxisAlignment.center,
actions: [
ElevatedButton(
onPressed: () {
Navigator.pop(dialogContext);
},
child: const Text(
'Повернутися до замовлень',
),
),
],
);
},
);

if (!mounted) {
return;
}

Navigator.pop(context, true);
}

Future<void> _stopRoute() async {
await _positionSubscription?.cancel();
_positionSubscription = null;

await _locationService.stopTracking();

if (!mounted) {
return;
}

setState(() {
_routeStarted = false;
_processingStep = false;
});

_refreshMarkers();
}

double get _remainingDistanceKm {
if (_optimizedSteps.isEmpty ||
_currentStepIndex >= _optimizedSteps.length) {
return 0;
}

double result = _currentSegmentDistanceKm;

for (int index = _currentStepIndex + 1;
index < _routeSegments.length;
index++) {
result += _routeSegments[index].distanceKm;
}

return result;
}

int get _remainingTimeMinutes {
if (_optimizedSteps.isEmpty ||
_currentStepIndex >= _optimizedSteps.length) {
return 0;
}

int result = _currentSegmentTimeMinutes;

for (int index = _currentStepIndex + 1;
index < _routeSegments.length;
index++) {
result += _routeSegments[index].durationMinutes;
}

return result;
}

String get _nextInstruction {
if (_navigationSteps.isEmpty) {
return 'Продовжуйте рух до поточної точки.';
}

final instruction =
_navigationSteps.first['instruction']?.toString().trim();

if (instruction == null || instruction.isEmpty) {
return 'Продовжуйте рух до поточної точки.';
}

return instruction;
}

String get _nextInstructionDistance {
if (_navigationSteps.isEmpty) {
return '';
}

return _navigationSteps.first['distance_text']?.toString() ?? '';
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

Set<Marker> _createMarkers({
Position? currentPosition,
}) {
final result = <Marker>{};
final position = currentPosition ?? _currentPosition;

if (position != null) {
result.add(
Marker(
markerId: const MarkerId('courier_position'),
position: LatLng(
position.latitude,
position.longitude,
),
infoWindow: InfoWindow(
title: 'Поточна позиція кур’єра',
snippet:
'Точність GPS: ${position.accuracy.toStringAsFixed(0)} м',
),
icon: BitmapDescriptor.defaultMarkerWithHue(
BitmapDescriptor.hueYellow,
),
rotation: position.heading,
anchor: const Offset(0.5, 0.5),
),
);
}

for (int index = 0;
index < _optimizedSteps.length;
index++) {
final step = _optimizedSteps[index];

final isPickup = step['type'] == 'pickup';

final isCurrent =
_routeStarted && index == _currentStepIndex;

final isCompleted =
_routeFinished || index < _currentStepIndex;

double markerHue;

if (isCompleted) {
markerHue = BitmapDescriptor.hueViolet;
} else if (isCurrent) {
markerHue = BitmapDescriptor.hueGreen;
} else if (isPickup) {
markerHue = BitmapDescriptor.hueAzure;
} else {
markerHue = BitmapDescriptor.hueRed;
}

result.add(
Marker(
markerId: MarkerId(
step['node_id']?.toString() ?? 'step_$index',
),
position: LatLng(
_toDouble(step['lat']),
_toDouble(step['lng']),
),
infoWindow: InfoWindow(
title: isCurrent
? 'Поточна точка: ${step['label']}'
    : step['title']?.toString() ?? '',
snippet: step['address']?.toString() ?? '',
),
icon: BitmapDescriptor.defaultMarkerWithHue(
markerHue,
),
),
);
}

return result;
}

void _refreshMarkers() {
if (!mounted) {
return;
}

setState(() {
_markers = _createMarkers();
});
}

void _focusCurrentStep() {
final step = _currentStep;

if (step == null || _mapController == null) {
return;
}

_mapController?.animateCamera(
CameraUpdate.newCameraPosition(
CameraPosition(
target: LatLng(
_toDouble(step['lat']),
_toDouble(step['lng']),
),
zoom: 15.5,
),
),
);
}

void _focusCourier() {
final position = _currentPosition;

if (position == null || _mapController == null) {
return;
}

_mapController?.animateCamera(
CameraUpdate.newLatLngZoom(
LatLng(
position.latitude,
position.longitude,
),
16,
),
);
}

void _fitWholeRoute() {
if (_mapController == null || _optimizedSteps.isEmpty) {
return;
}

final points = <LatLng>[];

final position = _currentPosition;

if (position != null) {
points.add(
LatLng(
position.latitude,
position.longitude,
),
);
}

points.addAll(
_optimizedSteps.map(
(step) => LatLng(
_toDouble(step['lat']),
_toDouble(step['lng']),
),
),
);

if (points.isEmpty) {
return;
}

if (points.length == 1) {
_mapController?.animateCamera(
CameraUpdate.newLatLngZoom(
points.first,
15,
),
);

return;
}

double minLat = points.first.latitude;
double maxLat = points.first.latitude;
double minLng = points.first.longitude;
double maxLng = points.first.longitude;

for (final point in points) {
if (point.latitude < minLat) {
minLat = point.latitude;
}

if (point.latitude > maxLat) {
maxLat = point.latitude;
}

if (point.longitude < minLng) {
minLng = point.longitude;
}

if (point.longitude > maxLng) {
maxLng = point.longitude;
}
}

if ((maxLat - minLat).abs() < 0.0001) {
maxLat += 0.001;
minLat -= 0.001;
}

if ((maxLng - minLng).abs() < 0.0001) {
maxLng += 0.001;
minLng -= 0.001;
}

Future<void>.delayed(
const Duration(milliseconds: 300),
() {
if (!mounted || _mapController == null) {
return;
}

_mapController?.animateCamera(
CameraUpdate.newLatLngBounds(
LatLngBounds(
southwest: LatLng(minLat, minLng),
northeast: LatLng(maxLat, maxLng),
),
80,
),
);
},
);
}

String _distanceToPointText() {
if (_currentPosition == null || _optimizedSteps.isEmpty) {
return 'Відстань невідома';
}

if (_distanceToCurrentPointMeters < 1000) {
return '${_distanceToCurrentPointMeters.round()} м до точки';
}

return '${(_distanceToCurrentPointMeters / 1000).toStringAsFixed(1)} км до точки';
}

Widget _buildTravelModeSelector() {
final modes = <_TravelModeOption>[
const _TravelModeOption(
value: 'driving',
label: 'Авто',
icon: Icons.directions_car_rounded,
),
const _TravelModeOption(
value: 'bicycling',
label: 'Велосипед',
icon: Icons.directions_bike_rounded,
),
const _TravelModeOption(
value: 'walking',
label: 'Пішки',
icon: Icons.directions_walk_rounded,
),
];

return Wrap(
spacing: 8,
runSpacing: 8,
children: modes.map((option) {
final selected = option.value == _travelMode;

return ChoiceChip(
selected: selected,
onSelected: _routeStarted
? null
    : (value) {
if (value) {
_changeTravelMode(option.value);
}
},
avatar: Icon(
option.icon,
size: 17,
color: selected
? Colors.white
    : Theme.of(context).colorScheme.primary,
),
label: Text(option.label),
labelStyle: TextStyle(
fontSize: 12,
fontWeight: FontWeight.w700,
color: selected ? Colors.white : null,
),
selectedColor: Theme.of(context).colorScheme.primary,
showCheckmark: false,
);
}).toList(),
);
}

Widget _metricChip(
IconData icon,
String text,
) {
final theme = Theme.of(context);
final isDark = theme.brightness == Brightness.dark;

return Container(
padding: const EdgeInsets.symmetric(
horizontal: 11,
vertical: 7,
),
decoration: BoxDecoration(
color: isDark
? const Color(0xFF2C313F)
    : const Color(0xFFF3F5F8),
borderRadius: BorderRadius.circular(30),
),
child: Row(
mainAxisSize: MainAxisSize.min,
children: [
Icon(
icon,
size: 14,
color: theme.colorScheme.primary,
),
const SizedBox(width: 5),
Text(
text,
style: const TextStyle(
fontSize: 11.5,
fontWeight: FontWeight.bold,
),
),
],
),
);
}

Widget _buildSummaryCard() {
final theme = Theme.of(context);
final isDark = theme.brightness == Brightness.dark;
final step = _currentStep;

final displayedDistance =
_routeStarted ? _remainingDistanceKm : _totalDistanceKm;

final displayedTime =
_routeStarted ? _remainingTimeMinutes : _totalTimeMinutes;

String title = 'Маршрут підготовлено';

if (_routeStarted && step != null) {
title = step['title']?.toString() ?? 'Поточна точка';
}

if (_routeFinished) {
title = 'Маршрут завершено';
}

return Container(
width: double.infinity,
margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
padding: const EdgeInsets.all(18),
decoration: BoxDecoration(
color: isDark
? const Color(0xFF1E222D)
    : Colors.white,
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
Icon(
_travelModeIcon,
color: theme.colorScheme.primary,
),
const SizedBox(width: 9),
Expanded(
child: Text(
title,
style: const TextStyle(
fontSize: 16,
fontWeight: FontWeight.w800,
),
),
),
if (_routeStarted)
Container(
padding: const EdgeInsets.symmetric(
horizontal: 9,
vertical: 4,
),
decoration: BoxDecoration(
color: const Color(0xFF34C759)
    .withValues(alpha: 0.1),
borderRadius: BorderRadius.circular(20),
),
child: const Text(
'GPS онлайн',
style: TextStyle(
color: Color(0xFF34C759),
fontSize: 11,
fontWeight: FontWeight.bold,
),
),
),
],
),
const SizedBox(height: 14),
_buildTravelModeSelector(),
const SizedBox(height: 14),
Wrap(
spacing: 8,
runSpacing: 8,
children: [
_metricChip(
Icons.navigation_rounded,
'${displayedDistance.toStringAsFixed(1)} км',
),
_metricChip(
Icons.access_time_filled_rounded,
'$displayedTime хв',
),
_metricChip(
Icons.location_searching_rounded,
_distanceToPointText(),
),
],
),
if (_routeStarted) ...[
const SizedBox(height: 14),
Container(
width: double.infinity,
padding: const EdgeInsets.all(12),
decoration: BoxDecoration(
color: theme.colorScheme.primary
    .withValues(alpha: 0.08),
borderRadius: BorderRadius.circular(14),
),
child: Row(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Icon(
Icons.turn_right_rounded,
color: theme.colorScheme.primary,
),
const SizedBox(width: 10),
Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(
_nextInstruction,
style: const TextStyle(
fontSize: 13,
fontWeight: FontWeight.w700,
height: 1.35,
),
),
if (_nextInstructionDistance.isNotEmpty) ...[
const SizedBox(height: 3),
Text(
_nextInstructionDistance,
style: TextStyle(
fontSize: 11,
color: theme.hintColor,
),
),
],
],
),
),
],
),
),
],
if (_trackingWarning != null) ...[
const SizedBox(height: 10),
_warningBox(_trackingWarning!),
],
if (_routeWarning != null) ...[
const SizedBox(height: 10),
_warningBox(_routeWarning!),
],
const SizedBox(height: 16),
if (!_routeStarted && !_routeFinished)
SizedBox(
width: double.infinity,
height: 50,
child: ElevatedButton.icon(
onPressed: _startRoute,
icon: const Icon(Icons.play_arrow_rounded),
label: const Text(
'Почати маршрут',
style: TextStyle(
fontWeight: FontWeight.bold,
),
),
),
),
if (_routeStarted)
Row(
children: [
Expanded(
child: SizedBox(
height: 50,
child: ElevatedButton.icon(
onPressed: _processingStep
? null
    : _completeCurrentStep,
icon: _processingStep
? const SizedBox(
width: 18,
height: 18,
child: CircularProgressIndicator(
strokeWidth: 2,
color: Colors.white,
),
)
    : const Icon(
Icons.check_circle_rounded,
),
label: Text(
_processingStep
? 'Обробка...'
    : step?['type'] == 'pickup'
? 'Відправлення забрано'
    : 'Замовлення доставлено',
),
style: ElevatedButton.styleFrom(
backgroundColor:
const Color(0xFF34C759),
foregroundColor: Colors.white,
),
),
),
),
const SizedBox(width: 8),
IconButton.filledTonal(
tooltip: 'Зупинити маршрут',
onPressed:
_processingStep ? null : _stopRoute,
icon: const Icon(Icons.stop_rounded),
),
],
),
],
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
fontSize: 11.5,
),
),
);
}

Widget _buildStepCard(
Map<String, dynamic> step,
int index,
) {
final theme = Theme.of(context);
final isDark = theme.brightness == Brightness.dark;

final current =
_routeStarted && index == _currentStepIndex;

final completed =
_routeFinished || index < _currentStepIndex;

final isPickup = step['type'] == 'pickup';

final color = completed
? Colors.grey
    : current
? const Color(0xFF34C759)
    : isPickup
? const Color(0xFF007AFF)
    : const Color(0xFFFF3B30);

return Container(
margin: const EdgeInsets.only(bottom: 8),
decoration: BoxDecoration(
color: current
? const Color(0xFF34C759).withValues(
alpha: isDark ? 0.15 : 0.06,
)
    : isDark
? const Color(0xFF1E222D)
    : Colors.white,
borderRadius: BorderRadius.circular(16),
border: Border.all(
color: current
? const Color(0xFF34C759)
    : isDark
? Colors.white.withValues(alpha: 0.05)
    : Colors.black.withValues(alpha: 0.03),
),
),
child: ListTile(
onTap: () {
_mapController?.animateCamera(
CameraUpdate.newLatLngZoom(
LatLng(
_toDouble(step['lat']),
_toDouble(step['lng']),
),
16,
),
);
},
leading: CircleAvatar(
radius: 17,
backgroundColor: color,
child: Text(
step['label']?.toString() ?? '',
style: const TextStyle(
color: Colors.white,
fontSize: 10,
fontWeight: FontWeight.bold,
),
),
),
title: Text(
step['title']?.toString() ?? '',
style: TextStyle(
fontSize: 13,
fontWeight: FontWeight.bold,
color: completed ? theme.hintColor : null,
decoration:
completed ? TextDecoration.lineThrough : null,
),
),
subtitle: Text(
step['address']?.toString() ?? '',
maxLines: 1,
overflow: TextOverflow.ellipsis,
style: TextStyle(
fontSize: 11.5,
color: theme.hintColor,
),
),
trailing: Icon(
completed
? Icons.check_circle_rounded
    : isPickup
? Icons.inventory_2_rounded
    : Icons.location_on_rounded,
color: color,
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
Icons.location_off_rounded,
size: 66,
color: Colors.orange,
),
const SizedBox(height: 18),
const Text(
'Не вдалося побудувати маршрут',
style: TextStyle(
fontSize: 19,
fontWeight: FontWeight.bold,
),
textAlign: TextAlign.center,
),
const SizedBox(height: 10),
Text(
_errorMessage ?? 'Невідома помилка',
textAlign: TextAlign.center,
),
const SizedBox(height: 20),
ElevatedButton.icon(
onPressed: _initializeRoute,
icon: const Icon(Icons.refresh_rounded),
label: const Text('Повторити'),
),
],
),
),
);
}

@override
void dispose() {
unawaited(_positionSubscription?.cancel());
unawaited(_locationService.stopTracking());

_mapController?.dispose();

super.dispose();
}

@override
Widget build(BuildContext context) {
final theme = Theme.of(context);
final isDark = theme.brightness == Brightness.dark;

final initialPosition = _currentPosition != null
? LatLng(
_currentPosition!.latitude,
_currentPosition!.longitude,
)
    : _optimizedSteps.isNotEmpty
? LatLng(
_toDouble(_optimizedSteps.first['lat']),
_toDouble(_optimizedSteps.first['lng']),
)
    : const LatLng(50.6199, 26.2516);

return Scaffold(
backgroundColor: isDark
? const Color(0xFF13151A)
    : const Color(0xFFF8F9FD),
appBar: AppBar(
elevation: 0,
backgroundColor: Colors.transparent,
foregroundColor: theme.textTheme.titleLarge?.color,
title: const Text(
'Оптимізований маршрут',
style: TextStyle(
fontSize: 18,
fontWeight: FontWeight.bold,
),
),
),
body: _loading
? const Center(
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
CircularProgressIndicator(),
SizedBox(height: 14),
Text(
'Отримуємо GPS і будуємо маршрут...',
),
],
),
)
    : _errorMessage != null && _optimizedSteps.isEmpty
? _buildErrorScreen()
    : Column(
children: [
_buildSummaryCard(),
Expanded(
flex: 3,
child: Container(
margin: const EdgeInsets.symmetric(
horizontal: 16,
),
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(22),
),
child: ClipRRect(
borderRadius: BorderRadius.circular(22),
child: Stack(
children: [
GoogleMap(
initialCameraPosition:
CameraPosition(
target: initialPosition,
zoom: 13,
),
markers: _markers,
polylines: _polylines,
myLocationEnabled: true,
myLocationButtonEnabled: false,
zoomControlsEnabled: false,
compassEnabled: true,
trafficEnabled:
_travelMode == 'driving',
mapToolbarEnabled: true,
onMapCreated: (controller) {
_mapController = controller;
_refreshMarkers();
_fitWholeRoute();
},
),
Positioned(
top: 12,
right: 12,
child: Column(
children: [
FloatingActionButton.small(
heroTag:
'courier_location',
onPressed: _focusCourier,
child: const Icon(
Icons.my_location_rounded,
),
),
const SizedBox(height: 8),
FloatingActionButton.small(
heroTag: 'whole_route',
onPressed: _fitWholeRoute,
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
Expanded(
flex: 2,
child: Padding(
padding: const EdgeInsets.all(16),
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
const Text(
'Порядок проходження точок',
style: TextStyle(
fontSize: 14,
fontWeight: FontWeight.bold,
),
),
const SizedBox(height: 8),
Expanded(
child: ListView.builder(
itemCount: _optimizedSteps.length,
itemBuilder: (context, index) {
return _buildStepCard(
_optimizedSteps[index],
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

class _TravelModeOption {
final String value;
final String label;
final IconData icon;

const _TravelModeOption({
required this.value,
required this.label,
required this.icon,
});
}

class _RouteSegment {
final int index;
final List<LatLng> points;
final double distanceKm;
final int durationMinutes;
final List<Map<String, dynamic>> navigationSteps;

const _RouteSegment({
required this.index,
required this.points,
required this.distanceKm,
required this.durationMinutes,
required this.navigationSteps,
});
}

class _RouteBuildResult {
final Set<Polyline> polylines;
final List<_RouteSegment> segments;
final double distanceKm;
final int timeMinutes;

const _RouteBuildResult({
required this.polylines,
required this.segments,
required this.distanceKm,
required this.timeMinutes,
});
}

class _RemainingRoute {
final double distanceKm;
final int timeMinutes;

const _RemainingRoute({
required this.distanceKm,
required this.timeMinutes,
});
}

