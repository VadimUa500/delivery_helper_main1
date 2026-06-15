import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../services/auth_storage.dart';
import '../theme/theme_notifier.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;
  bool _obscurePassword = true;
  String? error;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final res = await ApiService.login(
        emailController.text.trim(),
        passwordController.text,
      );

      if (res.containsKey('access_token')) {
        final token = res['access_token'];
        final role = res['role'] ?? 'client';

        await AuthStorage.saveToken(token);
        await AuthStorage.saveRole(role);

        if (!mounted) return;

        if (role == 'courier') {
          Navigator.pushReplacementNamed(context, '/courier');
        } else if (role == 'admin') {
          Navigator.pushReplacementNamed(context, '/admin');
        } else {
          Navigator.pushReplacementNamed(context, '/client');
        }
      } else {
        setState(() => error = res['message']?.toString() ?? 'Помилка входу');
      }
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  void _openRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  // Наш кастомний фірмовий стиль полів введення
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      // Тло змінюється відповідно до обраної теми додатка
      backgroundColor: isDark ? const Color(0xFF13151A) : const Color(0xFFF8F9FD),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Світла/темна іконка у шапці для швидкої зміни теми на екрані авторизації
                    Align(
                      alignment: Alignment.topRight,
                      child: Consumer<ThemeNotifier>(
                        builder: (context, themeNotifier, _) => IconButton(
                          icon: Icon(
                            themeNotifier.isDark
                                ? Icons.wb_sunny_rounded
                                : Icons.nightlight_round_rounded,
                            color: theme.hintColor.withValues(alpha: 0.6),
                          ),
                          onPressed: () => themeNotifier.toggleTheme(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Секція Логотипа із захистом від відсутності картинки
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 72,
                        height: 72,
                        errorBuilder: (context, error, stackTrace) {
                          // Повертає гарну системну іконку, якщо файл не знайдено
                          return Icon(
                            Icons.local_shipping_rounded,
                            size: 48,
                            color: theme.colorScheme.primary,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'Delivery Helper',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: theme.textTheme.titleLarge?.color,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Вхід до системи керування доставками',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.hintColor,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // Поле введення Email
                    TextFormField(
                      controller: emailController,
                      decoration: _inputDecoration(context, 'Ваш Email', Icons.email_rounded),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        final value = (v ?? '').trim();
                        if (value.isEmpty) {
                          return 'Введіть email';
                        }
                        if (!value.contains('@')) {
                          return 'Некоректний email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

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

                    if (error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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

                    const SizedBox(height: 32),

                    // Кнопка Увійти
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: loading ? null : _login,
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
                          'Увійти',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Кнопка Створення акаунту
                    TextButton(
                      onPressed: loading ? null : _openRegister,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      ),
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(fontSize: 13.5, color: theme.hintColor),
                          children: [
                            const TextSpan(text: 'Немає акаунту? '),
                            TextSpan(
                              text: 'Зареєструватися',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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