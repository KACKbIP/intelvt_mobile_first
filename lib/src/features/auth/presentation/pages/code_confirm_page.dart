import 'package:flutter/material.dart';
import '../../../../core/api/client/api_client.dart';
import '../../../home/presentation/pages/parent_dashboard_page.dart';
import 'login_page.dart';
import '../../../../core/services/push_device_service.dart';

class CodeConfirmPage extends StatefulWidget {
  final String phone;
  final String password; // Используется только при регистрации
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

  // ================= ЛОГИКА ДИАЛОГА СМЕНЫ ПАРОЛЯ =================
  Future<void> _showChangePasswordDialog(String validCode) async {
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    final dialogFormKey = GlobalKey<FormState>();
    
    bool isObscure = true;
    bool isDialogLoading = false;

    await showDialog(
      context: context,
      barrierDismissible: false, // Нельзя закрыть, нажав мимо
      builder: (dialogContext) {
        // StatefulBuilder нужен, чтобы обновлять состояние ВНУТРИ диалога (глазик, загрузка)
        return StatefulBuilder(
          builder: (context, setDialogState) {
            
            Future<void> submitNewPassword() async {
              if (!dialogFormKey.currentState!.validate()) return;
              FocusScope.of(context).unfocus();


              setDialogState(() => isDialogLoading = true);

              try {
                // Вызываем API смены пароля
                await ApiClient.resetPassword(
                  phone: widget.phone,
                  code: validCode,
                  newPassword: newPassController.text.trim(),
                );

                if (!mounted) return;
                Navigator.pop(dialogContext); // Закрываем диалог

                // Показываем успех и идем на логин
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Пароль успешно изменён!')),
                );

                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
                );

              } catch (e) {
                // Показываем ошибку поверх диалога или тостом
                 ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.toString())),
                );
              } finally {
                // Если диалог еще жив, снимаем загрузку
                setDialogState(() => isDialogLoading = false);
              }
            }

            return AlertDialog(
              title: const Text('Новый пароль'),
              content: Form(
                key: dialogFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Чтобы окно не растягивалось
                  children: [
                    const Text('Код подтверждён. Придумайте новый пароль.'),
                    const SizedBox(height: 16),
                    
                    // Поле 1: Новый пароль
                    TextFormField(
                      controller: newPassController,
                      obscureText: isObscure,
                      decoration: InputDecoration(
                        labelText: 'Новый пароль',
                        suffixIcon: IconButton(
                          icon: Icon(isObscure ? Icons.visibility_off : Icons.visibility),
                          onPressed: () {
                            setDialogState(() => isObscure = !isObscure);
                          },
                        ),
                      ),
                      validator: (v) => (v == null || v.length < 6) 
                          ? 'Минимум 6 символов' 
                          : null,
                    ),
                    const SizedBox(height: 12),
                    
                    // Поле 2: Повтор пароля
                    TextFormField(
                      controller: confirmPassController,
                      obscureText: isObscure,
                      decoration: const InputDecoration(
                        labelText: 'Повторите пароль',
                      ),
                      validator: (v) {
                        if (v != newPassController.text) return 'Пароли не совпадают';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isDialogLoading ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: isDialogLoading ? null : submitNewPassword,
                  child: isDialogLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ================= ОСНОВНАЯ КНОПКА "ПОДТВЕРДИТЬ" =================
  Future<void> _onConfirmPressed() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);
    final code = _codeController.text.trim();

    try {
      if (widget.isForPasswordReset) {
        // 1. Сценарий восстановления пароля
        // Тут можно сделать предварительную проверку кода на сервере, если есть такой метод.
        // Если нет отдельного метода "VerifyOnly", просто считаем, что код введен
        // и передаем его в диалог, а реальная проверка будет при смене пароля.
        
        await Future.delayed(const Duration(milliseconds: 500)); // Имитация проверки

        if (!mounted) return;
        
        // Открываем диалог смены пароля
        await _showChangePasswordDialog(code);

      } else {
        // 2. Сценарий регистрации
        final auth = await ApiClient.confirmRegistration(
          phone: widget.phone,
          password: widget.password,
          code: code,
        );

        await PushDeviceService().registerDevice();

        if (!mounted) return;

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
        const SnackBar(content: Text('Ошибка при проверке кода.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String? _validateCode(String? value) {
    if (value == null || value.trim().isEmpty) return 'Введите код';
    if (value.trim().length < 4) return 'Код слишком короткий';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isForPasswordReset
        ? 'Сброс пароля'
        : 'Регистрация';

    return Scaffold(
      appBar: AppBar(title: const Text('Подтверждение')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  'Код отправлен на ${widget.phone}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 30),

                TextFormField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Код из SMS',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.sms),
                  ),
                  validator: _validateCode,
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _onConfirmPressed,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Подтвердить'),
                  ),
                ),
                
                // Кнопка повторной отправки (оставляем как было)
                 TextButton(
                  onPressed: () async {
                    try {
                      await ApiClient.registerStart(phone: widget.phone); // Используем тот же метод для отправки SMS
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Код отправлен повторно')),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
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