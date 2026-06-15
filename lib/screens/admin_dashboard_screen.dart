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
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text('Помилка завантаження користувачів: $e'),
        ),
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

  // Розумне кольорове кодування ролей та блокування
  Widget _buildRoleBadge(String role, bool isActive, ThemeData theme) {
    Color badgeColor;
    Color textColor;
    String roleText;

    if (!isActive) {
      badgeColor = const Color(0xFFFF3B30).withValues(alpha: 0.1);
      textColor = const Color(0xFFFF3B30);
      roleText = 'Заблокований';
    } else if (role == 'admin') {
      badgeColor = const Color(0xFFFF2D55).withValues(alpha: 0.1);
      textColor = const Color(0xFFFF2D55);
      roleText = 'Адмін';
    } else if (role == 'courier') {
      badgeColor = const Color(0xFF007AFF).withValues(alpha: 0.1);
      textColor = const Color(0xFF007AFF);
      roleText = 'Кур’єр';
    } else {
      badgeColor = theme.colorScheme.primary.withValues(alpha: 0.1);
      textColor = theme.colorScheme.primary;
      roleText = 'Клієнт';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: textColor.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isActive) ...[
            const Icon(Icons.block_flipped, color: Color(0xFFFF3B30), size: 12),
            const SizedBox(width: 4),
          ],
          Text(
            roleText,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  // Кольоровий аватар, що адаптується до ролі
  Widget _buildAvatar(String name, String email, String role, bool isActive, ThemeData theme) {
    final initial = (name.isNotEmpty ? name[0] : email[0]).toUpperCase();

    Color avatarColor;
    if (!isActive) {
      avatarColor = const Color(0xFFFF3B30);
    } else if (role == 'admin') {
      avatarColor = const Color(0xFFFF2D55);
    } else if (role == 'courier') {
      avatarColor = const Color(0xFF007AFF);
    } else {
      avatarColor = theme.colorScheme.primary;
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: avatarColor.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(
          color: avatarColor.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: avatarColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Future<void> _changeRoleDialog(Map<String, dynamic> u) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final userId = u['id'] as String;
    String currentRole = (u['role'] ?? 'client') as String;
    String selectedRole = currentRole;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: isDark ? const Color(0xFF1E222D) : Colors.white,
          title: const Text(
            'Змінити роль користувача',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: DropdownButtonFormField<String>(
            value: selectedRole,
            dropdownColor: isDark ? const Color(0xFF1E222D) : Colors.white,
            decoration: InputDecoration(
              filled: true,
              fillColor: isDark ? const Color(0xFF252936) : const Color(0xFFF3F5F8),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
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
              child: Text('Скасувати', style: TextStyle(color: theme.hintColor)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                Navigator.pop(context);
                try {
                  final res = await ApiService.updateUser(userId, role: selectedRole);
                  if (!mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      content: Text(res['message'] ?? 'Роль оновлено'),
                    ),
                  );
                  await _loadUsers();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      content: Text('Помилка: $e'),
                    ),
                  );
                }
              },
              child: const Text('Зберегти', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _toggleBlockUser(Map<String, dynamic> u) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final userId = u['id'] as String;
    final isActive = (u['is_active'] ?? true) as bool;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: isDark ? const Color(0xFF1E222D) : Colors.white,
          title: Text(
            isActive ? 'Заблокувати користувача?' : 'Розблокувати користувача?',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: Text(
            isActive
                ? 'Користувач втратить доступ до системи, поки ви його не розблокуєте.'
                : 'Користувач знову зможе користуватися застосунком Delivery Helper.',
            style: TextStyle(fontSize: 14, color: theme.hintColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Скасувати', style: TextStyle(color: theme.hintColor)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isActive ? const Color(0xFFFF3B30) : const Color(0xFF34C759),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                isActive ? 'Заблокувати' : 'Розблокувати',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
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
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text(res['message'] ?? 'Статус активності змінено'),
        ),
      );
      await _loadUsers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text('Помилка: $e'),
        ),
      );
    }
  }

  void _openUserDetails(Map<String, dynamic> u) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final email = u['email'] ?? '';
    final name = u['display_name'] ?? '';
    final role = u['role'] ?? 'client';
    final isActive = u['is_active'] ?? true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E222D) : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 14,
            bottom: 16 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Індикатор Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: theme.hintColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Row(
                children: [
                  _buildAvatar(name, email, role, isActive, theme),
                  const SizedBox(width: 14),
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
                        const SizedBox(height: 2),
                        Text(
                          email,
                          style: TextStyle(fontSize: 12, color: theme.hintColor),
                        ),
                      ],
                    ),
                  ),
                  _buildRoleBadge(role, isActive, theme),
                ],
              ),
              const SizedBox(height: 24),
              Divider(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05), height: 1),
              const SizedBox(height: 20),
              const Text(
                'Керування обліковим записом',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _changeRoleDialog(u);
                      },
                      icon: const Icon(Icons.manage_accounts_rounded, size: 18),
                      label: const Text('Змінити роль', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isActive
                            ? const Color(0xFFFF3B30).withValues(alpha: 0.1)
                            : const Color(0xFF34C759).withValues(alpha: 0.1),
                        foregroundColor: isActive ? const Color(0xFFFF3B30) : const Color(0xFF34C759),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isActive
                                ? const Color(0xFFFF3B30).withValues(alpha: 0.2)
                                : const Color(0xFF34C759).withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _toggleBlockUser(u);
                      },
                      icon: Icon(
                        isActive ? Icons.block_flipped : Icons.lock_open_rounded,
                        size: 18,
                      ),
                      label: Text(
                        isActive ? 'Заблокувати' : 'Розблокувати',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
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

  // Скелетон завантаження користувачів
  Widget _buildSkeletonLoader() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
          height: 72,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.05),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const CircleAvatar(radius: 20, backgroundColor: Colors.black12),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 120, height: 12, color: Colors.black12),
                      const SizedBox(height: 6),
                      Container(width: 80, height: 10, color: Colors.black12),
                    ],
                  ),
                ),
                Container(width: 60, height: 22, color: Colors.black12),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF13151A) : const Color(0xFFF8F9FD),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: theme.textTheme.titleLarge?.color,
        title: const Text(
          'Адмін-панель',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
        actions: [
          IconButton(
            tooltip: 'Змінити тему',
            icon: Icon(
              themeNotifier.isDark
                  ? Icons.wb_sunny_rounded
                  : Icons.nightlight_round_rounded,
              size: 24,
            ),
            onPressed: () => themeNotifier.toggleTheme(),
          ),
          IconButton(
            tooltip: 'Вийти',
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 24),
            onPressed: _logout,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: loading
          ? _buildSkeletonLoader()
          : RefreshIndicator(
        onRefresh: _loadUsers,
        color: theme.colorScheme.primary,
        child: ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: users.length,
          itemBuilder: (context, i) {
            final u = users[i] as Map<String, dynamic>;
            final email = u['email'] ?? '';
            final name = u['display_name'] ?? '';
            final role = u['role'] ?? 'client';
            final isActive = u['is_active'] ?? true;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E222D) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                  width: 1,
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                onTap: () => _openUserDetails(u),
                leading: _buildAvatar(name, email, role, isActive, theme),
                title: Text(
                  name.isEmpty ? email : name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    email,
                    style: TextStyle(fontSize: 12, color: theme.hintColor),
                  ),
                ),
                trailing: _buildRoleBadge(role, isActive, theme),
              ),
            );
          },
        ),
      ),
    );
  }
}