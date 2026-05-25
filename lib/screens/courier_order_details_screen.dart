import 'package:flutter/material.dart';
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
      case 'food':
        return 'Доставка їжі / товару';
      case 'parcel':
        return 'Передача посилки';
      default:
        return 'Замовлення';
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
        SnackBar(content: Text(res['message'] ?? 'Замовлення прийнято')),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _processing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Помилка: $e')),
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
        SnackBar(content: Text(res['message'] ?? 'Позначено як доставлено')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() => _processing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Помилка: $e')),
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
        SnackBar(content: Text('Помилка відкриття маршруту: $e')),
      );
    }
  }

  Widget _infoRow(IconData icon, String title, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                  fontSize: 14,
                ),
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final status = _order['status']?.toString() ?? 'new';

    if (status == 'new') {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _processing ? null : _accept,
              icon: const Icon(Icons.assignment_turned_in_outlined),
              label: _processing
                  ? const Text('Обробка...')
                  : const Text('Прийняти замовлення'),
            ),
          ),
        ],
      );
    }

    if (status == 'in_progress') {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openRoute,
              icon: const Icon(Icons.map_outlined),
              label: const Text('Відкрити маршрут'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _processing ? null : _deliver,
              icon: const Icon(Icons.check_circle_outline),
              label: _processing
                  ? const Text('Обробка...')
                  : const Text('Позначити як доставлено'),
            ),
          ),
        ],
      );
    }

    if (status == 'delivered') {
      return const Center(
        child: Text(
          'Замовлення вже доставлено',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return const Center(
      child: Text(
        'Замовлення недоступне',
        style: TextStyle(color: Colors.grey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
      appBar: AppBar(
        title: const Text('Деталі доставки'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.local_shipping_outlined),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _orderTypeText(orderType),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        StatusChip(status: _order['status']),
                      ],
                    ),
                    const Divider(height: 24),
                    _infoRow(Icons.location_city, 'Місто', city),
                    _infoRow(
                      Icons.my_location_outlined,
                      'Звідки забрати',
                      pickupAddress,
                    ),
                    _infoRow(
                      Icons.location_on_outlined,
                      'Куди доставити',
                      deliveryAddress,
                    ),
                    _infoRow(Icons.route_outlined, 'Відстань', '$distance км'),
                    _infoRow(Icons.timer_outlined, 'Орієнтовний час', '$time хв'),
                    _infoRow(Icons.phone_outlined, 'Телефон', phone),
                    _infoRow(Icons.access_time, 'Створено', createdAt),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Опис замовлення',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description.isEmpty
                            ? 'Опис не вказано.'
                            : description,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (comment.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Коментар клієнта',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(comment),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }
}