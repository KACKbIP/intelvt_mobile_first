import 'package:flutter/material.dart';
import '/services/api_client.dart';
import 'parent_dashboard_page.dart';

class CodeConfirmPage extends StatefulWidget {
  final String phone;
  final String password; 
  final bool isForPasswordReset;

  const CodeConfirmPage({
    super.key,
    required this.phone,
    required this.password,  
    required this.isForPasswordReset,
  });

  @override
  State<CodeConfirmPage> createState() => _CodeConfirmPageState();
}

class _CodeConfirmPageState extends State<CodeConfirmPage> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  String? _validateCode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Введите код из SMS';
    }
    if (value.trim().length < 4) {
      return 'Код слишком короткий';
    }
    return null;
  }

  Future<void> _onConfirmPressed() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
final code = _codeController.text.trim();

if (widget.isForPasswordReset) {
  // здесь потом сделаешь API для сброса пароля
  await Future.delayed(const Duration(milliseconds: 300));

  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Код верный. Здесь будет смена пароля.'),
    ),
  );
} else {
  // подтверждение регистрации + автологин
  await ApiClient.confirmRegistration(
    phone: widget.phone,
    password: widget.password,   // 👈 важное место
    code: code,
  );

  if (!mounted) return;

  // успешная регистрация → дашборд
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => const ParentDashboardPage()),
    (route) => false,
  );
}
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ошибка при проверке кода. Попробуйте позже.'),
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
    final title = widget.isForPasswordReset
        ? 'Подтверждение сброса пароля'
        : 'Подтверждение регистрации';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Подтверждение кода'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Мы отправили код на номер:\n${widget.phone}',
                  style: const TextStyle(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                TextFormField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Код из SMS',
                    hintText: '1234',
                    prefixIcon: Icon(Icons.sms),
                  ),
                  validator: _validateCode,
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _onConfirmPressed,
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Text(
                            'Подтвердить',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ),

                const SizedBox(height: 16),
                TextButton(
  onPressed: () async {
    if (widget.isForPasswordReset) {
      // TODO: тут потом сделаешь отдельный эндпоинт для восстановления пароля
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Повторная отправка кода для сброса пароля пока не реализована'),
        ),
      );
      return;
    }

    try {
      await ApiClient.registerStart(
        phone: widget.phone,
        password: widget.password,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Код отправлен повторно'),
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
    }
  },
  child: const Text('Отправить код ещё раз'),
),

              ],
            ),
          ),
        ),
      ),
    );
  }
}
