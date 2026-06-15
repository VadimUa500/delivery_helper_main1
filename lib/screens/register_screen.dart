import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_storage.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();
  final displayNameController = TextEditingController();

  String role = 'client'; // client або courier
  bool loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? error;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      loading = true;
      error = null;
    });

    try {
      await ApiService.register(
        email: emailController.text.trim(),
        password: passwordController.text,
        displayName: displayNameController.text.trim().isEmpty
            ? emailController.text.trim()
            : displayNameController.text.trim(),
        role: role,
      );

      // авто-вхід після успішної реєстрації
      final loginRes = await ApiService.login(
        emailController.text.trim(),
        passwordController.text,
      );

      if (!loginRes.containsKey('access_token')) {
        throw Exception(
          loginRes['message'] ?? 'Не вдалося увійти після реєстрації',
        );
      }

      final token = loginRes['access_token'];
      final loggedRole = loginRes['role'] ?? role;

      await AuthStorage.saveToken(token);
      await AuthStorage.saveRole(loggedRole);

      if (!mounted) return;

      if (loggedRole == 'courier') {
        Navigator.pushReplacementNamed(context, '/courier');
      } else if (loggedRole == 'admin') {
        Navigator.pushReplacementNamed(context, '/admin');
      } else {
        Navigator.pushReplacementNamed(context, '/client');
      }
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  // Спільний фірмовий стиль полів введення
  InputDecoration _inputDecoration(BuildContext context, String label, IconData icon, {Widget? suffix}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: theme.hintColor, fontSize: 13.5),
      prefixIcon: Icon(icon, color: theme.colorScheme.primary, size: 20),
      suffixIcon: suffix,
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
    );
  }

  // Кастомна преміальна картка вибору ролі у системі
  Widget _buildRoleSelector(String roleValue, String title, String subtitle, IconData icon) {
    final theme = Theme.of(context);
    final isSelected = role == roleValue;
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        setState(() {
          role = roleValue;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.15 : 0.05)
              : (isDark ? const Color(0xFF1E222D) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03)),
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
                color: isSelected ? theme.colorScheme.primary : theme.hintColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isSelected ? theme.colorScheme.primary : theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: theme.hintColor,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary, size: 22),
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
      backgroundColor: isDark ? const Color(0xFF13151A) : const Color(0xFFF8F9FD),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: theme.textTheme.titleLarge?.color,
        title: const Text(
          'Реєстрація',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Секція Логотипа із захистом від відсутності картинки
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 64,
                        height: 64,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.local_shipping_rounded,
                            size: 40,
                            color: theme.colorScheme.primary,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      'Створення акаунта',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Заповніть дані користувача та оберіть роль у системі',
                      style: TextStyle(fontSize: 13.5, color: theme.hintColor),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),

                    // Поле введення Email
                    TextFormField(
                      controller: emailController,
                      decoration: _inputDecoration(context, 'Ваш Email', Icons.email_rounded),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        final value = (v ?? '').trim();
                        if (value.isEmpty) return 'Введіть email';
                        if (!value.contains('@')) return 'Некоректний email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Поле введення імені
                    TextFormField(
                      controller: displayNameController,
                      decoration: _inputDecoration(context, "Ім’я користувача (нікнейм)", Icons.person_rounded),
                    ),
                    const SizedBox(height: 12),

                    // Поле введення пароля
                    TextFormField(
                      controller: passwordController,
                      decoration: _inputDecoration(
                        context,
                        'Пароль',
                        Icons.lock_rounded,
                        suffix: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: theme.hintColor.withValues(alpha: 0.7),
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      obscureText: _obscurePassword,
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Введіть пароль';
                        }
                        if (v.length < 6) {
                          return 'Мінімум 6 символів';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Поле введення підтвердження пароля
                    TextFormField(
                      controller: confirmController,
                      decoration: _inputDecoration(
                        context,
                        'Підтвердження пароля',
                        Icons.lock_rounded,
                        suffix: IconButton(
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: theme.hintColor.withValues(alpha: 0.7),
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureConfirm = !_obscureConfirm;
                            });
                          },
                        ),
                      ),
                      obscureText: _obscureConfirm,
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Повторіть пароль';
                        }
                        if (v != passwordController.text) {
                          return 'Паролі не збігаються';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Секція вибору ролі
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 12),
                        child: Text(
                          'Виберіть роль користувача',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                        ),
                      ),
                    ),
                    _buildRoleSelector(
                      'client',
                      'Клієнт (створює замовлення)',
                      'Ви створюєте заявки на доставку та контролюєте їх виконання',
                      Icons.person_pin_rounded,
                    ),
                    _buildRoleSelector(
                      'courier',
                      'Кур’єр (виконує доставки)',
                      'Ви переглядаєте карту та доставляєте товари іншим людям',
                      Icons.delivery_dining_rounded,
                    ),

                    if (error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Colors.red, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                error!,
                                style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 28),

                    // Кнопка Зареєструватися
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: loading ? null : _register,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: loading
                            ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: theme.colorScheme.onPrimary,
                          ),
                        )
                            : const Text(
                          'Зареєструватися',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}