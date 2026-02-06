import 'package:flutter/material.dart';
import '../../../../core/services/api_client.dart';
import 'login_page.dart';
import '../../../home/presentation/pages/main_navigation_page.dart';

class AuthCheckPage extends StatefulWidget {
  const AuthCheckPage({super.key});

  @override
  State<AuthCheckPage> createState() => _AuthCheckPageState();
}

class _AuthCheckPageState extends State<AuthCheckPage> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Ждем секунду для красоты (сплэш-скрин), можно убрать
    await Future.delayed(const Duration(milliseconds: 500));

    // Проверяем токен
    final token = await ApiClient.getAccessToken();
    final userId = await ApiClient.getUserId();
    final phone = await ApiClient.getPhone();

    if (!mounted) return;

    if (token != null && token.isNotEmpty && userId != null && phone != null) {
      // ✅ Токен есть — идем на Главную
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MainNavigationPage(userId: userId, phone: phone),
        ),
      );
    } else {
      // ❌ Токена нет — идем на Логин
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}