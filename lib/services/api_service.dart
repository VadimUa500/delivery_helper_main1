import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_storage.dart';

class ApiService {
  static const String baseUrl = 'http://10.0.2.2:5000';

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final url = Uri.parse('$baseUrl/login');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
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
    return jsonDecode(res.body)['orders'];
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

  static Future<void> createOrder(String address, String desc, String phone) async {
    final token = await AuthStorage.getToken();
    final url = Uri.parse('$baseUrl/orders');
    await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'address': address,
        'description': desc,
        'phone': phone,
      }),
    );
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
}
