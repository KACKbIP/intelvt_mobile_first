import 'package:flutter/material.dart';
import '../services/api_client.dart';
import 'code_confirm_page.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String _normalizePhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');

    if (digits.length == 11 && digits.startsWith('7')) {
      // 7XXXXXXXXXX → +7XXXXXXXXXX
      return '+$digits';
    }
    if (digits.length == 11 && digits.startsWith('8')) {
      // 8XXXXXXXXXX → +7XXXXXXXXXX
      return '+7${digits.substring(1)}';
    }
    if (digits.length == 10) {
      // 701XXXXXXX → +7701XXXXXXX
      return '+7$digits';
    }

    throw AuthException('Некорректный формат номера телефона');
  }

  Future<void> _onSendCodePressed() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final normalizedPhone = _normalizePhone(_phoneController.text.trim());

      // Шлём код для восстановления пароля
      await ApiClient.sendPasswordResetCode(phone: normalizedPhone);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Код отправлен по SMS'),
        ),
      );

      // Переходим на страницу ввода кода в режиме восстановления
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CodeConfirmPage(
            phone: normalizedPhone,
            password: '',              // пароль пока не нужен
            isForPasswordReset: true,  // 👈 важный флаг
          ),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ошибка при отправке кода. Попробуйте позже.'),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Восстановление пароля'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Введите номер телефона, привязанный к аккаунту. '
                'Мы отправим SMS с кодом для восстановления пароля.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Телефон',
                  hintText: '+7 777 123 45 67',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Введите номер телефона';
                  }
                  final digits = value.replaceAll(RegExp(r'\D'), '');
                  if (digits.length < 10) {
                    return 'Слишком короткий номер';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _onSendCodePressed,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Отправить код'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
