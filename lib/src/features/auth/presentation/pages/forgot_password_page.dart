import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart'; // ✅ Импорт маски
import '../../../../core/services/api_client.dart';
import 'code_confirm_page.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();

  // ✅ Добавляем маску, точно такую же, как на LoginPage
  final _phoneMask = MaskTextInputFormatter(
    mask: '+7 (###) ###-##-##',
    filter: {'#': RegExp(r'[0-9]')},
  );

  bool _isLoading = false;

  /// Нормализуем номер для API: "+7 (701) 123-45-67" -> "+77011234567"
  String _normalizePhone() {
    final digits = _phoneMask
        .getUnmaskedText(); // Получаем только цифры (10 штук)
    if (digits.length != 10) {
      throw const FormatException('Номер введён не полностью');
    }
    return '+7$digits';
  }

  Future<void> _onSendCodePressed() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final normalizedPhone = _normalizePhone();

      // Шлём код для восстановления пароля
      await ApiClient.sendPasswordResetCode(phone: normalizedPhone);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Код отправлен по SMS')));

      // Переходим на страницу ввода кода
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CodeConfirmPage(
            phone: normalizedPhone,
            password: '', // пароль здесь не нужен
            isForPasswordReset: true, // флаг восстановления
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
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ошибка при отправке кода. Попробуйте позже.'),
          backgroundColor: Colors.red,
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
        backgroundColor: Colors.white,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(Icons.arrow_back_ios_new_outlined),
        ),
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
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),

              // ✅ Поле с маской
              TextFormField(
                keyboardType: TextInputType.phone,
                inputFormatters: [_phoneMask], // Подключаем маску
                decoration: const InputDecoration(
                  labelText: 'Телефон',
                  hintText: '+7 (777) 123-45-67',
                  hintStyle: TextStyle(color: Colors.grey),
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  // Проверяем, заполнена ли маска полностью
                  if (!_phoneMask.isFill()) {
                    return 'Введите полный номер телефона';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _isLoading ? null : _onSendCodePressed,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Отправить код',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
