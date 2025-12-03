import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/status_chip.dart';

class CourierOrderDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const CourierOrderDetailsScreen({super.key, required this.order});

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

  String get _id => _order['id'] ?? _order['_id'];

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
      Navigator.pop(context, true); // повідомляємо список, що є зміни
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

  Widget _buildBottomButton() {
    final status = _order['status'];

    if (status == 'new') {
      return ElevatedButton.icon(
        onPressed: _processing ? null : _accept,
        icon: const Icon(Icons.assignment_turned_in_outlined),
        label: const Text('Прийняти замовлення'),
      );
    } else if (status == 'in_progress') {
      return ElevatedButton.icon(
        onPressed: _processing ? null : _deliver,
        icon: const Icon(Icons.check_circle_outline),
        label: const Text('Позначити як доставлено'),
      );
    } else {
      return const Text(
        'Замовлення вже доставлено',
        style: TextStyle(color: Colors.grey),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final address = _order['address']?.toString() ?? '';
    final desc = _order['description']?.toString() ?? '';
    final phone = _order['phone']?.toString() ?? '';
    final createdAt = _order['created_at']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Деталі замовлення'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.local_shipping_outlined),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            address.isEmpty ? '(без адреси)' : address,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Статус:',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        StatusChip(status: _order['status']),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (phone.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.phone, size: 18),
                          const SizedBox(width: 6),
                          Text(phone),
                        ],
                      ),
                    ],
                    if (createdAt.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Створено: $createdAt',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Опис посилки',
                      style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      desc.isEmpty ? 'Опис не вказано.' : desc,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Матеріали кур’єра',
                      style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'У майбутніх версіях тут можна буде додавати фото доставки, '
                          'коментарі для клієнта та інші дані.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(child: _buildBottomButton()),
          ],
        ),
      ),
    );
  }
}
