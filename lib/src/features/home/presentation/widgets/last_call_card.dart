import 'package:flutter/material.dart';
import 'package:intelvt_mobile_first/src/core/api/client/api_client.dart';

class LastCallCard extends StatelessWidget {
  final CallItem lastCall;

  const LastCallCard({required this.lastCall});

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
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
