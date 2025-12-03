import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_storage.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'courier_order_details_screen.dart'; // 🆕 ДОДАТИ
import 'package:provider/provider.dart';
import '../theme/theme_notifier.dart';
import '../widgets/status_chip.dart';

class CourierOrdersScreen extends StatefulWidget {
  const CourierOrdersScreen({super.key});

  @override
  State<CourierOrdersScreen> createState() => _CourierOrdersScreenState();
}

class _CourierOrdersScreenState extends State<CourierOrdersScreen> {
  List<dynamic> orders = [];
  bool loading = true;

  Future<void> loadOrders() async {
    final data = await ApiService.getOrders();
    setState(() {
      orders = data;
      loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    loadOrders();
  }

  Future<void> acceptOrder(String id) async {
    try {
      final res = await ApiService.acceptOrder(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Замовлення прийнято')),
      );
      await loadOrders();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Помилка: $e')),
      );
    }
  }

  Future<void> deliverOrder(String id) async {
    try {
      final res = await ApiService.deliverOrder(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Статус оновлено')),
      );
      await loadOrders();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Помилка: $e')),
      );
    }
  }

  Future<void> logout() async {
    await AuthStorage.clear();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
      );
    }
  }

  Widget buildActionButton(Map<String, dynamic> o) {
    final status = o['status'];
    final id = o['id'] ?? o['_id'];

    if (status == 'new') {
      return ElevatedButton(
        onPressed: () => acceptOrder(id),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
        child: const Text('Прийняти', style: TextStyle(color: Colors.white)),
      );
    } else if (status == 'in_progress') {
      return ElevatedButton(
        onPressed: () => deliverOrder(id),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
        child: const Text('Доставлено', style: TextStyle(color: Colors.white)),
      );
    } else {
      return const Text('✅ Доставлено', style: TextStyle(color: Colors.grey));
    }
  }

  void _openCourierProfile() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Профіль кур’єра',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text('Роль: Кур’єр'),
              const Text('Статус: Онлайн 🟢'),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ProfileScreen()),
                      );
                    },
                    child: const Text('Детальніше'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () {
                      Navigator.pop(context);
                      logout();
                    },
                    child: const Text(
                      'Вийти',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Доставки'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Профіль кур’єра',
            onPressed: _openCourierProfile,
          ),
          Consumer<ThemeNotifier>(
            builder: (context, themeNotifier, _) => IconButton(
              icon: Icon(
                themeNotifier.isDark
                    ? Icons.wb_sunny
                    : Icons.nightlight_round,
              ),
              tooltip: 'Змінити тему',
              onPressed: () => themeNotifier.toggleTheme(),
            ),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: loadOrders,
        child: ListView.builder(
          itemCount: orders.length,
          itemBuilder: (context, i) {
            final o = orders[i] as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.all(8),
              child: ListTile(
                onTap: () async {
                  final changed = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          CourierOrderDetailsScreen(order: o),
                    ),
                  );
                  if (changed == true) {
                    await loadOrders();
                  }
                },
                title: Text(o['address'] ?? ''),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatusChip(status: o['status']),
                    const SizedBox(height: 4),
                    Text('Адреса: ${o['address'] ?? ''}'),
                  ],
                ),
                trailing: buildActionButton(o),
              ),
            );
          },
        ),
      ),
    );
  }
}
