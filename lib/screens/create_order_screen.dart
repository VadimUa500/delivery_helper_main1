import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/api_service.dart';
import '../services/map_service.dart';

class CreateOrderScreen extends StatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final _formKey = GlobalKey<FormState>();

  String orderType = 'parcel';
  String city = 'Рівне';

  final pickupAddressController = TextEditingController();
  final deliveryAddressController = TextEditingController();
  final descriptionController = TextEditingController();
  final phoneController = TextEditingController();
  final commentController = TextEditingController();

  LatLng? pickupCoords;
  LatLng? deliveryCoords;

  List<Map<String, dynamic>> pickupSuggestions = [];
  List<Map<String, dynamic>> deliverySuggestions = [];

  bool loading = false;
  bool searchingPickup = false;
  bool searchingDelivery = false;

  Future<void> _searchPickup(String value) async {
    if (value.trim().length < 3) {
      setState(() => pickupSuggestions = []);
      return;
    }

    setState(() => searchingPickup = true);

    try {
      final data = await MapService.autocompleteAddress('$value, $city');
      if (!mounted) return;
      setState(() {
        pickupSuggestions = data;
        searchingPickup = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        pickupSuggestions = [];
        searchingPickup = false;
      });
    }
  }

  Future<void> _searchDelivery(String value) async {
    if (value.trim().length < 3) {
      setState(() => deliverySuggestions = []);
      return;
    }

    setState(() => searchingDelivery = true);

    try {
      final data = await MapService.autocompleteAddress('$value, $city');
      if (!mounted) return;
      setState(() {
        deliverySuggestions = data;
        searchingDelivery = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        deliverySuggestions = [];
        searchingDelivery = false;
      });
    }
  }

  Future<void> _selectPickup(Map<String, dynamic> item) async {
    final details = await MapService.getPlaceDetails(item['place_id']);
    setState(() {
      pickupAddressController.text = details['address'];
      pickupCoords = LatLng(details['lat'], details['lng']);
      pickupSuggestions = [];
    });
  }

  Future<void> _selectDelivery(Map<String, dynamic> item) async {
    final details = await MapService.getPlaceDetails(item['place_id']);
    setState(() {
      deliveryAddressController.text = details['address'];
      deliveryCoords = LatLng(details['lat'], details['lng']);
      deliverySuggestions = [];
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => loading = true);

    try {
      final pickupAddress = pickupAddressController.text.trim();
      final deliveryAddress = deliveryAddressController.text.trim();

      final LatLng finalPickupCoords = pickupCoords ??
          await MapService.geocodeAddress('$pickupAddress, $city, Україна');

      final LatLng finalDeliveryCoords = deliveryCoords ??
          await MapService.geocodeAddress('$deliveryAddress, $city, Україна');

      await ApiService.createOrder(
        orderType: orderType,
        city: city,
        pickupAddress: pickupAddress,
        pickupLat: finalPickupCoords.latitude,
        pickupLng: finalPickupCoords.longitude,
        deliveryAddress: deliveryAddress,
        deliveryLat: finalDeliveryCoords.latitude,
        deliveryLng: finalDeliveryCoords.longitude,
        description: descriptionController.text.trim(),
        phone: phoneController.text.trim(),
        comment: commentController.text.trim(),
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
    pickupAddressController.dispose();
    deliveryAddressController.dispose();
    descriptionController.dispose();
    phoneController.dispose();
    commentController.dispose();
    super.dispose();
  }

  String get _descriptionLabel {
    return orderType == 'parcel'
        ? 'Що потрібно передати'
        : 'Що потрібно замовити / доставити';
  }

  String get _pickupLabel {
    return orderType == 'parcel'
        ? 'Звідки забрати посилку'
        : 'Звідки забрати товар / їжу';
  }

  String get _deliveryLabel {
    return orderType == 'parcel'
        ? 'Куди доставити посилку'
        : 'Куди доставити замовлення';
  }

  Widget _suggestionsList(
      List<Map<String, dynamic>> suggestions,
      Future<void> Function(Map<String, dynamic>) onSelect,
      ) {
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(top: 4),
      child: Column(
        children: suggestions.map((item) {
          return ListTile(
            dense: true,
            leading: const Icon(Icons.place_outlined),
            title: Text(
              item['description'] ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => onSelect(item),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Нове замовлення'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Тип доставки',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      RadioListTile<String>(
                        title: const Text('Передати посилку / документи'),
                        subtitle: const Text(
                          'Кур’єр забирає від вас і доставляє іншій людині',
                        ),
                        value: 'parcel',
                        groupValue: orderType,
                        onChanged: (v) {
                          setState(() => orderType = v ?? 'parcel');
                        },
                      ),
                      RadioListTile<String>(
                        title: const Text('Замовити їжу / товар до себе'),
                        subtitle: const Text(
                          'Кур’єр забирає товар або їжу і доставляє вам',
                        ),
                        value: 'food',
                        groupValue: orderType,
                        onChanged: (v) {
                          setState(() => orderType = v ?? 'food');
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: city,
                decoration: const InputDecoration(
                  labelText: 'Місто',
                  prefixIcon: Icon(Icons.location_city),
                ),
                items: const [
                  DropdownMenuItem(value: 'Рівне', child: Text('Рівне')),
                  DropdownMenuItem(value: 'Корець', child: Text('Корець')),
                  DropdownMenuItem(value: 'Здолбунів', child: Text('Здолбунів')),
                  DropdownMenuItem(value: 'Острог', child: Text('Острог')),
                ],
                onChanged: (v) {
                  setState(() {
                    city = v ?? 'Рівне';
                    pickupCoords = null;
                    deliveryCoords = null;
                    pickupSuggestions = [];
                    deliverySuggestions = [];
                  });
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: pickupAddressController,
                decoration: InputDecoration(
                  labelText: _pickupLabel,
                  prefixIcon: const Icon(Icons.my_location_outlined),
                  suffixIcon: searchingPickup
                      ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                      : null,
                ),
                onChanged: (v) {
                  pickupCoords = null;
                  _searchPickup(v);
                },
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) return 'Введіть адресу забору';
                  if (value.length < 3) return 'Адреса надто коротка';
                  return null;
                },
              ),
              _suggestionsList(pickupSuggestions, _selectPickup),
              const SizedBox(height: 12),
              TextFormField(
                controller: deliveryAddressController,
                decoration: InputDecoration(
                  labelText: _deliveryLabel,
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  suffixIcon: searchingDelivery
                      ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                      : null,
                ),
                onChanged: (v) {
                  deliveryCoords = null;
                  _searchDelivery(v);
                },
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) return 'Введіть адресу доставки';
                  if (value.length < 3) return 'Адреса надто коротка';
                  return null;
                },
              ),
              _suggestionsList(deliverySuggestions, _selectDelivery),
              const SizedBox(height: 12),
              TextFormField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: _descriptionLabel,
                  prefixIcon: const Icon(Icons.inventory_2_outlined),
                ),
                maxLines: 2,
                validator: (v) {
                  if ((v ?? '').trim().isEmpty) {
                    return 'Опишіть замовлення';
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
                  if (value.isEmpty) return 'Введіть телефон';
                  if (!RegExp(r'^\+?\d{9,15}$').hasMatch(value)) {
                    return 'Некоректний номер';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: commentController,
                decoration: const InputDecoration(
                  labelText: 'Коментар для кур’єра',
                  prefixIcon: Icon(Icons.comment_outlined),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.map_outlined),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Почніть вводити адресу та виберіть правильний варіант зі списку.',
                        ),
                      ),
                    ],
                  ),
                ),
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}