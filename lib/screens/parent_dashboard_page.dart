import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ParentDashboardPage extends StatelessWidget {
  const ParentDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Мок-данные, потом заменишь на реальные с API
    const soldierName = 'Кенесары Касымулы';
    const soldierUnit = 'В/ч 12345, Алматы';
    const soldierStatus = 'Доступен';
    const soldierStatusColor = Colors.green;

    const balanceTenge = 1700;       // баланс в тенге
    const tariffPerMinute = 100;     // 1 минута = 100 ₸
    const minutesUsedToday = 12;     // сколько минут уже потратили
    const nextLimitDate = '12.12.2025';

    final calls = [
      const CallItem(
        type: CallType.answered,
        dateTime: 'Сегодня, 10:23',
        duration: '12 мин',
      ),
      const CallItem(
        type: CallType.missed,
        dateTime: 'Вчера, 21:40',
        duration: '',
      ),
      const CallItem(
        type: CallType.answered,
        dateTime: '02.12.2025, 19:15',
        duration: '8 мин',
      ),
      const CallItem(
        type: CallType.answered,
        dateTime: '01.12.2025, 18:05',
        duration: '5 мин',
      ),
    ];

    final notifications = [
      'Был пропущенный звонок от Кенесары (вчера, 21:40)',
      'Лимит минут обновлён (01.12.2025)',
      'Профиль успешно подтверждён',
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Кабинет родителя'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SoldierCard(
                name: soldierName,
                unit: soldierUnit,
                status: soldierStatus,
                statusColor: soldierStatusColor,
              ),
              const SizedBox(height: 16),

              _BalanceCard(
                balanceTenge: balanceTenge,
                tariffPerMinute: tariffPerMinute,
                minutesUsedToday: minutesUsedToday,
                nextLimitDate: nextLimitDate,
              ),
              const SizedBox(height: 16),

              _LastCallCard(lastCall: calls.first),
              const SizedBox(height: 16),

              _CallsHistoryCard(calls: calls),
              const SizedBox(height: 16),

              _NotificationsCard(notifications: notifications),
              const SizedBox(height: 16),

              _HelpCard(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ================== МОДЕЛИ ==================

enum CallType { answered, missed }

class CallItem {
  final CallType type;
  final String dateTime;
  final String duration;

  const CallItem({
    required this.type,
    required this.dateTime,
    required this.duration,
  });
}

// ================== ВИДЖЕТЫ ==================

class _SoldierCard extends StatelessWidget {
  final String name;
  final String unit;
  final String status;
  final Color statusColor;

  const _SoldierCard({
    required this.name,
    required this.unit,
    required this.status,
    required this.statusColor,
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
              radius: 28,
              child: Text(
                name.isNotEmpty ? name[0] : '?',
                style: const TextStyle(fontSize: 24),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    unit,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        status,
                        style: TextStyle(
                          fontSize: 14,
                          color: statusColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
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

class _BalanceCard extends StatelessWidget {
  final int balanceTenge;      // баланс в тенге
  final int tariffPerMinute;   // стоимость минуты
  final int minutesUsedToday;  // сколько минут уже поговорили сегодня
  final String nextLimitDate;

  const _BalanceCard({
    required this.balanceTenge,
    required this.tariffPerMinute,
    required this.minutesUsedToday,
    required this.nextLimitDate,
  });

  static const String _kaspiUrl = 'https://kaspi.kz'; // сюда потом вставишь свой платежный линк
  static const Color _kaspiRed = Color(0xFFE31E24);

  Future<void> _openKaspi() async {
    final uri = Uri.parse(_kaspiUrl);
    if (!await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    )) {
      // можно залогировать или показать ошибку, но пока просто игнор
    }
  }

  @override
  Widget build(BuildContext context) {
    // сколько минут можно ещё поговорить
    final int minutesLeft = tariffPerMinute == 0
        ? 0
        : balanceTenge ~/ tariffPerMinute;

    // для прогресс-бара: использовано из общего лимита (использовано + остаток)
    final int totalMinutes = minutesLeft + minutesUsedToday;
    final double progress = totalMinutes == 0
        ? 0
        : (minutesUsedToday / totalMinutes);

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
                // Слева — баланс в деньгах и минутах
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

                // Справа — тариф и служебная инфа
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Тариф: $tariffPerMinute ₸ / мин',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Сегодня использовано: $minutesUsedToday мин',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Следующее пополнение: $nextLimitDate',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
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

            // Кнопка пополнения через Kaspi
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _openKaspi,
                style: TextButton.styleFrom(
                  foregroundColor: _kaspiRed,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

/// Простая эмблема Kaspi в виде красного кружка с белым "k"
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
                    lastCall.dateTime,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isMissed
                        ? 'Пропущенный'
                        : 'Длительность: ${lastCall.duration}',
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

  const _CallsHistoryCard({required this.calls});

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
              'История звонков',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: calls.length,
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
                            call.dateTime,
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
                    if (!isMissed && call.duration.isNotEmpty)
                      Text(
                        call.duration,
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
                separatorBuilder: (_, __) => const SizedBox(height: 8),
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
      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.9),
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
                onPressed: () {
                  // тут потом откроешь экран/диалог поддержки или чат
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
