import 'package:flutter/material.dart';
import 'package:intelvt_mobile_first/src/features/home/presentation/widgets/widgets.dart';

import '../../../../core/services/api_client.dart';

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Кабинет родителя'),
        centerTitle: true,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ParentCard(parentName: parentName),
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

                      SoldierCard(
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

                      BalanceCard(
                        uniqueNumber: soldier.uniqueNumber,
                        balanceTenge: soldier.balanceTenge,
                        tariffPerMinute: soldier.tariffPerMinute,
                        minutesUsedToday: soldier.minutesUsedToday,
                        nextLimitDate: null,
                      ),
                      const SizedBox(height: 12),

                      if (soldier.lastCall != null ||
                          soldier.calls.isNotEmpty) ...[
                        LastCallCard(
                          lastCall: soldier.lastCall ?? soldier.calls.first,
                        ),
                        const SizedBox(height: 12),
                        if (soldier.calls.isNotEmpty)
                          CallsHistoryCard(
                            calls: soldier.calls,
                            soldierName:
                                soldier.name, 
                          )
                        else
                          const Text(
                            'Пока нет истории звонков',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                      ] else
                        const Text(
                          'Пока нет звонков',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),

                      const SizedBox(height: 20),
                    ],

                    NotificationsCard(notifications: notifications),
                    const SizedBox(height: 16),

                    HelpCard(),
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





