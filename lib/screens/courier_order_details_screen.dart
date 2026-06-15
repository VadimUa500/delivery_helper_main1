import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../widgets/status_chip.dart';
import 'route_preview_screen.dart';

class CourierOrderDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const CourierOrderDetailsScreen({
    super.key,
    required this.order,
  });

  @override
  State<CourierOrderDetailsScreen> createState() =>
      _CourierOrderDetailsScreenState();
}

class _CourierOrderDetailsScreenState extends State<CourierOrderDetailsScreen> {
  late Map<String, dynamic> _order;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _order = Map<String, dynamic>.from(widget.order);
  }

  String get _id => (_order['id'] ?? _order['_id']).toString();

  String _orderTypeText(String? type) {
    switch (type) {
      case 'documents':
        return 'Передача документів';
      case 'parcel':
        return 'Передача посилки';
      default:
        return 'Замовлення доставки';
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

  Future<void> _callPhone(String phone) async {
    final cleanedPhone = phone.replaceAll(RegExp(r'\s+'), '');

    if (cleanedPhone.isEmpty) return;

    final uri = Uri(scheme: 'tel', path: cleanedPhone);

    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: const Text('Не вдалося відкрити телефонний застосунок'),
        ),
      );
    }
  }

  Future<void> _accept() async {
    setState(() => _processing = true);

    try {
      final res = await ApiService.acceptOrder(_id);

      if (!mounted) return;

      setState(() {
        _order['status'] = 'in_progress';
        _processing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text(res['message'] ?? 'Замовлення прийнято'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _processing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text('Помилка: $e'),
        ),
      );
    }
  }

  Future<void> _deliver() async {
    setState(() => _processing = true);

    try {
      final res = await ApiService.deliverOrder(_id);

      if (!mounted) return;

      setState(() {
        _order['status'] = 'delivered';
        _processing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text(res['message'] ?? 'Позначено як доставлено'),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() => _processing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text('Помилка: $e'),
        ),
      );
    }
  }

  Future<void> _openRoute() async {
    try {
      final route = await ApiService.getOrderRoute(_id);

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RoutePreviewScreen(route: route),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text('Помилка відкриття маршруту: $e'),
        ),
      );
    }
  }

  Widget _buildInfoRow(
      IconData icon,
      String title,
      String value,
      BuildContext context,
      ) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isPhone = title == 'Контакт клієнта';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.hintColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (isPhone)
            IconButton(
              icon: const Icon(Icons.call, color: Color(0xFF34C759), size: 20),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF34C759).withValues(alpha: 0.1),
                padding: const EdgeInsets.all(8),
              ),
              onPressed: () => _callPhone(value),
            ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
      BuildContext context,
      IconData icon,
      String value,
      String unit,
      String label,
      ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E222D) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.03),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 24),
            const SizedBox(height: 12),
            Row(
              textBaseline: TextBaseline.alphabetic,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: theme.hintColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: theme.hintColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final status = _order['status']?.toString() ?? 'new';
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget buttonContent;

    if (status == 'new') {
      buttonContent = ElevatedButton.icon(
        onPressed: _processing ? null : _accept,
        icon: _processing
            ? const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        )
            : const Icon(Icons.assignment_turned_in_rounded),
        label: Text(_processing ? 'Обробка...' : 'Прийняти замовлення'),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          minimumSize: const Size(double.infinity, 56),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    } else if (status == 'in_progress') {
      buttonContent = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton.icon(
            onPressed: _openRoute,
            icon: const Icon(Icons.map_rounded),
            label: const Text('Відкрити навігатор / карту'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.secondaryContainer,
              foregroundColor: theme.colorScheme.onSecondaryContainer,
              minimumSize: const Size(double.infinity, 54),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _processing ? null : _deliver,
            icon: _processing
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : const Icon(Icons.check_circle_rounded),
            label: Text(_processing ? 'Обробка...' : 'Позначити як доставлено'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF34C759),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      );
    } else if (status == 'delivered') {
      buttonContent = Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF34C759).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF34C759)),
            SizedBox(width: 8),
            Text(
              'Замовлення вже доставлено',
              style: TextStyle(
                color: Color(0xFF34C759),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    } else {
      buttonContent = Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: theme.disabledColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_rounded, color: theme.hintColor),
            const SizedBox(width: 8),
            Text(
              'Замовлення скасовано або недоступне',
              style: TextStyle(
                color: theme.hintColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).padding.bottom > 0
            ? MediaQuery.of(context).padding.bottom + 8
            : 16,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222D) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: buttonContent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final orderType = _order['order_type']?.toString() ?? 'parcel';
    final city = _order['city']?.toString() ?? '';
    final pickupAddress = _order['pickup_address']?.toString() ?? '';
    final deliveryAddress = _order['delivery_address']?.toString() ?? '';
    final description = _order['description']?.toString() ?? '';
    final phone = _order['phone']?.toString() ?? '';
    final comment = _order['comment']?.toString() ?? '';
    final distance = _order['distance_km']?.toString() ?? '0';
    final time = _order['estimated_time_min']?.toString() ?? '0';
    final createdAt = _order['created_at']?.toString() ?? '';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF13151A) : const Color(0xFFF8F9FD),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: theme.textTheme.titleLarge?.color,
        title: const Text(
          'Деталі доставки',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E222D) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.03),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _orderTypeIcon(orderType),
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _orderTypeText(orderType),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      StatusChip(status: _order['status']),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(
                    color: isDark
                        ? Colors.white10
                        : Colors.black.withValues(alpha: 0.05),
                    height: 1,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          const SizedBox(height: 4),
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: const Color(0xFF34C759),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                          Container(
                            width: 1.5,
                            height: 44,
                            color: isDark ? Colors.white10 : Colors.black12,
                          ),
                          const Icon(
                            Icons.location_on,
                            size: 14,
                            color: Color(0xFFFF3B30),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pickupAddress,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Адреса забору',
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.hintColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              deliveryAddress,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Адреса доставки',
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.hintColor,
                                fontWeight: FontWeight.w500,
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
            const SizedBox(height: 12),
            Row(
              children: [
                _buildMetricCard(
                  context,
                  Icons.directions_rounded,
                  distance,
                  'км',
                  'Відстань',
                ),
                const SizedBox(width: 12),
                _buildMetricCard(
                  context,
                  Icons.hourglass_top_rounded,
                  time,
                  'хв',
                  'Час доставки',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E222D) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.03),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Додаткова інформація',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.location_city_rounded,
                    'Місто замовлення',
                    city,
                    context,
                  ),
                  _buildInfoRow(
                    Icons.phone_rounded,
                    'Контакт клієнта',
                    phone,
                    context,
                  ),
                  _buildInfoRow(
                    Icons.calendar_month_rounded,
                    'Створено',
                    createdAt,
                    context,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E222D) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.03),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Деталі відправлення',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description.isEmpty ? 'Опис відсутній.' : description,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                    ),
                  ),
                  if (comment.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Divider(
                      color: isDark
                          ? Colors.white10
                          : Colors.black.withValues(alpha: 0.05),
                      height: 1,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Коментар кур’єру',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      comment,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
      bottomNavigationBar: _buildActionButtons(),
    );
  }
}