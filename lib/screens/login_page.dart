import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

import 'pin_code_page.dart'; // ✅ Импортируем экран ПИН-кода
import 'register_page.dart';
import 'forgot_password_page.dart';
import '/services/api_client.dart';
import '/services/push_device_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();

  // Маска телефона: +7 (777) 123-45-67
  final _phoneMask = MaskTextInputFormatter(
    mask: '+7 (###) ###-##-##',
    filter: {'#': RegExp(r'[0-9]')},
  );

  final _passwordController = TextEditingController();

  bool _isPasswordHidden = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  /// Нормализуем номер для API/БД: "+7 (701) 123-45-67" -> "+77011234567"
  String _normalizePhone() {
    final digits = _phoneMask.getUnmaskedText(); // только цифры
    if (digits.length != 10) {
      throw const FormatException('Номер введён не полностью');
    }
    return '+7$digits';
  }

  String? _validatePhone(String? _) {
    if (!_phoneMask.isFill()) {
      return 'Номер введён не полностью';
    }
    try {
      _normalizePhone();
    } on FormatException catch (e) {
      return e.message;
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Введите пароль';
    }
    if (value.length < 6) {
      return 'Минимум 6 символов';
    }
    return null;
  }

  Future<void> _onLoginPressed() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final normalizedPhone = _normalizePhone();

      // 1. Выполняем вход
      final auth = await ApiClient.login(
        phone: normalizedPhone,
        password: _passwordController.text,
      );

      // 2. Регистрируем устройство для Push-уведомлений
      try {
        await PushDeviceService().registerDevice();
      } catch (e) {
        debugPrint('Push register error: $e');
        // Не блокируем вход, если пуши не зарегистрировались
      }

      if (!mounted) return;

      // 3. ✅ Переходим на экран СОЗДАНИЯ ПИН-кода
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PinCodePage(
            mode: PinMode.create, // Режим создания
            userId: auth.userId,
            phone: normalizedPhone,
            fullName: auth.fullName,
          ),
        ),
      );
      
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } on FormatException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.orange),
      );
    } catch (e) {
      debugPrint('LOGIN ERROR: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка входа: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: size.width * 0.18,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Вход в систему',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Введите номер телефона и пароль,\nчтобы продолжить',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 32),

                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Телефон с маской
                        TextFormField(
                          keyboardType: TextInputType.phone,
                          inputFormatters: [_phoneMask],
                          decoration: const InputDecoration(
                            labelText: 'Номер телефона',
                            hintText: '+7 (777) 123-45-67',
                            prefixIcon: Icon(Icons.phone),
                          ),
                          validator: _validatePhone,
                        ),
                        const SizedBox(height: 16),

                        // Пароль
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _isPasswordHidden,
                          decoration: InputDecoration(
                            labelText: 'Пароль',
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordHidden
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isPasswordHidden = !_isPasswordHidden;
                                });
                              },
                            ),
                          ),
                          validator: _validatePassword,
                        ),

                        const SizedBox(height: 12),

                        // Забыли пароль?
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ForgotPasswordPage(),
                                ),
                              );
                            },
                            child: const Text('Забыли пароль?'),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Кнопка входа
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton(
                            onPressed: _isLoading ? null : _onLoginPressed,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Войти',
                                    style: TextStyle(fontSize: 16),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Регистрация
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Нет аккаунта?'),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const RegisterPage(),
                                  ),
                                );
                              },
                              child: const Text('Зарегистрироваться'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}