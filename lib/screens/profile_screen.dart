import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_storage.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool loading = true;
  Map<String, dynamic>? profile;

  final displayNameController = TextEditingController();
  final avatarUrlController = TextEditingController();
  final oldPassController = TextEditingController();
  final newPassController = TextEditingController();

  Future<void> _loadProfile() async {
    setState(() => loading = true);
    try {
      final p = await ApiService.getProfile();
      profile = p;
      displayNameController.text = p['display_name']?.toString() ?? '';
      avatarUrlController.text = p['avatar_url']?.toString() ?? '';
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text('Помилка завантаження профілю: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _saveProfile() async {
    try {
      await ApiService.updateProfile(
        displayName: displayNameController.text.trim(),
        avatarUrl: avatarUrlController.text.trim().isEmpty
            ? null
            : avatarUrlController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: const Text('Профіль оновлено'),
        ),
      );
      await _loadProfile();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text('Помилка оновлення: $e'),
        ),
      );
    }
  }

  Future<void> _changePassword() async {
    if (oldPassController.text.isEmpty || newPassController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: const Text('Введіть старий пароль і новий (мінімум 6 символів)'),
        ),
      );
      return;
    }

    try {
      final res = await ApiService.updateProfile(
        oldPassword: oldPassController.text,
        newPassword: newPassController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text(res['message']?.toString() ?? 'Пароль змінено'),
        ),
      );
      oldPassController.clear();
      newPassController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text('Помилка зміни пароля: $e'),
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

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    displayNameController.dispose();
    avatarUrlController.dispose();
    oldPassController.dispose();
    newPassController.dispose();
    super.dispose();
  }

  // Спільний преміальний стиль для полів введення
  InputDecoration _inputDecoration(BuildContext context, String label, IconData icon) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: theme.hintColor, fontSize: 13.5),
      prefixIcon: Icon(icon, color: theme.colorScheme.primary, size: 20),
      filled: true,
      fillColor: isDark ? const Color(0xFF1E222D) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
      ),
    );
  }

  // Візуалізація аватара з неоновим ефектом та можливістю підвантажувати фото
  Widget _buildAvatar(String avatarUrl, String initials, ThemeData theme) {
    final hasImage = avatarUrl.isNotEmpty && Uri.tryParse(avatarUrl)?.hasAbsolutePath == true;

    return Container(
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.2),
            width: 4,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              blurRadius: 16,
              spreadRadius: 4,
            )
          ]
      ),
      child: CircleAvatar(
        radius: 46,
        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
        backgroundImage: hasImage ? NetworkImage(avatarUrl) : null,
        child: !hasImage
            ? Text(
          initials.isEmpty ? '?' : initials,
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            color: theme.colorScheme.primary,
            letterSpacing: 0.5,
          ),
        )
            : null,
      ),
    );
  }

  // Красивий статус ролі користувача
  Widget _buildRoleBadge(String role, ThemeData theme) {
    Color badgeColor;
    Color textColor;
    String roleText;

    if (role == 'courier') {
      badgeColor = const Color(0xFF007AFF).withValues(alpha: 0.1);
      textColor = const Color(0xFF007AFF);
      roleText = 'Кур’єр';
    } else if (role == 'admin') {
      badgeColor = const Color(0xFFFF9500).withValues(alpha: 0.1);
      textColor = const Color(0xFFFF9500);
      roleText = 'Адміністратор';
    } else {
      badgeColor = theme.colorScheme.primary.withValues(alpha: 0.1);
      textColor = theme.colorScheme.primary;
      roleText = 'Клієнт';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        roleText,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final email = profile?['email']?.toString() ?? '';
    final role = profile?['role']?.toString() ?? '';
    final avatarUrl = profile?['avatar_url']?.toString() ?? '';
    final initials = (displayNameController.text.isNotEmpty
        ? displayNameController.text
        : email)
        .trim()
        .split(' ')
        .where((e) => e.isNotEmpty)
        .take(2)
        .map((e) => e[0].toUpperCase())
        .join();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF13151A) : const Color(0xFFF8F9FD),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: theme.textTheme.titleLarge?.color,
        title: const Text(
          'Профіль користувача',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            tooltip: 'Вийти',
            onPressed: _logout,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: loading
          ? Center(
        child: CircularProgressIndicator(
          color: theme.colorScheme.primary,
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 1. Головна Візитна Картка Профілю
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E222D) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                ),
              ),
              child: Column(
                children: [
                  _buildAvatar(avatarUrl, initials, theme),
                  const SizedBox(height: 16),
                  Text(
                    displayNameController.text.isEmpty
                        ? 'Без імені'
                        : displayNameController.text,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: TextStyle(color: theme.hintColor, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  _buildRoleBadge(role, theme),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Блок «Особисті дані»
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E222D) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 3,
                        height: 16,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Особисті дані',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: displayNameController,
                    decoration: _inputDecoration(context, "Ім'я або нікнейм", Icons.person_outline_rounded),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: avatarUrlController,
                    decoration: _inputDecoration(context, 'Посилання на аватар (URL)', Icons.image_outlined),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _saveProfile,
                      icon: const Icon(Icons.save_rounded, size: 18),
                      label: const Text(
                        'Зберегти зміни',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. Блок «Безпека / Зміна пароля»
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E222D) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 3,
                        height: 16,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9500),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Пароль та безпека',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: oldPassController,
                    obscureText: true,
                    decoration: _inputDecoration(context, 'Старий пароль', Icons.lock_outline_rounded),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newPassController,
                    obscureText: true,
                    decoration: _inputDecoration(context, 'Новий пароль', Icons.lock_reset_rounded),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _changePassword,
                      icon: const Icon(Icons.shield_rounded, size: 18),
                      label: const Text(
                        'Оновити пароль',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.4)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}