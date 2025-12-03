import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../theme/theme_notifier.dart';
import '../widgets/status_chip.dart';
import 'create_order_screen.dart';
import 'profile_screen.dart';

class ClientOrdersScreen extends StatefulWidget {
  const ClientOrdersScreen({super.key});

  @override
  State<ClientOrdersScreen> createState() => _ClientOrdersScreenState();
}

class _ClientOrdersScreenState extends State<ClientOrdersScreen> {
  List<dynamic> orders = [];
  bool loading = true;

  Future<void> loadOrders() async {
    try {
      final data = await ApiService.getOrders();
      setState(() {
        orders = data;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Помилка завантаження: $e')),
      );
    }
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
            tooltip: 'Профіль',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
          Consumer<ThemeNotifier>(
            builder: (context, themeNotifier, _) => IconButton(
              icon: Icon(
                themeNotifier.isDark
                    ? Icons.wb_sunny_outlined
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
        child: orders.isEmpty
            ? ListView(
          children: const [
            SizedBox(height: 120),
            Center(
              child: Text(
                'Замовлень поки немає.\nСтворіть перше замовлення за допомогою кнопки "+".',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        )
            : ListView.builder(
          padding: const EdgeInsets.symmetric(
              vertical: 8, horizontal: 8),
          itemCount: orders.length,
          itemBuilder: (context, i) {
            final o = orders[i] as Map<String, dynamic>;
            final address = o['address']?.toString() ?? '';
            final desc = o['description']?.toString() ?? '';
            final phone = o['phone']?.toString() ?? '';

            return Card(
              margin: const EdgeInsets.symmetric(
                  vertical: 4, horizontal: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 3,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 8, horizontal: 12),
                title: Text(
                  address.isEmpty ? '(без адреси)' : address,
                  style:
                  const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (desc.isNotEmpty)
                      Padding(
                        padding:
                        const EdgeInsets.only(top: 4.0),
                        child: Text(
                          desc,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (phone.isNotEmpty)
                      Padding(
                        padding:
                        const EdgeInsets.only(top: 2.0),
                        child: Text(
                          'Телефон: $phone',
                          style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey),
                        ),
                      ),
                  ],
                ),
                trailing: StatusChip(status: o['status']),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateOrderScreen()),
          );
          if (created == true) {
            await loadOrders();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
