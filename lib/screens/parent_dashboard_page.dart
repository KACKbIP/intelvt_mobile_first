import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_client.dart';
import 'calls_history_page.dart'; // ✅ Импортируем страницу истории

class ParentDashboardPage extends StatefulWidget {
  const ParentDashboardPage({super.key});

  @override
  State<ParentDashboardPage> createState() => _ParentDashboardPageState();
}

class _ParentDashboardPageState extends State<ParentDashboardPage> {
  late Future<ParentDashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiClient.getParentDashboard();
  }

  Future<void> _reload() async {
    setState(() {
      _future = ApiClient.getParentDashboard();
    });
  }

  Future<void> _editSoldierName(
    BuildContext context,
    SoldierDashboardData soldier,
  ) async {
    final controller = TextEditingController(text: soldier.soldierName);

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Имя военнослужащего'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Имя (как будет отображаться у вас)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isEmpty) return;
                Navigator.of(context).pop(text);
              },
              child: const Text('Сохранить'),
            ),
          ],
        );
      },
    );

    if (result == null) return;

    try {
      await ApiClient.updateSoldierName(
        soldierId: soldier.soldierId,
        name: result,
      );
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Кабинет родителя'),
      ),
      body: SafeArea(
        child: FutureBuilder<ParentDashboardData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Ошибка при загрузке: ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final data = snapshot.data!;
            final parentName = data.parentName;
            final soldiers = data.soldiers;
            final notifications = data.notifications;

            return RefreshIndicator(
              onRefresh: _reload,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ParentCard(parentName: parentName),
                    const SizedBox(height: 16),

                    for (final soldier in soldiers) ...[
                      Text(
                        soldier.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),

                      _SoldierCard(
                        name: soldier.name,
                        unit: soldier.unit,
                        uniqueNumber: soldier.uniqueNumber,
                        status: soldier.balanceTenge > 0
                            ? 'Можно звонить'
                            : 'Баланс нулевой',
                        statusColor: soldier.balanceTenge > 0
                            ? Colors.green
                            : Colors.red,
                        onEditName: () => _editSoldierName(context, soldier),
                      ),
                      const SizedBox(height: 12),

                      _BalanceCard(
                        uniqueNumber: soldier.uniqueNumber,
                        balanceTenge: soldier.balanceTenge,
                        tariffPerMinute: soldier.tariffPerMinute,
                        minutesUsedToday: soldier.minutesUsedToday,
                        nextLimitDate: null, 
                      ),
                      const SizedBox(height: 12),

                      if (soldier.lastCall != null ||
                          soldier.calls.isNotEmpty) ...[
                        _LastCallCard(
                          lastCall: soldier.lastCall ?? soldier.calls.first,
                        ),
                        const SizedBox(height: 12),
                        if (soldier.calls.isNotEmpty)
                          _CallsHistoryCard(
                            calls: soldier.calls,
                            soldierName: soldier.name, // ✅ Передаем имя для навигации
                          )
                        else
                          const Text(
                            'Пока нет истории звонков',
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey),
                          ),
                      ] else
                        const Text(
                          'Пока нет звонков',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),

                      const SizedBox(height: 20),
                    ],

                    _NotificationsCard(notifications: notifications),
                    const SizedBox(height: 16),

                    _HelpCard(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ================== ВИДЖЕТЫ ==================

class _ParentCard extends StatelessWidget {
  final String parentName;

  const _ParentCard({required this.parentName});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              child: Text(
                parentName.isNotEmpty ? parentName[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 24),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    parentName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Родитель военнослужащего(их)',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _SoldierCard extends StatelessWidget {
  final String name;
  final String unit;
  final String uniqueNumber; // ✅ Новое поле
  final String? status;
  final Color? statusColor;
  final VoidCallback? onEditName;

  const _SoldierCard({
    required this.name,
    required this.unit,
    required this.uniqueNumber, // ✅ Обязательный параметр
    this.status,
    this.statusColor,
    this.onEditName,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              child: Text(
                name.isNotEmpty ? name[0] : '?',
                style: const TextStyle(fontSize: 20),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- ИМЯ И РЕДАКТИРОВАНИЕ ---
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (onEditName != null)
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          tooltip: 'Изменить имя',
                          onPressed: onEditName,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          style: IconButton.styleFrom(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  
                  // --- ПОДРАЗДЕЛЕНИЕ ---
                  Text(
                    unit,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  
                  // --- ✅ УНИКАЛЬНЫЙ НОМЕР ---
                  const SizedBox(height: 2),
                  Text(
                    'ID: $uniqueNumber',
                    style: TextStyle(
                      fontSize: 12, 
                      color: Colors.grey.withOpacity(0.8)
                    ),
                  ),

                  const SizedBox(height: 8),

                  // --- СТАТУС ---
                  if (status != null && status!.isNotEmpty) ...[
                    Row(
                      children: [
                        if (statusColor != null)
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        if (statusColor != null) const SizedBox(width: 6),
                        Text(
                          status!,
                          style: TextStyle(
                            fontSize: 14,
                            color: statusColor ?? Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final String uniqueNumber; // ✅ Используем уникальный номер солдата
  final int balanceTenge;
  final int tariffPerMinute;
  final int minutesUsedToday;
  final String? nextLimitDate;

  const _BalanceCard({
    required this.uniqueNumber, // ✅ Обязательный параметр
    required this.balanceTenge,
    required this.tariffPerMinute,
    required this.minutesUsedToday,
    this.nextLimitDate,
  });

  static const Color _kaspiRed = Color(0xFFE31E24);

  Future<void> _openKaspi() async {
    // ✅ Подставляем uniqueNumber в ссылку Kaspi
    final String url = 'https://kaspi.kz/pay/ZHalin?18392=$uniqueNumber';
    
    final uri = Uri.parse(url);
    
    // mode: LaunchMode.externalApplication открывает именно приложение Kaspi
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('Не удалось открыть Kaspi: $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final int minutesLeft =
        tariffPerMinute == 0 ? 0 : balanceTenge ~/ tariffPerMinute;

    final int totalMinutes = minutesLeft + minutesUsedToday;
    final double progress =
        totalMinutes == 0 ? 0 : (minutesUsedToday / totalMinutes);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Баланс связи',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$balanceTenge ₸',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '≈ $minutesLeft мин осталось',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Тариф: $tariffPerMinute ₸ / мин',
                      style:
                          const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Сегодня использовано: $minutesUsedToday мин',
                      style:
                          const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    if (nextLimitDate != null &&
                        nextLimitDate!.isNotEmpty)
                      Text(
                        'Следующее пополнение: $nextLimitDate',
                        style: const TextStyle(
                            fontSize: 14, color: Colors.grey),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _openKaspi,
                style: TextButton.styleFrom(
                  foregroundColor: _kaspiRed,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                ),
                icon: const _KaspiLogo(),
                label: const Text(
                  'Пополнить через Kaspi',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KaspiLogo extends StatelessWidget {
  const _KaspiLogo();

  static const Color _kaspiRed = Color(0xFFE31E24);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        color: _kaspiRed,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Text(
        'k',
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _LastCallCard extends StatelessWidget {
  final CallItem lastCall;

  const _LastCallCard({required this.lastCall});

  String _formatDateTime(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$d.$m.$y, $hh:$mm';
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '';
    final minutes = (seconds / 60).ceil();
    return '$minutes мин';
  }

  @override
  Widget build(BuildContext context) {
    final isMissed = lastCall.type == CallType.missed;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              isMissed ? Icons.phone_missed : Icons.phone_in_talk,
              color: isMissed ? Colors.red : Colors.green,
              size: 28,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Последний звонок',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDateTime(lastCall.dateTime),
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isMissed
                        ? 'Пропущенный'
                        : 'Длительность: ${_formatDuration(lastCall.durationSeconds)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: isMissed ? Colors.red : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CallsHistoryCard extends StatelessWidget {
  final List<CallItem> calls;
  final String soldierName; // ✅ Новое поле

  const _CallsHistoryCard({
    required this.calls,
    required this.soldierName, // ✅ Требуем имя
  });

  IconData _iconByType(CallType type) {
    switch (type) {
      case CallType.answered:
        return Icons.call_made;
      case CallType.missed:
        return Icons.call_missed;
    }
  }

  Color _colorByType(CallType type) {
    switch (type) {
      case CallType.answered:
        return Colors.green;
      case CallType.missed:
        return Colors.red;
    }
  }

  String _labelByType(CallType type) {
    switch (type) {
      case CallType.answered:
        return 'Разговор';
      case CallType.missed:
        return 'Пропущенный';
    }
  }

  String _formatDateTime(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$d.$m.$y, $hh:$mm';
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '';
    final minutes = (seconds / 60).ceil();
    return '$minutes мин';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Заголовок с кнопкой "Все"
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'История звонков',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (calls.isNotEmpty)
                  InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => CallsHistoryPage(
                            soldierName: soldierName,
                            calls: calls,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Text(
                        'Все',
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            
            if (calls.isEmpty)
              const Text(
                'Пока нет истории звонков',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                // Берем только первые 5 для превью
                itemCount: calls.length > 5 ? 5 : calls.length,
                separatorBuilder: (_, __) => const Divider(height: 12),
                itemBuilder: (context, index) {
                  final call = calls[index];
                  final isMissed = call.type == CallType.missed;

                  return Row(
                    children: [
                      Icon(
                        _iconByType(call.type),
                        color: _colorByType(call.type),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatDateTime(call.dateTime),
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _labelByType(call.type),
                              style: TextStyle(
                                fontSize: 13,
                                color: isMissed ? Colors.red : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isMissed && call.durationSeconds > 0)
                        Text(
                          _formatDuration(call.durationSeconds),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _NotificationsCard extends StatelessWidget {
  final List<String> notifications;

  const _NotificationsCard({required this.notifications});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Уведомления',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            if (notifications.isEmpty)
              const Text(
                'Нет новых уведомлений',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: notifications.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.notifications, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          notifications[index],
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _HelpCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      color: Theme.of(context)
          .colorScheme
          .primaryContainer
          .withOpacity(0.9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Помощь и поддержка',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Если у вас не получается дозвониться или есть вопросы по работе сервиса — нажмите кнопку ниже.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Align(
  alignment: Alignment.centerRight,
  child: FilledButton.icon(
    onPressed: () async {
      final Uri url = Uri.parse('https://t.me/intelvt?direct');
      // mode: LaunchMode.externalApplication заставит открыть именно приложение Telegram (или браузер),
      // а не WebView внутри твоего приложения.
      try {
        if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
          throw Exception('Не удалось открыть $url');
        }
      } catch (e) {
        // Можно показать SnackBar с ошибкой, если ссылка не открылась
        print('Ошибка при открытии ссылки: $e');
      }
    },
    icon: const Icon(Icons.support_agent),
    label: const Text('Связаться с поддержкой'),
  ),
),
          ],
        ),
      ),
    );
  }
}