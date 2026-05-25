import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'screens/client_orders_screen.dart';
import 'screens/courier_orders_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/register_screen.dart';
import 'theme/theme_notifier.dart';
import 'screens/splash_screen.dart';


void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeNotifier(),
      child: const DeliveryHelperApp(),
    ),
  );
}

class DeliveryHelperApp extends StatelessWidget {
  const DeliveryHelperApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Delivery Helper',
      themeMode: themeNotifier.isDark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.tealAccent,
        brightness: Brightness.dark,
      ),
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/client': (context) => const ClientOrdersScreen(),
        '/courier': (context) => const CourierOrdersScreen(),
        '/admin': (context) => const AdminDashboardScreen(),
        '/profile': (context) => const ProfileScreen(),
      },


    );
  }
}
