import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../services/auth_storage.dart';
import '../theme/theme_notifier.dart';
import '../widgets/status_chip.dart';

import 'login_screen.dart';
import 'profile_screen.dart';
import 'courier_order_details_screen.dart';
import 'optimized_route_screen.dart';

class CourierOrdersScreen extends StatefulWidget {
  const CourierOrdersScreen({super.key});

  @override
  State<CourierOrdersScreen> createState() => _CourierOrdersScreenState();
}

class _CourierOrdersScreenState extends State<CourierOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<dynamic> availableOrders = [];
  List<dynamic> activeOrders = [];
  List<dynamic> deliveredOrders = [];

  final Set<String> selectedOrderIds = {};

  bool loading = true;
  String selectedCity = '';

  final List<String> cities = [
    '',
    'Рівне',
    'Корець',
    'Здолбунів',
    'Острог',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    loadOrders();
  }

  Future<void> loadOrders() async {
    setState(() => loading = true);

    try {
      final available = await ApiService.getCourierOrders(
        'available',
        city: selectedCity,
      );
      final active = await ApiService.getCourierOrders(
        'active',
        city: selectedCity,
      );
      final delivered = await ApiService.getCourierOrders(
        'delivered',
        city: selectedCity,
      );

      if (!mounted) return;

      setState(() {
        availableOrders = available;
        activeOrders = active;
        deliveredOrders = delivered;
        selectedOrderIds.clear();
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

  Future<void> logout() async {
    await AuthStorage.clear();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
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

  Future<void> _openDetails(Map<String, dynamic> order) async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CourierOrderDetailsScreen(order: order),
      ),
    );

    if (changed == true) {
      await loadOrders();
    }
  }

  void _toggleSelected(String orderId, bool? value) {
    setState(() {
      if (value == true) {
        selectedOrderIds.add(orderId);
      } else {
        selectedOrderIds.remove(orderId);
      }
    });
  }

  void _openOptimizedRoute() {
    final selectedOrders = activeOrders
        .where((o) => selectedOrderIds.contains(o['id'].toString()))
        .map((o) => Map<String, dynamic>.from(o as Map))
        .toList();

    if (selectedOrders.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Оберіть мінімум 2 активні замовлення'),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OptimizedRouteScreen(
          orders: selectedOrders,
        ),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> o) {
    final orderId = o['id']?.toString() ?? '';
    final status = o['status']?.toString() ?? '';
    final isActive = status == 'in_progress';
    final isSelected = selectedOrderIds.contains(orderId);

    final orderType = o['order_type']?.toString() ?? 'parcel';
    final pickupAddress = o['pickup_address']?.toString() ?? '';
    final deliveryAddress = o['delivery_address']?.toString() ?? '';
    final description = o['description']?.toString() ?? '';
    final city = o['city']?.toString() ?? '';
    final distance = o['distance_km']?.toString() ?? '0';
    final time = o['estimated_time_min']?.toString() ?? '0';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      elevation: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openDetails(o),
        onLongPress: isActive
            ? () => _toggleSelected(orderId, !isSelected)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (isActive)
                    Checkbox(
                      value: isSelected,
                      onChanged: (value) => _toggleSelected(orderId, value),
                    ),
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
                          ? 'Звідки: не вказано'
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
                          ? 'Куди: не вказано'
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
            ],
          ),
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
          final order = Map<String, dynamic>.from(list[index] as Map);
          return _buildOrderCard(order);
        },
      ),
    );
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
              const Text(
                'Профіль кур’єра',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text('Роль: Кур’єр'),
              const Text('Статус: Онлайн 🟢'),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ProfileScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.person_outline),
                      label: const Text('Профіль'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        logout();
                      },
                      icon: const Icon(Icons.logout, color: Colors.white),
                      label: const Text(
                        'Вийти',
                        style: TextStyle(color: Colors.white),
                      ),
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

  Widget _buildCityFilter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: DropdownButtonFormField<String>(
        value: selectedCity,
        decoration: const InputDecoration(
          labelText: 'Фільтр по місту',
          prefixIcon: Icon(Icons.location_city_outlined),
          border: OutlineInputBorder(),
        ),
        items: cities.map((city) {
          return DropdownMenuItem(
            value: city,
            child: Text(city.isEmpty ? 'Усі міста' : city),
          );
        }).toList(),
        onChanged: (value) async {
          setState(() {
            selectedCity = value ?? '';
            selectedOrderIds.clear();
          });
          await loadOrders();
        },
      ),
    );
  }

  Widget? _buildFloatingButton() {
    if (selectedOrderIds.length < 2) return null;

    return FloatingActionButton.extended(
      onPressed: _openOptimizedRoute,
      icon: const Icon(Icons.alt_route),
      label: Text('Оптимізувати: ${selectedOrderIds.length}'),
    );
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
        title: const Text('Доставки кур’єра'),
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
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.search_outlined),
              text: 'Доступні',
            ),
            Tab(
              icon: Icon(Icons.delivery_dining_outlined),
              text: 'Мої активні',
            ),
            Tab(
              icon: Icon(Icons.done_all_outlined),
              text: 'Доставлені',
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildCityFilter(),
          if (selectedOrderIds.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              child: Text(
                selectedOrderIds.length >= 2
                    ? 'Обрано ${selectedOrderIds.length} доставок. Натисніть "Оптимізувати", щоб побудувати рекомендований маршрут.'
                    : 'Оберіть ще одну активну доставку для оптимізації маршруту.',
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOrdersList(
                  availableOrders,
                  'Доступних замовлень поки немає.',
                ),
                _buildOrdersList(
                  activeOrders,
                  'У вас немає активних доставок.',
                ),
                _buildOrdersList(
                  deliveredOrders,
                  'Доставлених замовлень поки немає.',
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingButton(),
    );
  }
}