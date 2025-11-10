import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool loadingUsers = true;
  bool loadingOrders = true;
  List<dynamic> users = [];
  List<dynamic> orders = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    loadUsers();
    loadOrders();
  }

  Future<void> loadUsers() async {
    final data = await ApiService.getAllUsers();
    setState(() {
      users = data;
      loadingUsers = false;
    });
  }

  Future<void> loadOrders() async {
    final data = await ApiService.getOrders();
    setState(() {
      orders = data;
      loadingOrders = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Користувачі'),
            Tab(text: 'Замовлення'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 🧍‍♂️ Користувачі
          loadingUsers
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, i) {
              final u = users[i];
              return ListTile(
                title: Text(u['email']),
                subtitle: Text('Роль: ${u['role'] ?? 'невідомо'}'),
                leading: const Icon(Icons.person),
              );
            },
          ),
          // 📦 Замовлення
          loadingOrders
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, i) {
              final o = orders[i];
              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text(o['address']),
                  subtitle: Text(
                    'Статус: ${o['status']}\n'
                        'Клієнт: ${o['owner_id'] ?? 'невідомо'}',
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
