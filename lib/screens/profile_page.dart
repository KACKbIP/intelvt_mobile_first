import 'package:flutter/material.dart';

import '../services/api_client.dart';
import 'login_page.dart';

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
  late String _fullName;
  late String _phone;

  bool _isLogoutProcessing = false;

  @override
  void initState() {
    super.initState();
    _fullName = widget.fullName ?? 'Имя пользователя';
    _phone = widget.phone ?? '+7 XXX XXX XX XX';
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
                Navigator.pop(dialogContext);

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
                  decoration: const InputDecoration(labelText: 'Имя'),
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

  // ==================== SETTINGS ====================
  void _openSettings() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => const Padding(
        padding: EdgeInsets.all(16),
        child: Text("Здесь будут настройки"),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль'),
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
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    child: Text(
                      _fullName[0].toUpperCase(),
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_fullName, style: t.textTheme.titleMedium),
                      Text(_phone, style: t.textTheme.bodyMedium),
                    ],
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

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
                  leading: const Icon(Icons.settings),
                  title: const Text("Настройки"),
                  onTap: _openSettings,
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text(
                    "Выйти",
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: _logout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
