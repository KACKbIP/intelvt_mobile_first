import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class BalanceCard extends StatelessWidget {
  final String uniqueNumber; 
  final int balanceTenge;
  final int tariffPerMinute;
  final int minutesUsedToday;
  final String? nextLimitDate;

  const BalanceCard({
    required this.uniqueNumber,
    required this.balanceTenge,
    required this.tariffPerMinute,
    required this.minutesUsedToday,
    this.nextLimitDate,
  });

  static const Color _kaspiRed = Color(0xFFE31E24);

  Future<void> _openKaspi() async {
    final String url = 'https://kaspi.kz/pay/ZHalin?18392=$uniqueNumber';

    final uri = Uri.parse(url);

    try {
      await  launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Не удалось открыть Kaspi: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final int minutesLeft = tariffPerMinute == 0
        ? 0
        : balanceTenge ~/ tariffPerMinute;

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
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Сегодня использовано: $minutesUsedToday мин',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    if (nextLimitDate != null && nextLimitDate!.isNotEmpty)
                      Text(
                        'Следующее пополнение: $nextLimitDate',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
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
                icon: const KaspiLogo(),
                label: const Text(
                  'Пополнить через Kaspi',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class KaspiLogo extends StatelessWidget {
  const KaspiLogo({super.key});

  static const Color _kaspiRed = Color(0xFFE31E24);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(color: _kaspiRed, shape: BoxShape.circle),
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
