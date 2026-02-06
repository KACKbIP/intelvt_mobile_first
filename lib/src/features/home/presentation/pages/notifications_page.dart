import 'package:flutter/material.dart';
import '../../../../core/services/api_client.dart'; // Путь к вашему api_client

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late Future<List<NotificationItem>> _future;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _future = ApiClient.getNotifications();
    });
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Уведомления'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadData(),
        child: FutureBuilder<List<NotificationItem>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text('Ошибка: ${snapshot.error}'),
                    TextButton(onPressed: _loadData, child: const Text('Повторить'))
                  ],
                ),
              );
            }

            final items = snapshot.data ?? [];

            if (items.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 100),
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Уведомлений нет', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = items[index];
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                style: const TextStyle(
                                  fontSize: 16, 
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              _formatDate(item.createdAt),
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                        if (item.body.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            item.body,
                            style: const TextStyle(fontSize: 14, color: Colors.black87),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}