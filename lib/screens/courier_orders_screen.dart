import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../services/auth_storage.dart';
import '../theme/theme_notifier.dart';
import '../widgets/status_chip.dart';

import 'courier_order_details_screen.dart';
import 'login_screen.dart';
import 'optimized_route_screen.dart';
import 'profile_screen.dart';

class CourierOrdersScreen extends StatefulWidget {
const CourierOrdersScreen({super.key});

@override
State<CourierOrdersScreen> createState() => _CourierOrdersScreenState();
}

class _CourierOrdersScreenState extends State<CourierOrdersScreen>
with SingleTickerProviderStateMixin {
late final TabController _tabController;

List<dynamic> availableOrders = [];
List<dynamic> activeOrders = [];
List<dynamic> deliveredOrders = [];

final Set<String> selectedOrderIds = <String>{};

bool loading = true;
String selectedCity = '';

static const List<String> cities = [
'',
'Рівне',
'Корець',
'Здолбунів',
'Острог',
];

@override
void initState() {
super.initState();

_tabController = TabController(
length: 3,
vsync: this,
);

_tabController.addListener(_handleTabChanged);

loadOrders();
}

void _handleTabChanged() {
if (_tabController.indexIsChanging) return;

// Вибирати замовлення для оптимізації можна лише
// у вкладці активних замовлень.
if (_tabController.index != 1 && selectedOrderIds.isNotEmpty) {
setState(() {
selectedOrderIds.clear();
});
}
}

Future<void> loadOrders() async {
if (mounted) {
setState(() => loading = true);
}

try {
final results = await Future.wait([
ApiService.getCourierOrders(
'available',
city: selectedCity,
),
ApiService.getCourierOrders(
'active',
city: selectedCity,
),
ApiService.getCourierOrders(
'delivered',
city: selectedCity,
),
]);

if (!mounted) return;

setState(() {
availableOrders = results[0];
activeOrders = results[1];
deliveredOrders = results[2];

selectedOrderIds.clear();
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

Future<void> logout() async {
await AuthStorage.clear();

if (!mounted) return;

Navigator.pushAndRemoveUntil(
context,
MaterialPageRoute(
builder: (_) => const LoginScreen(),
),
(route) => false,
);
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

Future<void> _openDetails(
Map<String, dynamic> order,
) async {
final changed = await Navigator.push<bool>(
context,
MaterialPageRoute(
builder: (_) => CourierOrderDetailsScreen(
order: Map<String, dynamic>.from(order),
),
),
);

if (!mounted) return;

if (changed == true) {
await loadOrders();
}
}

void _toggleSelected(
String orderId,
bool? selected,
) {
if (orderId.isEmpty) return;

setState(() {
if (selected == true) {
selectedOrderIds.add(orderId);
} else {
selectedOrderIds.remove(orderId);
}
});
}

List<Map<String, dynamic>> _getSelectedOrders() {
return activeOrders
    .where(
(order) => selectedOrderIds.contains(
(order as Map)['id']?.toString() ?? '',
),
)
    .map(
(order) => Map<String, dynamic>.from(
order as Map,
),
)
    .toList();
}

Future<void> _openOptimizedRoute() async {
final selectedOrders = _getSelectedOrders();

if (selectedOrders.length < 2) {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
behavior: SnackBarBehavior.floating,
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(12),
),
content: const Text(
'Оберіть мінімум 2 активні замовлення',
),
),
);

return;
}

final routeChanged = await Navigator.push<bool>(
context,
MaterialPageRoute(
builder: (_) => OptimizedRouteScreen(
orders: selectedOrders,
),
),
);

if (!mounted) return;

if (routeChanged == true) {
await loadOrders();
_tabController.animateTo(1);
}
}

Widget _buildOrderCard(
Map<String, dynamic> order,
) {
final theme = Theme.of(context);
final isDark = theme.brightness == Brightness.dark;

final orderId =
order['id']?.toString().trim() ?? '';

final status =
order['status']?.toString().trim() ?? 'new';

final isActive = status == 'in_progress';
final isSelected = selectedOrderIds.contains(orderId);

final orderType =
order['order_type']?.toString() ?? 'parcel';

final pickupAddress =
order['pickup_address']?.toString().trim() ?? '';

final deliveryAddress =
order['delivery_address']?.toString().trim() ?? '';

final description =
order['description']?.toString().trim() ?? '';

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
color: isSelected
? theme.colorScheme.primary.withValues(
alpha: isDark ? 0.15 : 0.06,
)
    : isDark
? const Color(0xFF1E222D)
    : Colors.white,
borderRadius: BorderRadius.circular(24),
boxShadow: [
BoxShadow(
color: Colors.black.withValues(
alpha: isDark ? 0.12 : 0.03,
),
blurRadius: 10,
offset: const Offset(0, 4),
),
],
border: Border.all(
color: isSelected
? theme.colorScheme.primary
    : isDark
? Colors.white.withValues(alpha: 0.05)
    : Colors.black.withValues(alpha: 0.03),
width: isSelected ? 2 : 1,
),
),
child: ClipRRect(
borderRadius: BorderRadius.circular(24),
child: Material(
color: Colors.transparent,
child: InkWell(
onTap: () {
if (selectedOrderIds.isNotEmpty && isActive) {
_toggleSelected(
orderId,
!isSelected,
);
} else {
_openDetails(order);
}
},
onLongPress: isActive
? () {
_toggleSelected(
orderId,
!isSelected,
);
}
    : null,
child: Padding(
padding: const EdgeInsets.all(16),
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Row(
children: [
if (isActive) ...[
SizedBox(
width: 24,
height: 24,
child: Checkbox(
value: isSelected,
activeColor:
theme.colorScheme.primary,
shape: RoundedRectangleBorder(
borderRadius:
BorderRadius.circular(6),
),
onChanged: (value) {
_toggleSelected(
orderId,
value,
);
},
),
),
const SizedBox(width: 8),
],
Container(
padding: const EdgeInsets.all(8),
decoration: BoxDecoration(
color: theme.colorScheme.primary
    .withValues(alpha: 0.1),
borderRadius:
BorderRadius.circular(10),
),
child: Icon(
_orderTypeIcon(orderType),
color: theme.colorScheme.primary,
size: 17,
),
),
const SizedBox(width: 10),
Expanded(
child: Text(
_orderTypeText(orderType),
style: const TextStyle(
fontWeight: FontWeight.bold,
fontSize: 14.5,
),
),
),
StatusChip(status: status),
],
),
const SizedBox(height: 16),

Row(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Column(
children: [
const SizedBox(height: 4),
Container(
width: 9,
height: 9,
decoration: const BoxDecoration(
color: Color(0xFF34C759),
shape: BoxShape.circle,
),
),
Container(
width: 1.5,
height: 36,
color: isDark
? Colors.white10
    : Colors.black12,
),
const Icon(
Icons.location_on_rounded,
size: 13,
color: Color(0xFFFF3B30),
),
],
),
const SizedBox(width: 12),
Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(
pickupAddress.isEmpty
? 'Адресу забору не вказано'
    : pickupAddress,
style: const TextStyle(
fontSize: 13,
fontWeight: FontWeight.w600,
),
maxLines: 1,
overflow:
TextOverflow.ellipsis,
),
const SizedBox(height: 19),
Text(
deliveryAddress.isEmpty
? 'Адресу доставки не вказано'
    : deliveryAddress,
style: const TextStyle(
fontSize: 13,
fontWeight: FontWeight.w600,
),
maxLines: 1,
overflow:
TextOverflow.ellipsis,
),
],
),
),
],
),

if (description.isNotEmpty) ...[
const SizedBox(height: 12),
Container(
width: double.infinity,
padding: const EdgeInsets.all(10),
decoration: BoxDecoration(
color: isDark
? Colors.white.withValues(
alpha: 0.025,
)
    : Colors.black.withValues(
alpha: 0.025,
),
borderRadius:
BorderRadius.circular(10),
),
child: Text(
description,
style: TextStyle(
fontSize: 12,
height: 1.35,
color: theme.hintColor,
),
maxLines: 2,
overflow: TextOverflow.ellipsis,
),
),
],

const SizedBox(height: 14),
Divider(
height: 1,
color: isDark
? Colors.white10
    : Colors.black.withValues(alpha: 0.05),
),
const SizedBox(height: 14),

Wrap(
spacing: 8,
runSpacing: 8,
crossAxisAlignment:
WrapCrossAlignment.center,
children: [
if (city.isNotEmpty)
_buildMiniBadge(
context,
Icons.location_city_rounded,
city,
),
_buildMiniBadge(
context,
Icons.navigation_rounded,
'$distance км',
),
_buildMiniBadge(
context,
Icons.access_time_filled_rounded,
'$estimatedTime хв',
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

Widget _buildMiniBadge(
BuildContext context,
IconData icon,
String label,
) {
final theme = Theme.of(context);
final isDark = theme.brightness == Brightness.dark;

return Container(
padding: const EdgeInsets.symmetric(
horizontal: 10,
vertical: 7,
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
size: 12,
color: theme.colorScheme.onSurfaceVariant,
),
const SizedBox(width: 5),
Text(
label,
style: TextStyle(
fontSize: 11,
fontWeight: FontWeight.bold,
color: theme.colorScheme.onSurfaceVariant,
),
),
],
),
);
}

Widget _buildOrdersList(
List<dynamic> orders,
String emptyText,
) {
if (loading) {
return _buildSkeletonLoader();
}

return RefreshIndicator(
onRefresh: loadOrders,
color: Theme.of(context).colorScheme.primary,
child: orders.isEmpty
? ListView(
physics:
const AlwaysScrollableScrollPhysics(),
children: [
SizedBox(
height:
MediaQuery.of(context).size.height *
0.22,
),
Center(
child: Padding(
padding: const EdgeInsets.all(24),
child: Column(
children: [
Icon(
Icons.inbox_rounded,
size: 54,
color: Theme.of(context)
    .hintColor
    .withValues(alpha: 0.5),
),
const SizedBox(height: 16),
Text(
emptyText,
textAlign: TextAlign.center,
style: TextStyle(
fontSize: 14,
height: 1.4,
color: Theme.of(context)
    .hintColor,
),
),
],
),
),
),
],
)
    : ListView.builder(
physics:
const AlwaysScrollableScrollPhysics(),
padding: const EdgeInsets.only(
top: 8,
bottom: 90,
),
itemCount: orders.length,
itemBuilder: (context, index) {
final order =
Map<String, dynamic>.from(
orders[index] as Map,
);

return _buildOrderCard(order);
},
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
height: 150,
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
padding: const EdgeInsets.all(16),
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Row(
children: [
const CircleAvatar(
radius: 14,
backgroundColor: Colors.black12,
),
const SizedBox(width: 12),
Container(
width: 90,
height: 12,
color: Colors.black12,
),
const Spacer(),
Container(
width: 65,
height: 18,
color: Colors.black12,
),
],
),
const SizedBox(height: 20),
Container(
width: 200,
height: 10,
color: Colors.black12,
),
const SizedBox(height: 10),
Container(
width: 150,
height: 10,
color: Colors.black12,
),
],
),
),
);
},
);
}

void _openCourierProfile() {
final theme = Theme.of(context);
final isDark = theme.brightness == Brightness.dark;

showModalBottomSheet(
context: context,
backgroundColor: Colors.transparent,
builder: (context) {
return Container(
decoration: BoxDecoration(
color: isDark
? const Color(0xFF1E222D)
    : Colors.white,
borderRadius: const BorderRadius.only(
topLeft: Radius.circular(30),
topRight: Radius.circular(30),
),
),
padding: EdgeInsets.only(
left: 24,
right: 24,
top: 14,
bottom:
24 + MediaQuery.of(context).padding.bottom,
),
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
Container(
width: 40,
height: 4,
decoration: BoxDecoration(
color: theme.hintColor
    .withValues(alpha: 0.3),
borderRadius:
BorderRadius.circular(10),
),
),
const SizedBox(height: 20),
CircleAvatar(
radius: 36,
backgroundColor:
theme.colorScheme.primary
    .withValues(alpha: 0.1),
child: Text(
'К',
style: TextStyle(
fontSize: 28,
fontWeight: FontWeight.bold,
color: theme.colorScheme.primary,
),
),
),
const SizedBox(height: 16),
const Text(
'Робоче місце кур’єра',
style: TextStyle(
fontSize: 18,
fontWeight: FontWeight.bold,
),
),
const SizedBox(height: 6),
Row(
mainAxisAlignment:
MainAxisAlignment.center,
children: [
Container(
width: 8,
height: 8,
decoration: const BoxDecoration(
color: Color(0xFF34C759),
shape: BoxShape.circle,
),
),
const SizedBox(width: 6),
Text(
'Статус: активний',
style: TextStyle(
color: theme.hintColor,
fontSize: 13,
),
),
],
),
const SizedBox(height: 24),
Row(
children: [
Expanded(
child: OutlinedButton.icon(
style: OutlinedButton.styleFrom(
padding:
const EdgeInsets.symmetric(
vertical: 14,
),
shape: RoundedRectangleBorder(
borderRadius:
BorderRadius.circular(16),
),
),
onPressed: () {
Navigator.pop(context);

Navigator.push(
context,
MaterialPageRoute(
builder: (_) =>
const ProfileScreen(),
),
);
},
icon: const Icon(
Icons.person_outline_rounded,
),
label: const Text('Профіль'),
),
),
const SizedBox(width: 12),
Expanded(
child: ElevatedButton.icon(
style: ElevatedButton.styleFrom(
backgroundColor:
const Color(0xFFFF3B30),
foregroundColor: Colors.white,
padding:
const EdgeInsets.symmetric(
vertical: 14,
),
elevation: 0,
shape: RoundedRectangleBorder(
borderRadius:
BorderRadius.circular(16),
),
),
onPressed: () {
Navigator.pop(context);
logout();
},
icon: const Icon(
Icons.logout_rounded,
),
label: const Text('Вийти'),
),
),
],
),
],
),
);
},
);
}

Widget _buildCityChips() {
final theme = Theme.of(context);

return SizedBox(
height: 54,
child: ListView.builder(
scrollDirection: Axis.horizontal,
physics: const BouncingScrollPhysics(),
padding: const EdgeInsets.symmetric(
horizontal: 16,
vertical: 8,
),
itemCount: cities.length,
itemBuilder: (context, index) {
final city = cities[index];
final isSelected = selectedCity == city;

return Padding(
padding: const EdgeInsets.only(right: 8),
child: ChoiceChip(
label: Text(
city.isEmpty ? 'Усі міста' : city,
),
selected: isSelected,
onSelected: (_) async {
setState(() {
selectedCity = city;
selectedOrderIds.clear();
});

await loadOrders();
},
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(14),
),
selectedColor: theme.colorScheme.primary
    .withValues(alpha: 0.15),
checkmarkColor: theme.colorScheme.primary,
backgroundColor: Colors.transparent,
side: BorderSide(
color: isSelected
? theme.colorScheme.primary
    : theme.dividerColor
    .withValues(alpha: 0.15),
),
labelStyle: TextStyle(
color: isSelected
? theme.colorScheme.primary
    : theme.hintColor,
fontWeight: isSelected
? FontWeight.bold
    : FontWeight.w500,
fontSize: 12.5,
),
),
);
},
),
);
}

Widget? _buildFloatingButton() {
if (selectedOrderIds.length < 2) {
return null;
}

return FloatingActionButton.extended(
onPressed: _openOptimizedRoute,
backgroundColor:
Theme.of(context).colorScheme.primary,
foregroundColor:
Theme.of(context).colorScheme.onPrimary,
icon: const Icon(Icons.alt_route_rounded),
label: Text(
'Оптимізувати: ${selectedOrderIds.length}',
style: const TextStyle(
fontWeight: FontWeight.bold,
),
),
);
}

@override
void dispose() {
_tabController.removeListener(_handleTabChanged);
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
'Доставки кур’єра',
style: TextStyle(
fontWeight: FontWeight.w800,
fontSize: 20,
),
),
actions: [
IconButton(
icon: const Icon(
Icons.person_outline_rounded,
size: 26,
),
tooltip: 'Профіль кур’єра',
onPressed: _openCourierProfile,
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
_buildCityChips(),

if (selectedOrderIds.isNotEmpty)
Container(
width: double.infinity,
margin: const EdgeInsets.fromLTRB(
16,
4,
16,
8,
),
padding: const EdgeInsets.symmetric(
horizontal: 16,
vertical: 12,
),
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(16),
color: theme.colorScheme.primaryContainer
    .withValues(alpha: 0.5),
border: Border.all(
color: theme.colorScheme.primary
    .withValues(alpha: 0.1),
),
),
child: Row(
children: [
Icon(
Icons.info_outline_rounded,
color: theme.colorScheme.primary,
size: 18,
),
const SizedBox(width: 10),
Expanded(
child: Text(
selectedOrderIds.length >= 2
? 'Обрано ${selectedOrderIds.length} замовлень для побудови маршруту.'
    : 'Оберіть щонайменше ще одне активне замовлення.',
style: TextStyle(
fontSize: 12,
fontWeight: FontWeight.w600,
color: theme.colorScheme
    .onPrimaryContainer,
),
),
),
IconButton(
tooltip: 'Скасувати вибір',
onPressed: () {
setState(() {
selectedOrderIds.clear();
});
},
icon: const Icon(
Icons.close_rounded,
size: 18,
),
),
],
),
),

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
color: Colors.black
    .withValues(alpha: 0.05),
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
Tab(text: 'Доступні'),
Tab(text: 'Активні'),
Tab(text: 'Доставлені'),
],
),
),

Expanded(
child: TabBarView(
controller: _tabController,
children: [
_buildOrdersList(
availableOrders,
'Зараз доступних замовлень немає.',
),
_buildOrdersList(
activeOrders,
'Немає активних замовлень. Прийміть замовлення у вкладці «Доступні».',
),
_buildOrdersList(
deliveredOrders,
'Історія доставлених замовлень порожня.',
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

