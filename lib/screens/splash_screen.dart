import 'package:flutter/material.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      // Тло автоматично підлаштовується під обрану в системі тему
      backgroundColor: isDark ? const Color(0xFF13151A) : const Color(0xFFF8F9FD),
      body: SafeArea(
        child: Stack(
          children: [
            // Центрований блок брендингу
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Кругла підкладка логотипа з м'яким світінням (glow)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(alpha: 0.04),
                          blurRadius: 24,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 96,
                      height: 96,
                      errorBuilder: (context, error, stackTrace) {
                        // Захист від збоїв: якщо картинку не знайдено, показуємо системну іконку
                        return Icon(
                          Icons.local_shipping_rounded,
                          size: 64,
                          color: theme.colorScheme.primary,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Назва додатка
                  Text(
                    'Delivery Helper',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: theme.textTheme.titleLarge?.color,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Підзаголовок
                  Text(
                    'Система автоматизації доставки',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.hintColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Нижній блок: міні-індикатор завантаження та версія
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  // Мінімалістичний сучасний лінійний лоадер
                  SizedBox(
                    width: 120,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        minHeight: 3.5,
                        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Копірайт та версія
                  Text(
                    'Delivery Helper v1.0.0',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.hintColor.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '© 2026 Усі права захищено',
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.hintColor.withValues(alpha: 0.4),
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