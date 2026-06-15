import 'package:flutter/material.dart';

import '../widgets/status_chip.dart';
import 'client_tracking_screen.dart';

class ClientOrderDetailsScreen extends StatelessWidget {
final Map<String, dynamic> order;

const ClientOrderDetailsScreen({
super.key,
required this.order,
});

String _stringValue(
String key, {
String fallback = '',
}) {
final value = order[key];

if (value == null) {
return fallback;
}

final text = value.toString().trim();

return text.isEmpty ? fallback : text;
}

String _orderTypeText(String type) {
switch (type) {
case 'documents':
return 'Документи';

case 'parcel':
return 'Посилка або товар';

default:
return 'Доставка';
}
}

IconData _orderTypeIcon(String type) {
switch (type) {
case 'documents':
return Icons.description_rounded;

case 'parcel':
return Icons.inventory_2_rounded;

default:
return Icons.local_shipping_rounded;
}
}

String _statusDescription(String status) {
switch (status) {
case 'new':
return 'Замовлення створено та очікує прийняття кур’єром.';

case 'in_progress':
return 'Кур’єр прийняв замовлення та виконує доставку.';

case 'delivered':
return 'Замовлення успішно доставлено одержувачу.';

case 'cancelled':
return 'Замовлення було скасовано.';

default:
return 'Статус замовлення оновлюється.';
}
}

String _formatDate(dynamic value) {
if (value == null) {
return 'Не вказано';
}

final raw = value.toString().trim();

if (raw.isEmpty || raw == 'null') {
return 'Не вказано';
}

try {
final date = DateTime.parse(raw).toLocal();

final day = date.day.toString().padLeft(2, '0');
final month = date.month.toString().padLeft(2, '0');
final year = date.year.toString();

final hour = date.hour.toString().padLeft(2, '0');
final minute = date.minute.toString().padLeft(2, '0');

return '$day.$month.$year о $hour:$minute';
} catch (_) {
return raw;
}
}

bool _isStageCompleted(
String status,
int stageIndex,
) {
switch (status) {
case 'new':
return stageIndex == 0;

case 'in_progress':
return stageIndex <= 1;

case 'delivered':
return stageIndex <= 2;

default:
return false;
}
}

bool _isCurrentStage(
String status,
int stageIndex,
) {
switch (status) {
case 'new':
return stageIndex == 0;

case 'in_progress':
return stageIndex == 1;

case 'delivered':
return stageIndex == 2;

default:
return false;
}
}

Future<void> _openCourierTracking(
BuildContext context,
) async {
await Navigator.of(context).push(
MaterialPageRoute<void>(
builder: (_) => ClientTrackingScreen(
order: Map<String, dynamic>.from(order),
),
),
);
}

Widget _buildStageItem({
required BuildContext context,
required int index,
required String title,
required String subtitle,
required IconData icon,
required String status,
required bool isLast,
}) {
final theme = Theme.of(context);
final isDark = theme.brightness == Brightness.dark;

final completed = _isStageCompleted(
status,
index,
);

final current = _isCurrentStage(
status,
index,
);

final Color stageColor;

if (completed) {
stageColor = const Color(0xFF34C759);
} else {
stageColor = theme.hintColor.withValues(
alpha: 0.35,
);
}

return Row(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
SizedBox(
width: 44,
child: Column(
children: [
AnimatedContainer(
duration: const Duration(
milliseconds: 250,
),
width: 36,
height: 36,
decoration: BoxDecoration(
color: completed
? stageColor.withValues(
alpha: 0.12,
)
    : isDark
? Colors.white.withValues(
alpha: 0.04,
)
    : Colors.black.withValues(
alpha: 0.03,
),
shape: BoxShape.circle,
border: Border.all(
color: current
? stageColor
    : stageColor.withValues(
alpha: 0.45,
),
width: current ? 2 : 1,
),
),
child: Icon(
completed
? Icons.check_rounded
    : icon,
size: 19,
color: stageColor,
),
),
if (!isLast)
Container(
width: 2,
height: 52,
color: completed
? const Color(0xFF34C759).withValues(
alpha: 0.35,
)
    : theme.hintColor.withValues(
alpha: 0.15,
),
),
],
),
),
const SizedBox(width: 12),
Expanded(
child: Padding(
padding: const EdgeInsets.only(
top: 4,
bottom: 22,
),
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Row(
children: [
Expanded(
child: Text(
title,
style: TextStyle(
fontSize: 14,
fontWeight: current
? FontWeight.w800
    : FontWeight.w600,
color: completed
? theme.textTheme
    .bodyLarge?.color
    : theme.hintColor,
),
),
),
if (current)
Container(
padding:
const EdgeInsets.symmetric(
horizontal: 8,
vertical: 3,
),
decoration: BoxDecoration(
color: const Color(
0xFF34C759,
).withValues(
alpha: 0.1,
),
borderRadius:
BorderRadius.circular(20),
),
child: const Text(
'Поточний етап',
style: TextStyle(
color: Color(0xFF34C759),
fontSize: 10,
fontWeight:
FontWeight.bold,
),
),
),
],
),
const SizedBox(height: 4),
Text(
subtitle,
style: TextStyle(
fontSize: 12,
height: 1.35,
color: theme.hintColor,
),
),
],
),
),
),
],
);
}

Widget _buildInfoRow({
required BuildContext context,
required IconData icon,
required String title,
required String value,
}) {
if (value.trim().isEmpty) {
return const SizedBox.shrink();
}

final theme = Theme.of(context);

return Padding(
padding: const EdgeInsets.symmetric(
vertical: 9,
),
child: Row(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Container(
padding: const EdgeInsets.all(8),
decoration: BoxDecoration(
color: theme.colorScheme.primary
    .withValues(
alpha: 0.08,
),
borderRadius:
BorderRadius.circular(12),
),
child: Icon(
icon,
size: 17,
color: theme.colorScheme.primary,
),
),
const SizedBox(width: 12),
Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(
title,
style: TextStyle(
fontSize: 11,
color: theme.hintColor,
fontWeight: FontWeight.w500,
),
),
const SizedBox(height: 3),
Text(
value,
style: const TextStyle(
fontSize: 13.5,
height: 1.35,
fontWeight: FontWeight.w600,
),
),
],
),
),
],
),
);
}

Widget _buildMetric({
required BuildContext context,
required IconData icon,
required String value,
required String label,
}) {
final theme = Theme.of(context);
final isDark =
theme.brightness == Brightness.dark;

return Expanded(
child: Container(
padding: const EdgeInsets.all(15),
decoration: BoxDecoration(
color: isDark
? const Color(0xFF1E222D)
    : Colors.white,
borderRadius:
BorderRadius.circular(18),
border: Border.all(
color: isDark
? Colors.white.withValues(
alpha: 0.05,
)
    : Colors.black.withValues(
alpha: 0.03,
),
),
),
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Icon(
icon,
size: 21,
color: theme.colorScheme.primary,
),
const SizedBox(height: 10),
Text(
value,
style: const TextStyle(
fontSize: 17,
fontWeight: FontWeight.w800,
),
),
const SizedBox(height: 3),
Text(
label,
style: TextStyle(
fontSize: 11,
color: theme.hintColor,
),
),
],
),
),
);
}

Widget _buildTrackingButton(
BuildContext context,
) {
return SafeArea(
minimum: const EdgeInsets.fromLTRB(
16,
8,
16,
16,
),
child: SizedBox(
width: double.infinity,
height: 54,
child: ElevatedButton.icon(
onPressed: () {
_openCourierTracking(context);
},
icon: const Icon(
Icons.location_searching_rounded,
),
label: const Text(
'Відстежувати кур’єра',
style: TextStyle(
fontSize: 15,
fontWeight: FontWeight.w800,
),
),
style: ElevatedButton.styleFrom(
backgroundColor:
const Color(0xFF007AFF),
foregroundColor: Colors.white,
elevation: 0,
shape: RoundedRectangleBorder(
borderRadius:
BorderRadius.circular(16),
),
),
),
),
);
}

@override
Widget build(BuildContext context) {
final theme = Theme.of(context);
final isDark =
theme.brightness == Brightness.dark;

final status = _stringValue(
'status',
fallback: 'new',
);

final orderType = _stringValue(
'order_type',
fallback: 'parcel',
);

final pickupAddress = _stringValue(
'pickup_address',
fallback: 'Адресу забору не вказано',
);

final deliveryAddress = _stringValue(
'delivery_address',
fallback: 'Адресу доставки не вказано',
);

final city = _stringValue('city');
final description =
_stringValue('description');
final phone = _stringValue('phone');
final comment = _stringValue('comment');

final distance = _stringValue(
'distance_km',
fallback: '0',
);

final estimatedTime = _stringValue(
'estimated_time_min',
fallback: '0',
);

final createdAt = _formatDate(
order['created_at'],
);

final acceptedAt = _formatDate(
order['accepted_at'],
);

final deliveredAt = _formatDate(
order['delivered_at'],
);

return Scaffold(
backgroundColor: isDark
? const Color(0xFF13151A)
    : const Color(0xFFF8F9FD),
appBar: AppBar(
elevation: 0,
backgroundColor: Colors.transparent,
foregroundColor:
theme.textTheme.titleLarge?.color,
title: const Text(
'Моє замовлення',
style: TextStyle(
fontSize: 18,
fontWeight: FontWeight.bold,
),
),
),
body: SingleChildScrollView(
padding: const EdgeInsets.fromLTRB(
16,
8,
16,
28,
),
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Container(
width: double.infinity,
padding: const EdgeInsets.all(20),
decoration: BoxDecoration(
color: isDark
? const Color(0xFF1E222D)
    : Colors.white,
borderRadius:
BorderRadius.circular(24),
border: Border.all(
color: isDark
? Colors.white.withValues(
alpha: 0.05,
)
    : Colors.black.withValues(
alpha: 0.03,
),
),
boxShadow: [
BoxShadow(
color: Colors.black.withValues(
alpha:
isDark ? 0.12 : 0.035,
),
blurRadius: 12,
offset: const Offset(0, 5),
),
],
),
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Row(
children: [
Container(
padding:
const EdgeInsets.all(10),
decoration: BoxDecoration(
color: theme
    .colorScheme.primary
    .withValues(
alpha: 0.1,
),
borderRadius:
BorderRadius.circular(
14,
),
),
child: Icon(
_orderTypeIcon(orderType),
size: 23,
color: theme
    .colorScheme.primary,
),
),
const SizedBox(width: 12),
Expanded(
child: Text(
_orderTypeText(
orderType,
),
style: const TextStyle(
fontSize: 16,
fontWeight:
FontWeight.w800,
),
),
),
StatusChip(
status: status,
),
],
),
const SizedBox(height: 16),
Divider(
height: 1,
color: isDark
? Colors.white10
    : Colors.black.withValues(
alpha: 0.05,
),
),
const SizedBox(height: 16),
Text(
_statusDescription(status),
style: TextStyle(
fontSize: 13.5,
height: 1.4,
color: theme
    .textTheme.bodyMedium
    ?.color
    ?.withValues(
alpha: 0.78,
),
),
),
],
),
),
const SizedBox(height: 14),
if (status == 'cancelled')
Container(
width: double.infinity,
padding: const EdgeInsets.all(18),
decoration: BoxDecoration(
color: Colors.red.withValues(
alpha: 0.08,
),
borderRadius:
BorderRadius.circular(20),
border: Border.all(
color: Colors.red.withValues(
alpha: 0.18,
),
),
),
child: const Row(
children: [
Icon(
Icons.cancel_rounded,
color: Colors.red,
),
SizedBox(width: 12),
Expanded(
child: Text(
'Це замовлення скасовано та більше не виконується.',
style: TextStyle(
color: Colors.red,
fontSize: 13,
fontWeight:
FontWeight.w600,
),
),
),
],
),
)
else
Container(
width: double.infinity,
padding: const EdgeInsets.all(20),
decoration: BoxDecoration(
color: isDark
? const Color(0xFF1E222D)
    : Colors.white,
borderRadius:
BorderRadius.circular(24),
border: Border.all(
color: isDark
? Colors.white.withValues(
alpha: 0.05,
)
    : Colors.black.withValues(
alpha: 0.03,
),
),
),
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
const Text(
'Етапи виконання',
style: TextStyle(
fontSize: 15,
fontWeight:
FontWeight.w800,
),
),
const SizedBox(height: 18),
_buildStageItem(
context: context,
index: 0,
title:
'Замовлення створено',
subtitle: createdAt,
icon:
Icons.receipt_long_rounded,
status: status,
isLast: false,
),
_buildStageItem(
context: context,
index: 1,
title:
'Прийнято кур’єром',
subtitle: status == 'new'
? 'Очікує прийняття кур’єром'
    : acceptedAt,
icon:
Icons.delivery_dining_rounded,
status: status,
isLast: false,
),
_buildStageItem(
context: context,
index: 2,
title: 'Доставлено',
subtitle:
status == 'delivered'
? deliveredAt
    : 'Очікує завершення доставки',
icon:
Icons.task_alt_rounded,
status: status,
isLast: true,
),
],
),
),
const SizedBox(height: 14),
Row(
children: [
_buildMetric(
context: context,
icon:
Icons.navigation_rounded,
value: '$distance км',
label: 'Відстань',
),
const SizedBox(width: 12),
_buildMetric(
context: context,
icon: Icons
    .access_time_filled_rounded,
value: '$estimatedTime хв',
label:
'Орієнтовний час',
),
],
),
const SizedBox(height: 14),
Container(
width: double.infinity,
padding: const EdgeInsets.all(20),
decoration: BoxDecoration(
color: isDark
? const Color(0xFF1E222D)
    : Colors.white,
borderRadius:
BorderRadius.circular(24),
border: Border.all(
color: isDark
? Colors.white.withValues(
alpha: 0.05,
)
    : Colors.black.withValues(
alpha: 0.03,
),
),
),
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
const Text(
'Маршрут доставки',
style: TextStyle(
fontSize: 15,
fontWeight:
FontWeight.w800,
),
),
const SizedBox(height: 10),
_buildInfoRow(
context: context,
icon:
Icons.my_location_rounded,
title: 'Адреса забору',
value: pickupAddress,
),
_buildInfoRow(
context: context,
icon:
Icons.location_on_rounded,
title: 'Адреса доставки',
value: deliveryAddress,
),
if (city.isNotEmpty)
_buildInfoRow(
context: context,
icon: Icons
    .location_city_rounded,
title: 'Місто',
value: city,
),
],
),
),
const SizedBox(height: 14),
Container(
width: double.infinity,
padding: const EdgeInsets.all(20),
decoration: BoxDecoration(
color: isDark
? const Color(0xFF1E222D)
    : Colors.white,
borderRadius:
BorderRadius.circular(24),
border: Border.all(
color: isDark
? Colors.white.withValues(
alpha: 0.05,
)
    : Colors.black.withValues(
alpha: 0.03,
),
),
),
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
const Text(
'Інформація про відправлення',
style: TextStyle(
fontSize: 15,
fontWeight:
FontWeight.w800,
),
),
const SizedBox(height: 10),
if (description.isNotEmpty)
_buildInfoRow(
context: context,
icon: Icons
    .inventory_2_outlined,
title: 'Опис',
value: description,
),
if (phone.isNotEmpty)
_buildInfoRow(
context: context,
icon:
Icons.phone_rounded,
title:
'Контактний телефон',
value: phone,
),
if (comment.isNotEmpty)
_buildInfoRow(
context: context,
icon:
Icons.comment_rounded,
title:
'Коментар кур’єру',
value: comment,
),
if (description.isEmpty &&
phone.isEmpty &&
comment.isEmpty)
Text(
'Додаткову інформацію не вказано.',
style: TextStyle(
fontSize: 13,
color: theme.hintColor,
),
),
],
),
),
],
),
),
bottomNavigationBar:
status == 'in_progress'
? _buildTrackingButton(context)
    : null,
);
}
}

