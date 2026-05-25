import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_storage.dart';

class ApiService {
  static const String baseUrl = 'http://10.88.255.146:5000';

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final url = Uri.parse('$baseUrl/login');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String displayName,
    required String role,
  }) async {
    final url = Uri.parse('$baseUrl/register');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'display_name': displayName,
        'role': role,
      }),
    );
    return jsonDecode(res.body);
  }

  static Future<List<dynamic>> getOrders() async {
    final token = await AuthStorage.getToken();
    final url = Uri.parse('$baseUrl/orders');

    final res = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    final json = jsonDecode(res.body);
    return json['orders'] ?? [];
  }

  static Future<List<dynamic>> getClientOrders(String tab) async {
    final token = await AuthStorage.getToken();
    final url = Uri.parse('$baseUrl/orders?tab=$tab');

    final res = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    final json = jsonDecode(res.body);
    return json['orders'] ?? [];
  }

  static Future<List<dynamic>> getCourierOrders(
      String tab, {
        String city = '',
      }) async {
    final token = await AuthStorage.getToken();

    final query = city.trim().isEmpty
        ? 'tab=$tab'
        : 'tab=$tab&city=${Uri.encodeComponent(city.trim())}';

    final url = Uri.parse('$baseUrl/orders?$query');

    final res = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    final json = jsonDecode(res.body);
    return json['orders'] ?? [];
  }

  static Future<Map<String, dynamic>> getOrderRoute(String orderId) async {
    final token = await AuthStorage.getToken();
    final url = Uri.parse('$baseUrl/orders/$orderId/route');

    final res = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    final json = jsonDecode(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return json;
    } else {
      throw Exception(json['message'] ?? 'Помилка отримання маршруту');
    }
  }

  static Future<List<dynamic>> getAllUsers() async {
    final token = await AuthStorage.getToken();
    final url = Uri.parse('$baseUrl/admin/users');

    final res = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    final json = jsonDecode(res.body);
    return json['users'] ?? [];
  }

  static Future<Map<String, dynamic>> updateUser(
      String userId, {
        String? role,
        bool? isActive,
      }) async {
    final token = await AuthStorage.getToken();
    final url = Uri.parse('$baseUrl/admin/users/$userId');

    final body = <String, dynamic>{};
    if (role != null) body['role'] = role;
    if (isActive != null) body['is_active'] = isActive;

    final res = await http.put(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    final json = jsonDecode(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return json;
    } else {
      throw Exception(json['message'] ?? 'Помилка оновлення користувача');
    }
  }

  static Future<void> createOrder({
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
    String comment = '',
  }) async {
    final token = await AuthStorage.getToken();
    final url = Uri.parse('$baseUrl/orders');

    final res = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'order_type': orderType,
        'city': city,
        'pickup_address': pickupAddress,
        'pickup_lat': pickupLat,
        'pickup_lng': pickupLng,
        'delivery_address': deliveryAddress,
        'delivery_lat': deliveryLat,
        'delivery_lng': deliveryLng,
        'description': description,
        'phone': phone,
        'comment': comment,
      }),
    );

    final json = jsonDecode(res.body);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(json['message'] ?? 'Помилка створення замовлення');
    }
  }

  static Future<Map<String, dynamic>> acceptOrder(String orderId) async {
    final token = await AuthStorage.getToken();
    final url = Uri.parse('$baseUrl/orders/accept/$orderId');

    final res = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    Map<String, dynamic>? body;
    try {
      body = jsonDecode(res.body);
    } catch (_) {
      body = null;
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return {
        'ok': true,
        'message': body?['message'] ?? 'Замовлення прийнято',
      };
    } else {
      throw Exception(body?['message'] ?? 'Помилка при прийнятті замовлення');
    }
  }

  static Future<Map<String, dynamic>> deliverOrder(String orderId) async {
    final token = await AuthStorage.getToken();
    final url = Uri.parse('$baseUrl/orders/delivered/$orderId');

    final res = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    Map<String, dynamic>? body;
    try {
      body = jsonDecode(res.body);
    } catch (_) {
      body = null;
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return {
        'ok': true,
        'message': body?['message'] ?? 'Статус змінено на "доставлено"',
      };
    } else {
      throw Exception(body?['message'] ?? 'Помилка при зміні статусу');
    }
  }

  static Future<Map<String, dynamic>> getProfile() async {
    final token = await AuthStorage.getToken();
    final url = Uri.parse('$baseUrl/profile');

    final res = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> updateProfile({
    String? displayName,
    String? avatarUrl,
    String? oldPassword,
    String? newPassword,
  }) async {
    final token = await AuthStorage.getToken();
    final url = Uri.parse('$baseUrl/profile');

    final body = <String, dynamic>{};
    if (displayName != null) body['display_name'] = displayName;
    if (avatarUrl != null) body['avatar_url'] = avatarUrl;
    if (oldPassword != null && newPassword != null) {
      body['old_password'] = oldPassword;
      body['new_password'] = newPassword;
    }

    final res = await http.put(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    return jsonDecode(res.body);
  }
}