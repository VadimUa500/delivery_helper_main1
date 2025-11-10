import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'create_order_screen.dart';
import 'profile_screen.dart';
import 'package:provider/provider.dart';
import '../theme/theme_notifier.dart';
import '../widgets/status_chip.dart';


class ClientOrdersScreen extends StatefulWidget {
  const ClientOrdersScreen({super.key});

  @override
  State<ClientOrdersScreen> createState() => _ClientOrdersScreenState();
}

class _ClientOrdersScreenState extends State<ClientOrdersScreen> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мої замовлення'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
          Consumer<ThemeNotifier>(
            builder: (context, themeNotifier, _) => IconButton(
              icon: Icon(themeNotifier.isDark ? Icons.wb_sunny : Icons.nightlight),
              tooltip: 'Змінити тему',
              onPressed: () => themeNotifier.toggleTheme(),
            ),
          ),
        ],
      ),

      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        itemCount: orders.length,
        itemBuilder: (context, i) {
          final o = orders[i];
          return ListTile(
            title: Text(o['address']),
            subtitle: StatusChip(status: o['status']),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateOrderScreen()),
          );
          if (created == true) loadOrders();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
