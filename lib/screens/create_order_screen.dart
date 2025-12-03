import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CreateOrderScreen extends StatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final _formKey = GlobalKey<FormState>();

  final addressController = TextEditingController();
  final descriptionController = TextEditingController();
  final phoneController = TextEditingController();

  bool loading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => loading = true);

    try {
      await ApiService.createOrder(
        addressController.text.trim(),
        descriptionController.text.trim(),
        phoneController.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Замовлення створено')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Помилка створення: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  void dispose() {
    addressController.dispose();
    descriptionController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Нове замовлення')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: 'Адреса доставки',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                validator: (v) {
                  if ((v ?? '').trim().isEmpty) {
                    return 'Введіть адресу';
                  }
                  if (v!.trim().length < 5) {
                    return 'Адреса надто коротка';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Опис посилки',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                maxLines: 2,
                validator: (v) {
                  if ((v ?? '').trim().isEmpty) {
                    return 'Опишіть, що потрібно доставити';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Контактний телефон',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) {
                    return 'Введіть телефон';
                  }
                  if (!RegExp(r'^\+?\d{9,15}$').hasMatch(value)) {
                    return 'Некоректний номер';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: loading ? null : _submit,
                  icon: const Icon(Icons.check),
                  label: loading
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text('Створити замовлення'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
