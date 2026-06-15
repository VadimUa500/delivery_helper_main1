import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../theme/theme_notifier.dart';
import '../widgets/status_chip.dart';

import 'client_order_details_screen.dart';
import 'create_order_screen.dart';
import 'profile_screen.dart';

class ClientOrdersScreen extends StatefulWidget {
  const ClientOrdersScreen({super.key});

  @override
  State<ClientOrdersScreen> createState() => _ClientOrdersScreenState();
}

class _ClientOrdersScreenState extends State<ClientOrdersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  List<dynamic> activeOrders = [];
  List<dynamic> deliveredOrders = [];
  List<dynamic> cancelledOrders = [];

  bool loading = true;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      length: 3,
      vsync: this,
    );

    loadOrders();
  }

  Future<void> loadOrders() async {
    if (mounted) {
      setState(() => loading = true);
    }

    try {
      final results = await Future.wait([
        ApiService.getClientOrders('active'),
        ApiService.getClientOrders('delivered'),
        ApiService.getClientOrders('cancelled'),
      ]);

      if (!mounted) return;

      setState(() {
        activeOrders = results[0];
        deliveredOrders = results[1];
        cancelledOrders = results[2];
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Text(
            'Помилка завантаження замовлень: $e',
          ),
        ),
      );
    }
  }

  String _orderTypeText(String? type) {
    switch (type) {
      case 'documents':
        return 'Документи';

      case 'parcel':
        return 'Посилка або товар';

      default:
        return 'Доставка';
    }
  }

  IconData _orderTypeIcon(String? type) {
    switch (type) {
      case 'documents':
        return Icons.description_rounded;

      case 'parcel':
        return Icons.inventory_2_rounded;

      default:
        return Icons.local_shipping_rounded;
    }
  }

  Future<void> _openOrderDetails(
      Map<String, dynamic> order,
      ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientOrderDetailsScreen(
          order: Map<String, dynamic>.from(order),
        ),
      ),
    );

    if (!mounted) return;

    await loadOrders();
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final orderType =
        order['order_type']?.toString() ?? 'parcel';

    final status =
        order['status']?.toString() ?? 'new';

    final pickupAddress =
        order['pickup_address']?.toString().trim() ?? '';

    final deliveryAddress =
        order['delivery_address']?.toString().trim() ?? '';

    final description =
        order['description']?.toString().trim() ?? '';

    final phone =
        order['phone']?.toString().trim() ?? '';

    final city =
        order['city']?.toString().trim() ?? '';

    final distance =
        order['distance_km']?.toString() ?? '0';

    final estimatedTime =
        order['estimated_time_min']?.toString() ?? '0';

    return Container(
      margin: const EdgeInsets.symmetric(
        vertical: 8,
        horizontal: 16,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E222D)
            : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: isDark ? 0.15 : 0.04,
            ),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.03),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openOrderDetails(order),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _orderTypeIcon(orderType),
                              color: theme.colorScheme.primary,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _orderTypeText(orderType)
                                  .toUpperCase(),
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      StatusChip(status: status),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: theme.hintColor
                            .withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          const SizedBox(height: 4),
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: const Color(0xFF34C759),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                            ),
                          ),
                          Container(
                            width: 1.5,
                            height: 38,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.15)
                                : Colors.black.withValues(alpha: 0.08),
                          ),
                          const Icon(
                            Icons.location_on_rounded,
                            size: 16,
                            color: Color(0xFFFF3B30),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pickupAddress.isEmpty
                                  ? 'Адресу забору не вказано'
                                  : pickupAddress,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (city.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                city,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.hintColor,
                                ),
                              ),
                            ],
                            const SizedBox(height: 18),
                            Text(
                              deliveryAddress.isEmpty
                                  ? 'Адресу доставки не вказано'
                                  : deliveryAddress,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  if (description.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                      ),
                      child: Divider(
                        height: 1,
                        color: isDark
                            ? Colors.white10
                            : Colors.black.withValues(alpha: 0.05),
                      ),
                    ),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.textTheme.bodyMedium?.color
                            ?.withValues(alpha: 0.7),
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 20),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment:
                    WrapCrossAlignment.center,
                    children: [
                      _buildMetricPill(
                        context,
                        Icons.navigation_rounded,
                        '$distance км',
                      ),
                      _buildMetricPill(
                        context,
                        Icons.access_time_filled_rounded,
                        '$estimatedTime хв',
                      ),
                      if (phone.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.black.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.phone_rounded,
                                size: 13,
                                color: theme.hintColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                phone,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: theme.hintColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricPill(
      BuildContext context,
      IconData icon,
      String label,
      ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF2C313F)
            : const Color(0xFFF3F5F8),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: isDark
                ? Colors.white70
                : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.9)
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String text) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary
                    .withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 64,
                color: theme.colorScheme.primary
                    .withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Замовлень немає',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: theme.hintColor,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _openCreateOrder,
              icon: const Icon(
                Icons.add_rounded,
                size: 18,
              ),
              label: const Text(
                'Створити замовлення',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.symmetric(
            vertical: 8,
            horizontal: 16,
          ),
          height: 180,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Theme.of(context)
                  .dividerColor
                  .withValues(alpha: 0.05),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.black12,
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 100,
                      height: 12,
                      color: Colors.black12,
                    ),
                    const Spacer(),
                    Container(
                      width: 70,
                      height: 20,
                      color: Colors.black12,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  width: 180,
                  height: 10,
                  color: Colors.black12,
                ),
                const SizedBox(height: 12),
                Container(
                  width: 140,
                  height: 10,
                  color: Colors.black12,
                ),
                const Spacer(),
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 24,
                      color: Colors.black12,
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 60,
                      height: 24,
                      color: Colors.black12,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrdersList(
      List<dynamic> list,
      String emptyText,
      ) {
    if (loading) {
      return _buildSkeletonLoader();
    }

    return RefreshIndicator(
      onRefresh: loadOrders,
      color: Theme.of(context).colorScheme.primary,
      child: list.isEmpty
          ? SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.68,
          child: _buildEmptyState(emptyText),
        ),
      )
          : ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(
          top: 8,
          bottom: 90,
        ),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final order = Map<String, dynamic>.from(
            list[index] as Map,
          );

          return _buildOrderCard(order);
        },
      ),
    );
  }

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProfileScreen(),
      ),
    );
  }

  Future<void> _openCreateOrder() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const CreateOrderScreen(),
      ),
    );

    if (created == true) {
      await loadOrders();

      if (!mounted) return;

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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF13151A)
          : const Color(0xFFF8F9FD),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: theme.textTheme.titleLarge?.color,
        title: const Text(
          'Мої доставки',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.person_outline_rounded,
              size: 26,
            ),
            tooltip: 'Профіль',
            onPressed: _openProfile,
          ),
          Consumer<ThemeNotifier>(
            builder: (context, themeNotifier, _) {
              return IconButton(
                icon: Icon(
                  themeNotifier.isDark
                      ? Icons.wb_sunny_rounded
                      : Icons.nightlight_round_rounded,
                  size: 24,
                ),
                tooltip: 'Змінити тему',
                onPressed: themeNotifier.toggleTheme,
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E222D)
                  : const Color(0xFFEFEFF4),
              borderRadius: BorderRadius.circular(16),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: isDark
                    ? theme.colorScheme.primary
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  if (!isDark)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                ],
              ),
              labelColor: isDark
                  ? Colors.white
                  : theme.colorScheme.primary,
              unselectedLabelColor: theme.hintColor,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Активні'),
                Tab(text: 'Доставлені'),
                Tab(text: 'Скасовані'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOrdersList(
                  activeOrders,
                  'Немає активних замовлень. Створіть нову заявку на доставку.',
                ),
                _buildOrdersList(
                  deliveredOrders,
                  'Історія доставлених замовлень порожня.',
                ),
                _buildOrdersList(
                  cancelledOrders,
                  'Скасованих замовлень немає.',
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateOrder,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 4,
        icon: const Icon(
          Icons.add_rounded,
          size: 24,
        ),
        label: const Text(
          'Замовити',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}