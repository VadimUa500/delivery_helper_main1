import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CreateOrderScreen extends StatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final addressController = TextEditingController();
  final descController = TextEditingController();
  final phoneController = TextEditingController();
  bool loading = false;
  String? message;

  Future<void> _submit() async {
    setState(() => loading = true);
    try {
      await ApiService.createOrder(
        addressController.text,
        descController.text,
        phoneController.text,
      );
      setState(() => message = '✅ Замовлення створено');
      Navigator.pop(context, true); // повертаємося на список
    } catch (e) {
      setState(() => message = 'Помилка: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Нове замовлення')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: addressController, decoration: const InputDecoration(labelText: 'Адреса')),
            TextField(controller: descController, decoration: const InputDecoration(labelText: 'Опис')),
            TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Телефон')),
            const SizedBox(height: 20),
            if (message != null) Text(message!, style: const TextStyle(color: Colors.green)),
            ElevatedButton(
              onPressed: loading ? null : _submit,
              child: loading
                  ? const CircularProgressIndicator()
                  : const Text('Створити'),
            ),
          ],
        ),
      ),
    );
  }
}
