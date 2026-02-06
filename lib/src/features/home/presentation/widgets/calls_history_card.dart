import 'package:flutter/material.dart';
import 'package:intelvt_mobile_first/src/features/calls/presentation/pages/calls_history_page.dart';
import 'package:intelvt_mobile_first/src/core/api/client/api_client.dart';

class CallsHistoryCard extends StatelessWidget {
  final List<CallItem> calls;
  final String soldierName;

  const CallsHistoryCard({
    super.key,
    required this.calls,
    required this.soldierName,
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
