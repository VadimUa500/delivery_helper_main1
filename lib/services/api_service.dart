import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
final String message;
final int? statusCode;

const ApiException(
this.message, {
this.statusCode,
});

@override
String toString() => message;
}

class ApiService {
ApiService._();

/// Адреса Flask-сервера.
///
/// Для Android-емулятора та сервера на цьому ж комп'ютері
/// часто використовується:
/// http://10.0.2.2:5000
///
/// Зараз залишена адреса, яка була у твоєму проєкті.
static const String _configuredBaseUrl = String.fromEnvironment(
'API_BASE_URL',
defaultValue: 'http://10.243.33.146:5000',
);

static const Duration _requestTimeout = Duration(seconds: 25);

static final http.Client _client = http.Client();

static String get baseUrl {
final value = _configuredBaseUrl.trim();

if (value.endsWith('/')) {
return value.substring(0, value.length - 1);
}

return value;
}

// ---------------------------------------------------------------------------
// Сесія та JWT
// ---------------------------------------------------------------------------

/// Шукає JWT-токен у SharedPreferences.
///
/// Перевіряються декілька поширених назв,
/// щоб сервіс працював із поточним AuthStorage.
static Future<String?> _getToken() async {
final preferences = await SharedPreferences.getInstance();

const possibleKeys = <String>[
'token',
'access_token',
'jwt_token',
'auth_token',
];

for (final key in possibleKeys) {
final value = preferences.getString(key)?.trim();

if (value != null && value.isNotEmpty) {
return value;
}
}

// Додаткова перевірка на випадок, якщо AuthStorage
// використовує іншу назву ключа.
for (final key in preferences.getKeys()) {
final value = preferences.get(key);

if (value is String && _looksLikeJwt(value)) {
return value.trim();
}
}

return null;
}

static bool _looksLikeJwt(String value) {
final parts = value.trim().split('.');
return parts.length == 3;
}

static Future<Map<String, String>> _headers({
required bool authorized,
}) async {
final headers = <String, String>{
'Accept': 'application/json',
'Content-Type': 'application/json; charset=UTF-8',
};

if (authorized) {
final token = await _getToken();

if (token == null || token.isEmpty) {
throw const ApiException(
'Авторизаційний токен відсутній. Увійдіть у систему повторно.',
statusCode: 401,
);
}

headers['Authorization'] = 'Bearer $token';
}

return headers;
}

// ---------------------------------------------------------------------------
// Загальна обробка HTTP
// ---------------------------------------------------------------------------

static Future<dynamic> _request({
required String method,
required String path,
bool authorized = true,
Map<String, dynamic>? body,
Map<String, String>? queryParameters,
}) async {
final uri = Uri.parse('$baseUrl$path').replace(
queryParameters: queryParameters == null || queryParameters.isEmpty
? null
    : queryParameters,
);

final request = http.Request(method, uri);

request.headers.addAll(
await _headers(authorized: authorized),
);

if (body != null) {
request.body = jsonEncode(body);
}

try {
final streamedResponse = await _client
    .send(request)
    .timeout(_requestTimeout);

final response = await http.Response.fromStream(streamedResponse);

final decodedBody = _decodeResponseBody(response.body);

if (response.statusCode >= 200 && response.statusCode < 300) {
return decodedBody;
}

throw ApiException(
_extractErrorMessage(
decodedBody,
response.statusCode,
),
statusCode: response.statusCode,
);
} on TimeoutException {
throw const ApiException(
'Сервер не відповідає. Перевірте підключення та повторіть спробу.',
);
} on ApiException {
rethrow;
} catch (error) {
throw ApiException(
'Помилка з’єднання із сервером: $error',
);
}
}

static dynamic _decodeResponseBody(String body) {
final trimmed = body.trim();

if (trimmed.isEmpty) {
return <String, dynamic>{};
}

try {
return jsonDecode(trimmed);
} on FormatException {
return <String, dynamic>{
'message': trimmed,
};
}
}

static String _extractErrorMessage(
dynamic responseBody,
int statusCode,
) {
if (responseBody is Map) {
final message = responseBody['message']?.toString().trim();

if (message != null && message.isNotEmpty) {
return message;
}

final error = responseBody['error']?.toString().trim();

if (error != null && error.isNotEmpty) {
return error;
}
}

switch (statusCode) {
case 400:
return 'Сервер відхилив передані дані.';
case 401:
return 'Сеанс авторизації завершено. Увійдіть повторно.';
case 403:
return 'У вас немає дозволу на виконання цієї дії.';
case 404:
return 'Запитаний ресурс не знайдено.';
case 405:
return 'Сервер не підтримує цей метод запиту.';
case 409:
return 'Дані вже змінені іншим користувачем.';
case 500:
return 'Внутрішня помилка сервера.';
default:
return 'Помилка сервера: HTTP $statusCode.';
}
}

static Map<String, dynamic> _asMap(dynamic value) {
if (value is Map<String, dynamic>) {
return value;
}

if (value is Map) {
return Map<String, dynamic>.from(value);
}

return <String, dynamic>{};
}

static List<dynamic> _extractList(
dynamic response, {
required String key,
}) {
if (response is List) {
return response;
}

if (response is Map) {
final value = response[key];

if (value is List) {
return value;
}
}

return <dynamic>[];
}

// ---------------------------------------------------------------------------
// Реєстрація та авторизація
// ---------------------------------------------------------------------------

static Future<Map<String, dynamic>> register({
required String email,
required String password,
required String displayName,
required String role,
}) async {
final response = await _request(
method: 'POST',
path: '/register',
authorized: false,
body: <String, dynamic>{
'email': email.trim().toLowerCase(),
'password': password,
'display_name': displayName.trim(),
'role': role.trim().toLowerCase(),
},
);

return _asMap(response);
}

static Future<Map<String, dynamic>> login(
String email,
String password,
) async {
final response = await _request(
method: 'POST',
path: '/login',
authorized: false,
body: <String, dynamic>{
'email': email.trim().toLowerCase(),
'password': password,
},
);

return _asMap(response);
}

// ---------------------------------------------------------------------------
// Профіль
// ---------------------------------------------------------------------------

static Future<Map<String, dynamic>> getProfile() async {
final response = await _request(
method: 'GET',
path: '/profile',
);

return _asMap(response);
}

static Future<Map<String, dynamic>> updateProfile({
String? displayName,
String? avatarUrl,
String? oldPassword,
String? newPassword,
}) async {
final body = <String, dynamic>{};

if (displayName != null) {
body['display_name'] = displayName.trim();
}

if (avatarUrl != null) {
body['avatar_url'] = avatarUrl.trim();
}

if (oldPassword != null) {
body['old_password'] = oldPassword;
}

if (newPassword != null) {
body['new_password'] = newPassword;
}

if (body.isEmpty) {
throw const ApiException(
'Немає даних для оновлення профілю.',
);
}

final response = await _request(
method: 'PUT',
path: '/profile',
body: body,
);

return _asMap(response);
}

// ---------------------------------------------------------------------------
// Замовлення клієнта
// ---------------------------------------------------------------------------

static Future<Map<String, dynamic>> createOrder({
required String orderType,
required String city,
required String pickupAddress,
required double pickupLat,
required double pickupLng,
required String deliveryAddress,
required double deliveryLat,
required double deliveryLng,
required String description,
required String phone,
required String comment,
}) async {
final response = await _request(
method: 'POST',
path: '/orders',
body: <String, dynamic>{
'order_type': orderType.trim().toLowerCase(),
'city': city.trim(),
'pickup_address': pickupAddress.trim(),
'pickup_lat': pickupLat,
'pickup_lng': pickupLng,
'delivery_address': deliveryAddress.trim(),
'delivery_lat': deliveryLat,
'delivery_lng': deliveryLng,
'description': description.trim(),
'phone': phone.trim(),
'comment': comment.trim(),
},
);

return _asMap(response);
}

static Future<List<dynamic>> getClientOrders(
String tab,
) async {
final response = await _request(
method: 'GET',
path: '/orders',
queryParameters: <String, String>{
'tab': tab.trim(),
},
);

return _extractList(
response,
key: 'orders',
);
}

static Future<Map<String, dynamic>> getOrder(
String orderId,
) async {
final normalizedId = orderId.trim();

if (normalizedId.isEmpty) {
throw const ApiException(
'Не вказано ID замовлення.',
);
}

final response = await _request(
method: 'GET',
path: '/orders/$normalizedId',
);

return _asMap(response);
}

static Future<Map<String, dynamic>> cancelOrder(
String orderId,
) async {
final normalizedId = orderId.trim();

if (normalizedId.isEmpty) {
throw const ApiException(
'Не вказано ID замовлення.',
);
}

final response = await _request(
method: 'POST',
path: '/orders/cancel/$normalizedId',
);

return _asMap(response);
}

// ---------------------------------------------------------------------------
// Замовлення кур’єра
// ---------------------------------------------------------------------------

static Future<List<dynamic>> getCourierOrders(
String tab, {
String city = '',
}) async {
final query = <String, String>{
'tab': tab.trim(),
};

final normalizedCity = city.trim();

if (normalizedCity.isNotEmpty) {
query['city'] = normalizedCity;
}

final response = await _request(
method: 'GET',
path: '/orders',
queryParameters: query,
);

return _extractList(
response,
key: 'orders',
);
}

static Future<Map<String, dynamic>> acceptOrder(
String orderId,
) async {
final normalizedId = orderId.trim();

if (normalizedId.isEmpty) {
throw const ApiException(
'Не вказано ID замовлення.',
);
}

final response = await _request(
method: 'POST',
path: '/orders/accept/$normalizedId',
);

return _asMap(response);
}

static Future<Map<String, dynamic>> deliverOrder(
String orderId,
) async {
final normalizedId = orderId.trim();

if (normalizedId.isEmpty) {
throw const ApiException(
'Не вказано ID замовлення.',
);
}

final response = await _request(
method: 'POST',
path: '/orders/delivered/$normalizedId',
);

return _asMap(response);
}

static Future<Map<String, dynamic>> getOrderRoute(
String orderId,
) async {
final normalizedId = orderId.trim();

if (normalizedId.isEmpty) {
throw const ApiException(
'Не вказано ID замовлення.',
);
}

final response = await _request(
method: 'GET',
path: '/orders/$normalizedId/route',
);

return _asMap(response);
}

// ---------------------------------------------------------------------------
// Адміністратор
// ---------------------------------------------------------------------------

static Future<List<dynamic>> getAllUsers() async {
final response = await _request(
method: 'GET',
path: '/admin/users',
);

return _extractList(
response,
key: 'users',
);
}

static Future<Map<String, dynamic>> updateUser(
String userId, {
String? role,
bool? isActive,
}) async {
final normalizedId = userId.trim();

if (normalizedId.isEmpty) {
throw const ApiException(
'Не вказано ID користувача.',
);
}

final body = <String, dynamic>{};

if (role != null) {
body['role'] = role.trim().toLowerCase();
}

if (isActive != null) {
body['is_active'] = isActive;
}

if (body.isEmpty) {
throw const ApiException(
'Немає даних для оновлення користувача.',
);
}

final response = await _request(
method: 'PUT',
path: '/admin/users/$normalizedId',
body: body,
);

return _asMap(response);
}

// ---------------------------------------------------------------------------
// Статус користувача
// ---------------------------------------------------------------------------

static Future<Map<String, dynamic>> getMyStatus() async {
final response = await _request(
method: 'GET',
path: '/me/status',
);

return _asMap(response);
}

static Future<Map<String, dynamic>> getUserStatus(
String userId,
) async {
final normalizedId = userId.trim();

if (normalizedId.isEmpty) {
throw const ApiException(
'Не вказано ID користувача.',
);
}

final response = await _request(
method: 'GET',
path: '/status/$normalizedId',
);

return _asMap(response);
}

// ---------------------------------------------------------------------------
// Живе відстеження кур’єра
// ---------------------------------------------------------------------------

  /// Передає поточне місцезнаходження кур’єра на сервер.
  ///
  /// orderUpdates може містити окремий час прибуття
  /// та залишкову відстань для кожного активного замовлення.
  static Future<Map<String, dynamic>> updateCourierLocation({
    required double latitude,
    required double longitude,
    double accuracy = 0,
    double speedMps = 0,
    double heading = 0,
    String travelMode = 'driving',
    String? currentStepType,
    String? currentStepAddress,
    List<Map<String, dynamic>> orderUpdates =
    const <Map<String, dynamic>>[],
  }) async {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180 ||
        (latitude == 0 && longitude == 0)) {
      throw const ApiException(
        'Не вдалося передати некоректні GPS-координати.',
      );
    }

    final normalizedTravelMode =
    travelMode.trim().toLowerCase();

    const allowedTravelModes = <String>{
      'driving',
      'walking',
      'bicycling',
    };

    if (!allowedTravelModes.contains(
      normalizedTravelMode,
    )) {
      throw const ApiException(
        'Некоректний режим пересування.',
      );
    }

    final normalizedStepType =
    currentStepType?.trim().toLowerCase();

    if (normalizedStepType != null &&
        normalizedStepType.isNotEmpty &&
        normalizedStepType != 'pickup' &&
        normalizedStepType != 'delivery') {
      throw const ApiException(
        'Некоректний тип поточної точки маршруту.',
      );
    }

    final preparedUpdates = orderUpdates
        .where(
          (item) =>
      item['order_id']?.toString().trim().isNotEmpty ==
          true,
    )
        .map(
          (item) => <String, dynamic>{
        'order_id':
        item['order_id'].toString().trim(),
        if (item['remaining_distance_km'] != null)
          'remaining_distance_km':
          item['remaining_distance_km'],
        if (item['estimated_arrival_min'] != null)
          'estimated_arrival_min':
          item['estimated_arrival_min'],
      },
    )
        .toList();

    final response = await _request(
      method: 'POST',
      path: '/courier/location',
      body: <String, dynamic>{
        'lat': latitude,
        'lng': longitude,
        'accuracy': accuracy < 0 ? 0 : accuracy,
        'speed_mps': speedMps < 0 ? 0 : speedMps,
        'heading': heading % 360,
        'travel_mode': normalizedTravelMode,
        if (normalizedStepType != null &&
            normalizedStepType.isNotEmpty)
          'current_step_type': normalizedStepType,
        if (currentStepAddress != null &&
            currentStepAddress.trim().isNotEmpty)
          'current_step_address':
          currentStepAddress.trim(),
        'order_updates': preparedUpdates,
      },
    );

    return _asMap(response);
  }

  /// Отримує актуальну позицію кур’єра,
  /// залишкову відстань і час прибуття для клієнта.
  static Future<Map<String, dynamic>> getOrderTracking(
      String orderId,
      ) async {
    final normalizedId = orderId.trim();

    if (normalizedId.isEmpty) {
      throw const ApiException(
        'Не вказано ID замовлення.',
      );
    }

    final response = await _request(
      method: 'GET',
      path: '/orders/$normalizedId/tracking',
    );

    return _asMap(response);
  }

/// Закривати HTTP-клієнт потрібно лише
/// під час повного завершення роботи застосунку.
/// під час повного завершення роботи застосунку.
static void dispose() {
_client.close();
}
}

