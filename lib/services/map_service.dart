import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import 'maps_config.dart';

class MapServiceException implements Exception {
final String message;

const MapServiceException(this.message);

@override
String toString() => message;
}

class MapService {
MapService._();

static final http.Client _client = http.Client();

static const Duration _requestTimeout =
Duration(seconds: 25);

static const int _maximumCachedRoutes = 40;

static final LinkedHashMap<String, _CachedRoute>
_routeCache = LinkedHashMap<String, _CachedRoute>();

static final Map<String, Future<Map<String, dynamic>>>
_inFlightRoutes =
<String, Future<Map<String, dynamic>>>{};

static const Set<String> supportedTravelModes =
<String>{
'driving',
'walking',
'bicycling',
};

static String get _apiKey {
final value = MapsConfig.apiKey.trim();

if (value.isEmpty ||
value ==
'ТУТ_ВСТАВ_СВІЙ_GOOGLE_MAPS_API_KEY') {
throw const MapServiceException(
'Google Maps API key не налаштований.',
);
}

return value;
}

// ---------------------------------------------------------------------------
// Режими пересування
// ---------------------------------------------------------------------------

static String normalizeTravelMode(
String? value,
) {
final mode = value?.trim().toLowerCase();

switch (mode) {
case 'drive':
case 'car':
case 'auto':
case 'автомобіль':
return 'driving';

case 'walk':
case 'foot':
case 'пішки':
return 'walking';

case 'bike':
case 'bicycle':
case 'велосипед':
return 'bicycling';

case 'driving':
case 'walking':
case 'bicycling':
return mode!;

default:
return 'driving';
}
}

static String travelModeLabel(
String? value,
) {
switch (normalizeTravelMode(value)) {
case 'walking':
return 'Пішки';

case 'bicycling':
return 'Велосипедом';

case 'driving':
default:
return 'Автомобілем';
}
}

static IconTravelModeData travelModeData(
String? value,
) {
switch (normalizeTravelMode(value)) {
case 'walking':
return const IconTravelModeData(
mode: 'walking',
label: 'Пішки',
);

case 'bicycling':
return const IconTravelModeData(
mode: 'bicycling',
label: 'Велосипедом',
);

case 'driving':
default:
return const IconTravelModeData(
mode: 'driving',
label: 'Автомобілем',
);
}
}

// ---------------------------------------------------------------------------
// Автодоповнення адрес
// ---------------------------------------------------------------------------

static Future<List<Map<String, dynamic>>>
autocompleteAddress(
String input,
) async {
final normalizedInput = input.trim();

if (normalizedInput.length < 3) {
return <Map<String, dynamic>>[];
}

final uri = Uri.https(
'maps.googleapis.com',
'/maps/api/place/autocomplete/json',
<String, String>{
'input': normalizedInput,
'key': _apiKey,
'language': 'uk',
'components': 'country:ua',
'types': 'address',
},
);

final data = await _getJson(uri);

final status =
data['status']?.toString() ?? '';

if (status == 'ZERO_RESULTS') {
return <Map<String, dynamic>>[];
}

_checkGoogleStatus(
data,
operation:
'Не вдалося знайти адреси',
);

final predictions = data['predictions'];

if (predictions is! List) {
return <Map<String, dynamic>>[];
}

return predictions
    .whereType<Map>()
    .map(
(item) {
final prediction =
Map<String, dynamic>.from(item);

return <String, dynamic>{
'description':
prediction['description']
    ?.toString() ??
'',
'place_id':
prediction['place_id']
    ?.toString() ??
'',
'main_text': _nestedString(
prediction,
'structured_formatting',
'main_text',
),
'secondary_text': _nestedString(
prediction,
'structured_formatting',
'secondary_text',
),
};
},
)
    .where(
(item) =>
item['place_id']
    .toString()
    .trim()
    .isNotEmpty,
)
    .toList();
}

// ---------------------------------------------------------------------------
// Детальна інформація про адресу
// ---------------------------------------------------------------------------

static Future<Map<String, dynamic>>
getPlaceDetails(
String placeId,
) async {
final normalizedPlaceId = placeId.trim();

if (normalizedPlaceId.isEmpty) {
throw const MapServiceException(
'Не вказано ідентифікатор адреси.',
);
}

final uri = Uri.https(
'maps.googleapis.com',
'/maps/api/place/details/json',
<String, String>{
'place_id': normalizedPlaceId,
'key': _apiKey,
'language': 'uk',
'fields':
'formatted_address,name,geometry',
},
);

final data = await _getJson(uri);

_checkGoogleStatus(
data,
operation:
'Не вдалося отримати дані адреси',
);

final result = _asMap(data['result']);
final geometry = _asMap(
result['geometry'],
);
final location = _asMap(
geometry['location'],
);

final latitude = _toDouble(
location['lat'],
);
final longitude = _toDouble(
location['lng'],
);

if (!_validCoordinates(
latitude,
longitude,
)) {
throw const MapServiceException(
'Google Maps не повернув координати адреси.',
);
}

final formattedAddress =
result['formatted_address']
    ?.toString()
    .trim();

final name = result['name']
    ?.toString()
    .trim();

return <String, dynamic>{
'address':
formattedAddress?.isNotEmpty == true
? formattedAddress
    : name ?? '',
'lat': latitude,
'lng': longitude,
};
}

// ---------------------------------------------------------------------------
// Геокодування текстової адреси
// ---------------------------------------------------------------------------

static Future<LatLng> geocodeAddress(
String address,
) async {
final normalizedAddress = address.trim();

if (normalizedAddress.isEmpty) {
throw const MapServiceException(
'Адреса для пошуку не вказана.',
);
}

final uri = Uri.https(
'maps.googleapis.com',
'/maps/api/geocode/json',
<String, String>{
'address': normalizedAddress,
'key': _apiKey,
'language': 'uk',
'region': 'ua',
},
);

final data = await _getJson(uri);

final status =
data['status']?.toString() ?? '';

if (status == 'ZERO_RESULTS') {
throw const MapServiceException(
'Не вдалося знайти координати цієї адреси.',
);
}

_checkGoogleStatus(
data,
operation:
'Не вдалося визначити координати адреси',
);

final results = data['results'];

if (results is! List ||
results.isEmpty) {
throw const MapServiceException(
'Google Maps не повернув результат геокодування.',
);
}

final firstResult =
_asMap(results.first);
final geometry = _asMap(
firstResult['geometry'],
);
final location = _asMap(
geometry['location'],
);

final latitude = _toDouble(
location['lat'],
);
final longitude = _toDouble(
location['lng'],
);

if (!_validCoordinates(
latitude,
longitude,
)) {
throw const MapServiceException(
'Отримано некоректні координати адреси.',
);
}

return LatLng(
latitude,
longitude,
);
}

// ---------------------------------------------------------------------------
// Повна інформація про маршрут
// ---------------------------------------------------------------------------

static Future<Map<String, dynamic>>
getRouteDetails({
required double originLat,
required double originLng,
required double destinationLat,
required double destinationLng,
String travelMode = 'driving',
bool forceRefresh = false,
}) async {
if (!_validCoordinates(
originLat,
originLng,
) ||
!_validCoordinates(
destinationLat,
destinationLng,
)) {
throw const MapServiceException(
'Для маршруту передано некоректні координати.',
);
}

final normalizedMode =
normalizeTravelMode(travelMode);

final cacheKey = _routeCacheKey(
originLat: originLat,
originLng: originLng,
destinationLat: destinationLat,
destinationLng: destinationLng,
travelMode: normalizedMode,
);

if (!forceRefresh) {
final cached =
_readRouteFromCache(cacheKey);

if (cached != null) {
return cached;
}
}

final activeRequest =
_inFlightRoutes[cacheKey];

if (activeRequest != null) {
return activeRequest;
}
final request = _fetchRouteDetails(
originLat: originLat,
originLng: originLng,
destinationLat: destinationLat,
destinationLng: destinationLng,
travelMode: normalizedMode,
);
_inFlightRoutes[cacheKey] = request;
try {
final result = await request;
_storeRouteInCache(
cacheKey,
result,
travelMode: normalizedMode,
);

return result;
} finally {
_inFlightRoutes.remove(cacheKey);
}
}

static Future<Map<String, dynamic>>
_fetchRouteDetails({
required double originLat,
required double originLng,
required double destinationLat,
required double destinationLng,
required String travelMode,
}) async {
final query = <String, String>{
'origin': '$originLat,$originLng',
'destination':
'$destinationLat,$destinationLng',
'mode': travelMode,
'language': 'uk',
'region': 'ua',
'units': 'metric',
'alternatives': 'false',
'key': _apiKey,
};
if (travelMode == 'driving') {
query['departure_time'] = 'now';
query['traffic_model'] =
'best_guess';
}
final uri = Uri.https(
'maps.googleapis.com',
'/maps/api/directions/json',
query,
);

final data = await _getJson(uri);
final status =
data['status']?.toString() ?? '';
if (status == 'ZERO_RESULTS') {
throw MapServiceException(
'Не знайдено маршрут для режиму «${travelModeLabel(travelMode)}».',
);
}
_checkGoogleStatus(
data,
operation:
'Не вдалося побудувати маршрут',
);
final routes = data['routes'];
if (routes is! List ||
routes.isEmpty) {
throw const MapServiceException(
'Google Maps не повернув маршрут.',
);
}
final route = _asMap(
routes.first,
);
final legs = route['legs'];
if (legs is! List ||
legs.isEmpty) {
throw const MapServiceException(
'Маршрут не містить інформації про відстань і час.',
);
}

final leg = _asMap(
legs.first,
);
final distance = _asMap(
leg['distance'],
);
final regularDuration = _asMap(
leg['duration'],
);
final trafficDuration = _asMap(
leg['duration_in_traffic'],
);
final selectedDuration =
travelMode == 'driving' &&
trafficDuration.isNotEmpty
? trafficDuration
    : regularDuration;
final overviewPolyline = _asMap(
route['overview_polyline'],
);
final encodedPolyline =
overviewPolyline['points']
    ?.toString() ??
'';
final decodedPoints =
encodedPolyline.isEmpty
? <LatLng>[
LatLng(
originLat,
originLng,
),
LatLng(
destinationLat,
destinationLng,
),
]
    : _decodePolyline(
encodedPolyline,
);
final bounds = _asMap(
route['bounds'],
);
return <String, dynamic>{
'points': decodedPoints,
'distance_meters': _toInt(
distance['value'],
),
'distance_text':
distance['text']?.toString() ??
'',
'duration_seconds': _toInt(
selectedDuration['value'],
),
'duration_text':
selectedDuration['text']
    ?.toString() ??
'',
'regular_duration_seconds':
_toInt(
regularDuration['value'],
),
'travel_mode': travelMode,
'travel_mode_label':
travelModeLabel(travelMode),
'start_address':
leg['start_address']
    ?.toString() ??
'',
'end_address':
leg['end_address']
    ?.toString() ??
'',
'steps': _parseRouteSteps(
leg['steps'],
),
'bounds': _parseBounds(
bounds,
),
'copyrights':
route['copyrights']
    ?.toString() ??
'',
'summary':
route['summary']?.toString() ??
'',
};
}

// ---------------------------------------------------------------------------
// Сумісність зі старими екранами
// ---------------------------------------------------------------------------

static Future<List<LatLng>>
getRoutePolyline({
required double originLat,
required double originLng,
required double destinationLat,
required double destinationLng,
String travelMode = 'driving',
bool forceRefresh = false,
}) async {
final details =
await getRouteDetails(
originLat: originLat,
originLng: originLng,
destinationLat: destinationLat,
destinationLng: destinationLng,
travelMode: travelMode,
forceRefresh: forceRefresh,
);

final points = details['points'];

if (points is List<LatLng>) {
return points;
}

if (points is List) {
return points
    .whereType<LatLng>()
    .toList();
}

return <LatLng>[
LatLng(
originLat,
originLng,
),
LatLng(
destinationLat,
destinationLng,
),
];
}

static Future<Map<String, dynamic>>
getRouteInfo({
required double originLat,
required double originLng,
required double destinationLat,
required double destinationLng,
String travelMode = 'driving',
bool forceRefresh = false,
}) async {
final details =
await getRouteDetails(
originLat: originLat,
originLng: originLng,
destinationLat: destinationLat,
destinationLng: destinationLng,
travelMode: travelMode,
forceRefresh: forceRefresh,
);

final distanceMeters =
_toInt(
details['distance_meters'],
);

final durationSeconds =
_toInt(
details['duration_seconds'],
);

return <String, dynamic>{
'distance_meters':
distanceMeters,
'distance_km':
distanceMeters / 1000,
'distance_text':
details['distance_text']
    ?.toString() ??
'',
'duration_seconds':
durationSeconds,
'duration_minutes':
(durationSeconds / 60).ceil(),
'duration_text':
details['duration_text']
    ?.toString() ??
'',
'travel_mode':
details['travel_mode']
    ?.toString() ??
normalizeTravelMode(
travelMode,
),
'travel_mode_label':
details['travel_mode_label']
    ?.toString() ??
travelModeLabel(
travelMode,
),
'steps':
details['steps'] is List
? details['steps']
    : <dynamic>[],
};
}

// ---------------------------------------------------------------------------
// Кроки навігації
// ---------------------------------------------------------------------------

static List<Map<String, dynamic>>
_parseRouteSteps(
dynamic rawSteps,
) {
if (rawSteps is! List) {
return <Map<String, dynamic>>[];
}

return rawSteps
    .whereType<Map>()
    .map(
(item) {
final step =
Map<String, dynamic>.from(
item,
);

final distance = _asMap(
step['distance'],
);

final duration = _asMap(
step['duration'],
);

final startLocation =
_asMap(
step['start_location'],
);

final endLocation =
_asMap(
step['end_location'],
);

final polyline = _asMap(
step['polyline'],
);

return <String, dynamic>{
'instruction':
_plainInstruction(
step['html_instructions']
    ?.toString() ??
'',
),
'maneuver':
step['maneuver']
    ?.toString() ??
'',
'distance_meters':
_toInt(
distance['value'],
),
'distance_text':
distance['text']
    ?.toString() ??
'',
'duration_seconds':
_toInt(
duration['value'],
),
'duration_text':
duration['text']
    ?.toString() ??
'',
'start_lat':
_toDouble(
startLocation['lat'],
),
'start_lng':
_toDouble(
startLocation['lng'],
),
'end_lat':
_toDouble(
endLocation['lat'],
),
'end_lng':
_toDouble(
endLocation['lng'],
),
'points': _decodePolyline(
polyline['points']
    ?.toString() ??
'',
),
};
},
)
    .toList();
}

static String _plainInstruction(
String html,
) {
if (html.trim().isEmpty) {
return '';
}

var result = html.replaceAll(
RegExp(r'<[^>]*>'),
' ',
);

result = result
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>');

result = result.replaceAll(
RegExp(r'\s+'),
' ',
);

return result.trim();
}

// ---------------------------------------------------------------------------
// Кешування маршрутів
// ---------------------------------------------------------------------------

static Map<String, dynamic>?
_readRouteFromCache(
String key,
) {
final cached =
_routeCache[key];

if (cached == null) {
return null;
}

if (DateTime.now().isAfter(
cached.expiresAt,
)) {
_routeCache.remove(key);
return null;
}

// Переміщуємо використаний елемент у кінець,
// щоб реалізувати обмежений LRU-кеш.
_routeCache.remove(key);
_routeCache[key] = cached;

return cached.data;
}

static void _storeRouteInCache(
String key,
Map<String, dynamic> data, {
required String travelMode,
}) {
final cacheDuration =
travelMode == 'driving'
? const Duration(
seconds: 90,
)
    : const Duration(
minutes: 10,
);

_routeCache.remove(key);

_routeCache[key] = _CachedRoute(
data: data,
expiresAt: DateTime.now().add(
cacheDuration,
),
);

while (_routeCache.length >
_maximumCachedRoutes) {
_routeCache.remove(
_routeCache.keys.first,
);
}
}

static String _routeCacheKey({
required double originLat,
required double originLng,
required double destinationLat,
required double destinationLng,
required String travelMode,
}) {
return [
originLat.toStringAsFixed(5),
originLng.toStringAsFixed(5),
destinationLat.toStringAsFixed(5),
destinationLng.toStringAsFixed(5),
travelMode,
].join('|');
}

static void clearRouteCache() {
_routeCache.clear();
_inFlightRoutes.clear();
}

// ---------------------------------------------------------------------------
// HTTP та обробка Google Maps
// ---------------------------------------------------------------------------

static Future<Map<String, dynamic>>
_getJson(
Uri uri,
) async {
try {
final response = await _client
    .get(
uri,
headers: const <String, String>{
'Accept': 'application/json',
},
)
    .timeout(
_requestTimeout,
);

if (response.statusCode < 200 ||
response.statusCode >= 300) {
throw MapServiceException(
'Google Maps повернув HTTP ${response.statusCode}.',
);
}

final decoded = jsonDecode(
response.body,
);

if (decoded is! Map) {
throw const MapServiceException(
'Google Maps повернув некоректну відповідь.',
);
}

return Map<String, dynamic>.from(
decoded,
);
} on TimeoutException {
throw const MapServiceException(
'Google Maps не відповідає. Перевірте інтернет-з’єднання.',
);
} on MapServiceException {
rethrow;
} on FormatException {
throw const MapServiceException(
'Не вдалося прочитати відповідь Google Maps.',
);
} catch (error) {
throw MapServiceException(
'Помилка підключення до Google Maps: $error',
);
}
}

static void _checkGoogleStatus(
Map<String, dynamic> data, {
required String operation,
}) {
final status =
data['status']?.toString() ?? '';

if (status == 'OK') {
return;
}

final serverMessage =
data['error_message']
    ?.toString()
    .trim();

switch (status) {
case 'REQUEST_DENIED':
throw MapServiceException(
serverMessage?.isNotEmpty == true
? '$operation: $serverMessage'
    : '$operation: запит відхилено. Перевірте API key і підключені Google API.',
);

case 'OVER_DAILY_LIMIT':
case 'OVER_QUERY_LIMIT':
throw MapServiceException(
'$operation: перевищено ліміт Google Maps API.',
);

case 'INVALID_REQUEST':
throw MapServiceException(
'$operation: передано неповні або некоректні дані.',
);

case 'UNKNOWN_ERROR':
throw MapServiceException(
'$operation: тимчасова помилка Google Maps.',
);

default:
throw MapServiceException(
serverMessage?.isNotEmpty == true
? '$operation: $serverMessage'
    : '$operation. Статус Google Maps: $status.',
);
}
}

// ---------------------------------------------------------------------------
// Допоміжні методи
// ---------------------------------------------------------------------------

static Map<String, dynamic> _asMap(
dynamic value,
) {
if (value is Map<String, dynamic>) {
return value;
}

if (value is Map) {
return Map<String, dynamic>.from(
value,
);
}

return <String, dynamic>{};
}

static String _nestedString(
Map<String, dynamic> source,
String firstKey,
String secondKey,
) {
final nested = _asMap(
source[firstKey],
);

return nested[secondKey]
    ?.toString() ??
'';
}

static double _toDouble(
dynamic value,
) {
if (value is double) {
return value;
}

if (value is num) {
return value.toDouble();
}

return double.tryParse(
value?.toString() ?? '',
) ??
0;
}

static int _toInt(
dynamic value,
) {
if (value is int) {
return value;
}

if (value is num) {
return value.round();
}

return double.tryParse(
value?.toString() ?? '',
)
    ?.round() ??
0;
}

static bool _validCoordinates(
double latitude,
double longitude,
) {
if (!latitude.isFinite ||
!longitude.isFinite) {
return false;
}

if (latitude < -90 ||
latitude > 90) {
return false;
}

if (longitude < -180 ||
longitude > 180) {
return false;
}

return latitude != 0 ||
longitude != 0;
}

static Map<String, dynamic> _parseBounds(
Map<String, dynamic> bounds,
) {
final northeast = _asMap(
bounds['northeast'],
);

final southwest = _asMap(
bounds['southwest'],
);

return <String, dynamic>{
'northeast_lat':
_toDouble(
northeast['lat'],
),
'northeast_lng':
_toDouble(
northeast['lng'],
),
'southwest_lat':
_toDouble(
southwest['lat'],
),
'southwest_lng':
_toDouble(
southwest['lng'],
),
};
}

static List<LatLng> _decodePolyline(
String encoded,
) {
if (encoded.isEmpty) {
return <LatLng>[];
}

final points = <LatLng>[];

int index = 0;
int latitude = 0;
int longitude = 0;

while (index < encoded.length) {
int result = 0;
int shift = 0;
int byte;

do {
byte =
encoded.codeUnitAt(index++) -
63;

result |=
(byte & 0x1F) << shift;

shift += 5;
} while (byte >= 0x20 &&
index < encoded.length);

final latitudeDelta =
(result & 1) != 0
? ~(result >> 1)
    : result >> 1;

latitude += latitudeDelta;

result = 0;
shift = 0;

do {
byte =
encoded.codeUnitAt(index++) -
63;

result |=
(byte & 0x1F) << shift;

shift += 5;
} while (byte >= 0x20 &&
index < encoded.length);

final longitudeDelta =
(result & 1) != 0
? ~(result >> 1)
    : result >> 1;

longitude += longitudeDelta;

points.add(
LatLng(
latitude / 100000,
longitude / 100000,
),
);
}

return points;
}

/// Викликати лише під час остаточного
/// завершення роботи застосунку.
static void dispose() {
clearRouteCache();
_client.close();
}
}

class IconTravelModeData {
final String mode;
final String label;

const IconTravelModeData({
required this.mode,
required this.label,
});
}

class _CachedRoute {
final Map<String, dynamic> data;
final DateTime expiresAt;

const _CachedRoute({
required this.data,
required this.expiresAt,
});
}

