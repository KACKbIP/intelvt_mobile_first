import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

import '../../../../core/services/api_client.dart';
import 'code_confirm_page.dart'; // 👈 добавить импорт

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final _phoneMask = MaskTextInputFormatter(
    mask: '+7 (###) ###-##-##',
    filter: {'#': RegExp(r'[0-9]')},
  );

  final _passwordController = TextEditingController();
  final _repeatPasswordController = TextEditingController();

  bool _isPasswordHidden = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _repeatPasswordController.dispose();
    super.dispose();
  }

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

  String? _validateRepeatPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Повторите пароль';
    }
    if (value != _passwordController.text) {
      return 'Пароли не совпадают';
    }
    return null;
  }

  Future<void> _onRegisterPressed() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);

    try {
      final normalizedPhone = _normalizePhone();

      await ApiClient.registerStart(phone: normalizedPhone);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Код отправлен по SMS')));

      // Переходим на экран ввода кода
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CodeConfirmPage(
            phone: normalizedPhone,
            password: _passwordController.text, // 👈 добавили
            isForPasswordReset: false,
          ),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ошибка при регистрации. Попробуйте позже.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Регистрация'),
        backgroundColor: Colors.white,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(Icons.arrow_back_ios_new_outlined),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Создание аккаунта родителя',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Телефон
                  TextFormField(
                    keyboardType: TextInputType.phone,
                    inputFormatters: [_phoneMask],
                    decoration: const InputDecoration(
                      labelText: 'Номер телефона',
                      hintText: '+7 (777) 123-45-67',
                      hintStyle: TextStyle(color: Colors.grey),
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
                  const SizedBox(height: 16),

                  // Повтор пароля
                  TextFormField(
                    controller: _repeatPasswordController,
                    obscureText: _isPasswordHidden,
                    decoration: const InputDecoration(
                      labelText: 'Повторите пароль',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: _validateRepeatPassword,
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _isLoading ? null : _onRegisterPressed,
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text(
                              'Зарегистрироваться',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    'Номер телефона после регистрации изменить нельзя.\n'
                    'В случае ошибки обратитесь в поддержку.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withOpacity(0.6),
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
