import 'dart:async';

import 'package:geolocator/geolocator.dart';

class LocationServiceException implements Exception {
final String message;

const LocationServiceException(this.message);

@override
String toString() => message;
}

class LocationService {
LocationService._();

static final LocationService instance = LocationService._();

StreamSubscription<Position>? _positionSubscription;

final StreamController<Position> _positionController =
StreamController<Position>.broadcast();

Position? _lastPosition;
bool _isTracking = false;

Stream<Position> get positionStream => _positionController.stream;

Position? get lastPosition => _lastPosition;

bool get isTracking => _isTracking;

Future<void> ensureLocationReady() async {
final serviceEnabled =
await Geolocator.isLocationServiceEnabled();

if (!serviceEnabled) {
throw const LocationServiceException(
'Геолокацію вимкнено. Увімкніть GPS у налаштуваннях телефону.',
);
}

var permission = await Geolocator.checkPermission();

if (permission == LocationPermission.denied) {
permission = await Geolocator.requestPermission();
}

if (permission == LocationPermission.denied) {
throw const LocationServiceException(
'Доступ до геолокації не надано.',
);
}

if (permission == LocationPermission.deniedForever) {
throw const LocationServiceException(
'Доступ до геолокації заборонено назавжди. '
'Відкрийте налаштування застосунку та дозвольте геолокацію.',
);
}
}

Future<Position> getCurrentPosition() async {
await ensureLocationReady();

try {
final locationSettings = AndroidSettings(
accuracy: LocationAccuracy.bestForNavigation,
distanceFilter: 0,
timeLimit: const Duration(seconds: 25),
);

final position = await Geolocator.getCurrentPosition(
locationSettings: locationSettings,
);

_lastPosition = position;

return position;
} on TimeoutException {
throw const LocationServiceException(
'Не вдалося отримати GPS-координати за відведений час.',
);
} catch (error) {
if (error is LocationServiceException) {
rethrow;
}

throw LocationServiceException(
'Помилка отримання геолокації: $error',
);
}
}

Future<void> startTracking({
int distanceFilter = 8,
Duration interval = const Duration(seconds: 5),
}) async {
await ensureLocationReady();

await stopTracking();

final locationSettings = AndroidSettings(
accuracy: LocationAccuracy.bestForNavigation,
distanceFilter: distanceFilter,
intervalDuration: interval,
);

_isTracking = true;

_positionSubscription = Geolocator.getPositionStream(
locationSettings: locationSettings,
).listen(
(Position position) {
_lastPosition = position;

if (!_positionController.isClosed) {
_positionController.add(position);
}
},
onError: (Object error, StackTrace stackTrace) {
_isTracking = false;

if (!_positionController.isClosed) {
_positionController.addError(
LocationServiceException(
'Помилка GPS-відстеження: $error',
),
stackTrace,
);
}
},
onDone: () {
_isTracking = false;
},
cancelOnError: false,
);
}

Future<void> stopTracking() async {
final subscription = _positionSubscription;

_positionSubscription = null;
_isTracking = false;

if (subscription != null) {
await subscription.cancel();
}
}

double distanceFromCurrentPosition({
required double destinationLatitude,
required double destinationLongitude,
}) {
final position = _lastPosition;

if (position == null) {
return double.infinity;
}

return Geolocator.distanceBetween(
position.latitude,
position.longitude,
destinationLatitude,
destinationLongitude,
);
}

bool isWithinRadius({
required double destinationLatitude,
required double destinationLongitude,
double radiusMeters = 50,
}) {
final distance = distanceFromCurrentPosition(
destinationLatitude: destinationLatitude,
destinationLongitude: destinationLongitude,
);

return distance <= radiusMeters;
}

Future<bool> openLocationSettings() {
return Geolocator.openLocationSettings();
}

Future<bool> openAppSettings() {
return Geolocator.openAppSettings();
}

Future<void> dispose() async {
await stopTracking();

if (!_positionController.isClosed) {
await _positionController.close();
}
}
}

