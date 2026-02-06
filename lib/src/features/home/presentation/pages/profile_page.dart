import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // Не забудь добавить этот пакет в pubspec.yaml

import '../../../../core/api/client/api_client.dart';
import '../../../auth/presentation/pages/login_page.dart';

class ProfilePage extends StatefulWidget {
  final int userId;
  final String? phone;
  final String? fullName;

  const ProfilePage({
    super.key,
    required this.userId,
    this.phone,
    this.fullName,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  
  Future<String> getName() async {
    String name = await ApiClient.getName() ?? 'No name';
    return name;
  }
  late String _phone;
  late String _fullName;

  bool _isLogoutProcessing = false;

  @override
  void initState() {
    super.initState();
    _fullName = widget.fullName  ?? 'У вас пока нет имени';
    _phone = widget.phone ?? '+7 XXX XXX XX XX';

    ApiClient.getName().then((name) {
    if (!mounted || name == null) return;
    setState(() => _fullName = name);
  });

  }

  Future<void> _openSupport() async {
    final Uri url = Uri.parse('tg://resolve?domain=intelvt');
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Не удалось открыть Telegram');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при открытии ссылки: $e')),
      );
    }
  }

  // ==================== LOGOUT ====================
  Future<void> _logout() async {
    if (_isLogoutProcessing) return;

    setState(() => _isLogoutProcessing = true);

    try {
      await ApiClient.logout();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Ошибка при выходе')));
    } finally {
      if (mounted) setState(() => _isLogoutProcessing = false);
    }
  }

  // ==================== DELETE ACCOUNT (APPLE REQUIREMENT) ====================
  Future<void> _deleteAccount() async {
    // 1. Показываем диалог подтверждения
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удаление аккаунта'),
        content: const Text(
          'Вы уверены? Ваш аккаунт и все данные будут безвозвратно удалены. Это действие нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить навсегда'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // 2. Запускаем процесс удаления
    if (!mounted) return;
    setState(() => _isLogoutProcessing = true); // Используем индикатор загрузки

    try {
      // Внимание: Убедись, что метод deleteAccount добавлен в ApiClient!
      await ApiClient.deleteAccount();

      if (!mounted) return;

      // 3. Переход на логин после успеха
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Аккаунт успешно удален')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLogoutProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  // ==================== CHANGE NAME ====================
  Future<void> _changeName() async {
    final controller = TextEditingController(text: _fullName);
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setLocal) {
            Future<void> submit() async {
              if (!formKey.currentState!.validate()) return;

              setLocal(() => isLoading = true);

              final newName = controller.text.trim();

              try {
                await ApiClient.updateProfileName(
                  userId: widget.userId,
                  newName: newName,
                );

                if (!mounted) return;

                setState(() => _fullName = newName);
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Имя успешно обновлено')),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.toString())),
                );
              } finally {
                setLocal(() => isLoading = false);
              }
            }

            return AlertDialog(
              title: const Text('Изменить имя'),
              content: Form(
                key: formKey,
                child: TextFormField(
                  controller: controller,
                  decoration: const InputDecoration(labelText: 'Имя', hintText: 'Новое Имя'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Введите имя';
                    if (v.trim().length < 2) return 'Слишком короткое имя';
                    return null;
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : submit,
                  child: isLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==================== CHANGE PASSWORD ====================
  Future<void> _changePassword() async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setLocal) {
            Future<void> submit() async {
              if (!formKey.currentState!.validate()) return;

              setLocal(() => isLoading = true);

              try {
                await ApiClient.changePassword(
                  userId: widget.userId,
                  currentPassword: currentController.text.trim(),
                  newPassword: newController.text.trim(),
                );

                if (!mounted) return;

                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Пароль изменён')),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.toString())),
                );
              } finally {
                setLocal(() => isLoading = false);
              }
            }

            return AlertDialog(
              title: const Text('Изменить пароль'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: currentController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Текущий пароль'),
                      validator: (v) => v == null || v.isEmpty
                          ? 'Введите текущий пароль'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: newController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Новый пароль'),
                      validator: (v) =>
                          v == null || v.length < 6 ? 'Минимум 6 символов' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: confirmController,
                      obscureText: true,
                      decoration:
                          const InputDecoration(labelText: 'Повторите пароль'),
                      validator: (v) => v != newController.text
                          ? 'Пароли не совпадают'
                          : null,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : submit,
                  child: isLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('Профиль'),
        actions: [
          IconButton(
            icon: _isLogoutProcessing
                ? const CircularProgressIndicator(color: Colors.white)
                : const Icon(Icons.logout),
            onPressed: _isLogoutProcessing ? null : _logout,
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // КАРТОЧКА ПРОФИЛЯ
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    child: Text(
                      _fullName.isNotEmpty ? _fullName[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_fullName, style: t.textTheme.titleMedium),
                        Text(_phone, style: t.textTheme.bodyMedium),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // КАРТОЧКА ДЕЙСТВИЙ
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text("Изменить имя"),
                  onTap: _changeName,
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.lock),
                  title: const Text("Изменить пароль"),
                  onTap: _changePassword,
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.support_agent, color: Colors.blue),
                  title: const Text("Служба поддержки"),
                  onTap: _openSupport,
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text("Выйти"),
                  onTap: _logout,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // КНОПКА УДАЛЕНИЯ АККАУНТА (Отдельно, чтобы не нажать случайно)
          Card(
            color: Colors.red.shade50,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text(
                "Удалить аккаунт",
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text("Безвозвратное удаление всех данных"),
              onTap: _isLogoutProcessing ? null : _deleteAccount,
            ),
          ),
        ],
      ),
    );
  }
}