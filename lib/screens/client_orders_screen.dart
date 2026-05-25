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

class _ClientOrdersScreenState extends State<ClientOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<dynamic> activeOrders = [];
  List<dynamic> deliveredOrders = [];
  List<dynamic> cancelledOrders = [];

  bool loading = true;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 3, vsync: this);
    loadOrders();
  }

  Future<void> loadOrders() async {
    setState(() => loading = true);

    try {
      final active = await ApiService.getClientOrders('active');
      final delivered = await ApiService.getClientOrders('delivered');
      final cancelled = await ApiService.getClientOrders('cancelled');

      if (!mounted) return;

      setState(() {
        activeOrders = active;
        deliveredOrders = delivered;
        cancelledOrders = cancelled;
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

  String _orderTypeText(String? type) {
    switch (type) {
      case 'food':
        return 'Доставка їжі / товару';
      case 'parcel':
        return 'Передача посилки';
      default:
        return 'Замовлення';
    }
  }

  IconData _orderTypeIcon(String? type) {
    switch (type) {
      case 'food':
        return Icons.restaurant_menu_outlined;
      case 'parcel':
        return Icons.inventory_2_outlined;
      default:
        return Icons.local_shipping_outlined;
    }
  }

  Widget _buildOrderCard(Map<String, dynamic> o) {
    final orderType = o['order_type']?.toString() ?? 'parcel';
    final pickupAddress = o['pickup_address']?.toString() ?? '';
    final deliveryAddress = o['delivery_address']?.toString() ?? '';
    final description = o['description']?.toString() ?? '';
    final phone = o['phone']?.toString() ?? '';
    final city = o['city']?.toString() ?? '';
    final distance = o['distance_km']?.toString() ?? '0';
    final time = o['estimated_time_min']?.toString() ?? '0';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_orderTypeIcon(orderType)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _orderTypeText(orderType),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                StatusChip(status: o['status']),
              ],
            ),
            const SizedBox(height: 10),
            if (city.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.location_city, size: 18),
                  const SizedBox(width: 6),
                  Text('Місто: $city'),
                ],
              ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.my_location_outlined, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    pickupAddress.isEmpty
                        ? 'Адресу забору не вказано'
                        : 'Звідки: $pickupAddress',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    deliveryAddress.isEmpty
                        ? 'Адресу доставки не вказано'
                        : 'Куди: $deliveryAddress',
                  ),
                ),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.route_outlined, size: 18),
                const SizedBox(width: 6),
                Text('$distance км'),
                const SizedBox(width: 16),
                const Icon(Icons.timer_outlined, size: 18),
                const SizedBox(width: 6),
                Text('$time хв'),
              ],
            ),
            if (phone.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.phone_outlined, size: 18),
                  const SizedBox(width: 6),
                  Text(phone),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersList(List<dynamic> list, String emptyText) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: loadOrders,
      child: list.isEmpty
          ? ListView(
        children: [
          const SizedBox(height: 120),
          Center(
            child: Text(
              emptyText,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ],
      )
          : ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final order = list[index] as Map<String, dynamic>;
          return _buildOrderCard(order);
        },
      ),
    );
  }

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  Future<void> _openCreateOrder() async {
    final created = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateOrderScreen()),
    );

    if (created == true) {
      await loadOrders();
      _tabController.animateTo(0);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
            onPressed: _openProfile,
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
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.pending_actions_outlined),
              text: 'Активні',
            ),
            Tab(
              icon: Icon(Icons.done_all_outlined),
              text: 'Доставлені',
            ),
            Tab(
              icon: Icon(Icons.cancel_outlined),
              text: 'Скасовані',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrdersList(
            activeOrders,
            'Активних замовлень поки немає.\nНатисніть "+", щоб створити нове замовлення.',
          ),
          _buildOrdersList(
            deliveredOrders,
            'Доставлених замовлень поки немає.',
          ),
          _buildOrdersList(
            cancelledOrders,
            'Скасованих замовлень поки немає.',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateOrder,
        icon: const Icon(Icons.add),
        label: const Text('Нове'),
      ),
    );
  }
}