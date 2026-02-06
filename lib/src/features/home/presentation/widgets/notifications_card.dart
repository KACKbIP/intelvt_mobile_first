import 'package:flutter/material.dart';

class NotificationsCard extends StatelessWidget {
  final List<String> notifications;

  const NotificationsCard({required this.notifications});

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
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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