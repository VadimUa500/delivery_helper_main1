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
        SnackBar(content: Text('Помилка завантаження профілю: $e')),
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
        const SnackBar(content: Text('Профіль оновлено')),
      );
      await _loadProfile();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Помилка оновлення: $e')),
      );
    }
  }

  Future<void> _changePassword() async {
    if (oldPassController.text.isEmpty || newPassController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Введіть старий пароль і новий (мінімум 6 символів)')),
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
        SnackBar(content: Text(res['message']?.toString() ?? 'Пароль змінено')),
      );
      oldPassController.clear();
      newPassController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Помилка зміни пароля: $e')),
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

  @override
  Widget build(BuildContext context) {
    final email = profile?['email']?.toString() ?? '';
    final role = profile?['role']?.toString() ?? '';
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
      appBar: AppBar(
        title: const Text('Профіль користувача'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Вийти',
            onPressed: _logout,
          )
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      child: Text(
                        initials.isEmpty ? '?' : initials,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      displayNameController.text.isEmpty
                          ? 'Без імені'
                          : displayNameController.text,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Chip(
                      label: Text(
                        role == 'courier'
                            ? 'Кур’єр'
                            : role == 'admin'
                            ? 'Адміністратор'
                            : 'Клієнт',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Особисті дані',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: displayNameController,
                      decoration: const InputDecoration(
                        labelText: "Ім'я / нікнейм",
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: avatarUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Посилання на аватар',
                        prefixIcon: Icon(Icons.image_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saveProfile,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Зберегти зміни'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Зміна пароля',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: oldPassController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Старий пароль',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: newPassController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Новий пароль',
                        prefixIcon: Icon(Icons.lock_reset),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _changePassword,
                        icon: const Icon(Icons.check),
                        label: const Text('Оновити пароль'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
