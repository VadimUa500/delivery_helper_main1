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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Реєстрація')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ЛОГОТИП
                      Image.asset(
                        'assets/images/logo.png',
                        width: 110,
                      ),
                      const SizedBox(height: 12),

                      const Text(
                        'Створення акаунта',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Заповніть дані користувача та оберіть роль у системі',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),

                      TextFormField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          final value = (v ?? '').trim();
                          if (value.isEmpty) return 'Введіть email';
                          if (!value.contains('@')) return 'Некоректний email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: displayNameController,
                        decoration: const InputDecoration(
                          labelText: "Ім’я",
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: passwordController,
                        decoration: InputDecoration(
                          labelText: 'Пароль',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
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
                      TextFormField(
                        controller: confirmController,
                        decoration: InputDecoration(
                          labelText: 'Підтвердження пароля',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_off
                                  : Icons.visibility,
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
                      const SizedBox(height: 20),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Роль користувача',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      RadioListTile<String>(
                        title: const Text('Клієнт (створює замовлення)'),
                        value: 'client',
                        groupValue: role,
                        onChanged: (v) =>
                            setState(() => role = v ?? 'client'),
                      ),
                      RadioListTile<String>(
                        title:
                        const Text('Кур’єр (приймає та виконує доставки)'),
                        value: 'courier',
                        groupValue: role,
                        onChanged: (v) =>
                            setState(() => role = v ?? 'client'),
                      ),
                      const SizedBox(height: 12),
                      if (error != null)
                        Text(
                          error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: loading ? null : _register,
                          style: ElevatedButton.styleFrom(
                            padding:
                            const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: loading
                              ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                              : const Text(
                            'Зареєструватися',
                            style: TextStyle(fontSize: 16),
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
      ),
    );
  }
}
