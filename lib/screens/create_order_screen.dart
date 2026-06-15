import 'dart:async';

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

  Timer? _pickupDebounce;
  Timer? _deliveryDebounce;

  bool loading = false;
  bool searchingPickup = false;
  bool searchingDelivery = false;

  /// Локальні адреси, які відображаються одразу після вибору міста.
  ///
  /// За потреби ці адреси можна замінити на інші актуальні точки.
  final Map<String, List<String>> popularAddressesByCity = const {
    'Рівне': [
      'вулиця Соборна, 55, Рівне',
      'майдан Незалежності, Рівне',
      'вулиця Київська, 40, Рівне',
      'Привокзальна площа, Рівне',
      'вулиця Відінська, Рівне',
    ],
    'Корець': [
      'площа Київська, Корець',
      'вулиця Київська, Корець',
      'вулиця Незалежності, Корець',
      'вулиця Старомонастирська, Корець',
    ],
    'Здолбунів': [
      'вулиця Грушевського, Здолбунів',
      'вулиця Шкільна, Здолбунів',
      'вулиця Незалежності, Здолбунів',
      'Привокзальна площа, Здолбунів',
    ],
    'Острог': [
      'проспект Незалежності, Острог',
      'вулиця Героїв Майдану, Острог',
      'вулиця Академічна, Острог',
      'вулиця Татарська, Острог',
    ],
  };

  @override
  void initState() {
    super.initState();

    pickupSuggestions = _popularSuggestionItems();
    deliverySuggestions = _popularSuggestionItems();
  }

  List<Map<String, dynamic>> _popularSuggestionItems() {
    final addresses = popularAddressesByCity[city] ?? const <String>[];

    return addresses
        .map(
          (address) => <String, dynamic>{
        'description': address,
        'place_id': '',
        'is_preset': true,
      },
    )
        .toList();
  }

  void _showPickupPresets() {
    if (pickupAddressController.text.trim().isNotEmpty) return;

    setState(() {
      pickupSuggestions = _popularSuggestionItems();
    });
  }

  void _showDeliveryPresets() {
    if (deliveryAddressController.text.trim().isNotEmpty) return;

    setState(() {
      deliverySuggestions = _popularSuggestionItems();
    });
  }

  void _searchPickup(String value) {
    pickupCoords = null;
    _pickupDebounce?.cancel();

    final query = value.trim();

    if (query.isEmpty) {
      setState(() {
        pickupSuggestions = _popularSuggestionItems();
        searchingPickup = false;
      });
      return;
    }

    if (query.length < 3) {
      setState(() {
        pickupSuggestions = [];
        searchingPickup = false;
      });
      return;
    }

    setState(() => searchingPickup = true);

    _pickupDebounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final data = await MapService.autocompleteAddress('$query, $city');

        if (!mounted) return;

        // Не показуємо результати старого запиту,
        // якщо користувач уже змінив введений текст.
        if (pickupAddressController.text.trim() != query) return;

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
    });
  }

  void _searchDelivery(String value) {
    deliveryCoords = null;
    _deliveryDebounce?.cancel();

    final query = value.trim();

    if (query.isEmpty) {
      setState(() {
        deliverySuggestions = _popularSuggestionItems();
        searchingDelivery = false;
      });
      return;
    }

    if (query.length < 3) {
      setState(() {
        deliverySuggestions = [];
        searchingDelivery = false;
      });
      return;
    }

    setState(() => searchingDelivery = true);

    _deliveryDebounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final data = await MapService.autocompleteAddress('$query, $city');

        if (!mounted) return;

        if (deliveryAddressController.text.trim() != query) return;

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
    });
  }

  Future<void> _selectPickup(Map<String, dynamic> item) async {
    try {
      final isPreset = item['is_preset'] == true;
      final description = item['description']?.toString() ?? '';

      if (description.isEmpty) return;

      if (isPreset) {
        final coordinates = await MapService.geocodeAddress(
          '$description, Україна',
        );

        if (!mounted) return;

        setState(() {
          pickupAddressController.text = description;
          pickupCoords = coordinates;
          pickupSuggestions = [];
        });
        return;
      }

      final placeId = item['place_id']?.toString() ?? '';

      if (placeId.isEmpty) return;

      final details = await MapService.getPlaceDetails(placeId);

      if (!mounted) return;

      setState(() {
        pickupAddressController.text =
            details['address']?.toString() ?? description;

        pickupCoords = LatLng(
          (details['lat'] as num).toDouble(),
          (details['lng'] as num).toDouble(),
        );

        pickupSuggestions = [];
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Не вдалося визначити адресу забору: $e'),
        ),
      );
    }
  }

  Future<void> _selectDelivery(Map<String, dynamic> item) async {
    try {
      final isPreset = item['is_preset'] == true;
      final description = item['description']?.toString() ?? '';

      if (description.isEmpty) return;

      if (isPreset) {
        final coordinates = await MapService.geocodeAddress(
          '$description, Україна',
        );

        if (!mounted) return;

        setState(() {
          deliveryAddressController.text = description;
          deliveryCoords = coordinates;
          deliverySuggestions = [];
        });
        return;
      }

      final placeId = item['place_id']?.toString() ?? '';

      if (placeId.isEmpty) return;

      final details = await MapService.getPlaceDetails(placeId);

      if (!mounted) return;

      setState(() {
        deliveryAddressController.text =
            details['address']?.toString() ?? description;

        deliveryCoords = LatLng(
          (details['lat'] as num).toDouble(),
          (details['lng'] as num).toDouble(),
        );

        deliverySuggestions = [];
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Не вдалося визначити адресу доставки: $e'),
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => loading = true);

    try {
      final pickupAddress = pickupAddressController.text.trim();
      final deliveryAddress = deliveryAddressController.text.trim();

      final finalPickupCoords = pickupCoords ??
          await MapService.geocodeAddress(
            '$pickupAddress, $city, Україна',
          );

      final finalDeliveryCoords = deliveryCoords ??
          await MapService.geocodeAddress(
            '$deliveryAddress, $city, Україна',
          );

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
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: const Text('Замовлення створено'),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Text('Помилка створення: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  void dispose() {
    _pickupDebounce?.cancel();
    _deliveryDebounce?.cancel();

    pickupAddressController.dispose();
    deliveryAddressController.dispose();
    descriptionController.dispose();
    phoneController.dispose();
    commentController.dispose();

    super.dispose();
  }

  String get _descriptionLabel {
    if (orderType == 'documents') {
      return 'Які документи потрібно передати';
    }

    return 'Що міститься у відправленні';
  }

  String get _pickupLabel {
    return 'Адреса забору відправлення';
  }

  String get _deliveryLabel {
    return 'Адреса доставки відправлення';
  }

  InputDecoration _inputDecoration(
      BuildContext context,
      String label,
      IconData icon, {
        Widget? suffix,
      }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: theme.hintColor,
        fontSize: 13.5,
      ),
      prefixIcon: Icon(
        icon,
        color: theme.colorScheme.primary,
        size: 20,
      ),
      suffixIcon: suffix,
      filled: true,
      fillColor: isDark ? const Color(0xFF1E222D) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.03)
              : Colors.black.withValues(alpha: 0.03),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: theme.colorScheme.primary,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Colors.red,
          width: 1,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Colors.red,
          width: 1.5,
        ),
      ),
    );
  }

  Widget _suggestionsList(
      List<Map<String, dynamic>> suggestions,
      Future<void> Function(Map<String, dynamic>) onSelect,
      ) {
    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      constraints: const BoxConstraints(maxHeight: 230),
      margin: const EdgeInsets.only(top: 4, bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252936) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: isDark ? 0.3 : 0.08,
            ),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: suggestions.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            color: theme.dividerColor.withValues(alpha: 0.08),
          ),
          itemBuilder: (context, index) {
            final item = suggestions[index];
            final isPreset = item['is_preset'] == true;

            return ListTile(
              dense: true,
              leading: Icon(
                isPreset
                    ? Icons.star_outline_rounded
                    : Icons.location_on_rounded,
                color: theme.colorScheme.primary,
                size: 19,
              ),
              title: Text(
                item['description']?.toString() ?? '',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: isPreset
                  ? const Text(
                'Популярна адреса',
                style: TextStyle(fontSize: 10.5),
              )
                  : null,
              onTap: () => onSelect(item),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTypeSelector(
      String typeValue,
      String title,
      String subtitle,
      IconData icon,
      ) {
    final theme = Theme.of(context);
    final isSelected = orderType == typeValue;
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        setState(() {
          orderType = typeValue;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(
            alpha: isDark ? 0.15 : 0.05,
          )
              : (isDark ? const Color(0xFF1E222D) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.03),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary.withValues(alpha: 0.1)
                    : theme.disabledColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.hintColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.hintColor,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: theme.colorScheme.primary,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
      isDark ? const Color(0xFF13151A) : const Color(0xFFF8F9FD),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: theme.textTheme.titleLarge?.color,
        title: const Text(
          'Нове замовлення',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(
                  left: 4,
                  bottom: 12,
                ),
                child: Text(
                  'Оберіть тип відправлення',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildTypeSelector(
                'parcel',
                'Посилка або товар',
                'Кур’єр забирає відправлення та доставляє одержувачу',
                Icons.inventory_2_rounded,
              ),
              _buildTypeSelector(
                'documents',
                'Документи',
                'Кур’єр забирає документи та доставляє одержувачу',
                Icons.description_rounded,
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: city,
                decoration: _inputDecoration(
                  context,
                  'Місто виконання',
                  Icons.location_city_rounded,
                ),
                dropdownColor:
                isDark ? const Color(0xFF1E222D) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                items: const [
                  DropdownMenuItem(
                    value: 'Рівне',
                    child: Text('Рівне'),
                  ),
                  DropdownMenuItem(
                    value: 'Корець',
                    child: Text('Корець'),
                  ),
                  DropdownMenuItem(
                    value: 'Здолбунів',
                    child: Text('Здолбунів'),
                  ),
                  DropdownMenuItem(
                    value: 'Острог',
                    child: Text('Острог'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    city = value ?? 'Рівне';

                    pickupCoords = null;
                    deliveryCoords = null;

                    pickupAddressController.clear();
                    deliveryAddressController.clear();

                    pickupSuggestions = _popularSuggestionItems();
                    deliverySuggestions = _popularSuggestionItems();
                  });
                },
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: pickupAddressController,
                decoration: _inputDecoration(
                  context,
                  _pickupLabel,
                  Icons.my_location_rounded,
                  suffix: searchingPickup
                      ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  )
                      : null,
                ),
                onTap: _showPickupPresets,
                onChanged: _searchPickup,
                validator: (value) {
                  final text = (value ?? '').trim();

                  if (text.isEmpty) {
                    return 'Введіть адресу забору';
                  }

                  if (text.length < 3) {
                    return 'Адреса надто коротка';
                  }

                  return null;
                },
              ),
              _suggestionsList(
                pickupSuggestions,
                _selectPickup,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: deliveryAddressController,
                decoration: _inputDecoration(
                  context,
                  _deliveryLabel,
                  Icons.location_on_rounded,
                  suffix: searchingDelivery
                      ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  )
                      : null,
                ),
                onTap: _showDeliveryPresets,
                onChanged: _searchDelivery,
                validator: (value) {
                  final text = (value ?? '').trim();

                  if (text.isEmpty) {
                    return 'Введіть адресу доставки';
                  }

                  if (text.length < 3) {
                    return 'Адреса надто коротка';
                  }

                  return null;
                },
              ),
              _suggestionsList(
                deliverySuggestions,
                _selectDelivery,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: descriptionController,
                decoration: _inputDecoration(
                  context,
                  _descriptionLabel,
                  Icons.assignment_rounded,
                ),
                maxLines: 2,
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Опишіть відправлення';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: phoneController,
                decoration: _inputDecoration(
                  context,
                  'Контактний телефон одержувача',
                  Icons.phone_rounded,
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  final phone = (value ?? '').trim();

                  if (phone.isEmpty) {
                    return 'Введіть телефон';
                  }

                  if (!RegExp(r'^\+?\d{9,15}$').hasMatch(phone)) {
                    return 'Некоректний номер';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: commentController,
                decoration: _inputDecoration(
                  context,
                  'Додатковий коментар кур’єру',
                  Icons.comment_rounded,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Після вибору міста можна одразу обрати одну з популярних адрес або почати вводити точну адресу.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.3,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: loading ? null : _submit,
                  icon: loading
                      ? const SizedBox.shrink()
                      : const Icon(
                    Icons.check_rounded,
                    size: 20,
                  ),
                  label: loading
                      ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: theme.colorScheme.onPrimary,
                    ),
                  )
                      : const Text(
                    'Створити замовлення',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 0.3,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}