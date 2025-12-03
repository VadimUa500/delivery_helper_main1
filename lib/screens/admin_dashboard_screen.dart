import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../services/auth_storage.dart';
import 'login_screen.dart';
import '../theme/theme_notifier.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  List<dynamic> users = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => loading = true);
    try {
      final data = await ApiService.getAllUsers();
      setState(() {
        users = data;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Помилка завантаження користувачів: $e')),
      );
    }
  }

  Future<void> _logout() async {
    await AuthStorage.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  Color _roleColor(String role, BuildContext context) {
    switch (role) {
      case 'admin':
        return Colors.redAccent;
      case 'courier':
        return Colors.orangeAccent;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  Widget _buildRoleChip(String role, bool isActive) {
    final color = _roleColor(role, context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color),
          ),
          child: Text(
            role,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Icon(
          isActive ? Icons.check_circle : Icons.cancel,
          size: 16,
          color: isActive ? Colors.green : Colors.redAccent,
        ),
      ],
    );
  }

  Future<void> _changeRoleDialog(Map<String, dynamic> u) async {
    final userId = u['id'] as String;
    String currentRole = (u['role'] ?? 'client') as String;
    String selectedRole = currentRole;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Змінити роль користувача'),
          content: DropdownButtonFormField<String>(
            value: selectedRole,
            items: const [
              DropdownMenuItem(value: 'client', child: Text('Клієнт')),
              DropdownMenuItem(value: 'courier', child: Text('Кур’єр')),
              DropdownMenuItem(value: 'admin', child: Text('Адмін')),
            ],
            onChanged: (v) {
              if (v != null) {
                selectedRole = v;
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Скасувати'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context); // закриваємо діалог
                try {
                  final res = await ApiService.updateUser(userId, role: selectedRole);
                  if (!mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(res['message'] ?? 'Роль оновлено')),
                  );
                  await _loadUsers();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Помилка: $e')),
                  );
                }
              },
              child: const Text('Зберегти'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _toggleBlockUser(Map<String, dynamic> u) async {
    final userId = u['id'] as String;
    final isActive = (u['is_active'] ?? true) as bool;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isActive ? 'Заблокувати користувача?' : 'Розблокувати користувача?'),
          content: Text(
            isActive
                ? 'Користувач не зможе входити в систему, поки його не буде розблоковано.'
                : 'Користувач знову зможе користуватися застосунком.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Скасувати'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isActive ? Colors.red : Colors.green,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(isActive ? 'Заблокувати' : 'Розблокувати'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      final res = await ApiService.updateUser(userId, isActive: !isActive);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Статус активності змінено')),
      );
      await _loadUsers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Помилка: $e')),
      );
    }
  }

  void _openUserDetails(Map<String, dynamic> u) {
    final email = u['email'] ?? '';
    final name = u['display_name'] ?? '';
    final role = u['role'] ?? 'client';
    final isActive = u['is_active'] ?? true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    child: Text(
                      (name.isNotEmpty ? name[0] : email[0]).toUpperCase(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isEmpty ? '(без імені)' : name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          email,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  _buildRoleChip(role, isActive),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Дії адміністратора',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context); // закриваємо bottom sheet
                        _changeRoleDialog(u);
                      },
                      icon: const Icon(Icons.manage_accounts_outlined),
                      label: const Text('Змінити роль'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _toggleBlockUser(u);
                      },
                      icon: Icon(
                        isActive ? Icons.block : Icons.lock_open,
                      ),
                      label: Text(isActive ? 'Заблокувати' : 'Розблокувати'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Адмін-панель'),
        actions: [
          IconButton(
            tooltip: 'Вийти',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
          IconButton(
            tooltip: 'Змінити тему',
            icon: Icon(
              themeNotifier.isDark
                  ? Icons.wb_sunny_outlined
                  : Icons.nightlight_round,
            ),
            onPressed: () => themeNotifier.toggleTheme(),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadUsers,
        child: ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, i) {
            final u = users[i] as Map<String, dynamic>;
            final email = u['email'] ?? '';
            final name = u['display_name'] ?? '';
            final role = u['role'] ?? 'client';
            final isActive = u['is_active'] ?? true;

            return Card(
              margin:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                onTap: () => _openUserDetails(u),
                leading: CircleAvatar(
                  child: Text(
                    (name.isNotEmpty ? name[0] : email[0]).toUpperCase(),
                  ),
                ),
                title: Text(
                  name.isEmpty ? email : name,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(email),
                trailing: _buildRoleChip(role, isActive),
              ),
            );
          },
        ),
      ),
    );
  }
}
