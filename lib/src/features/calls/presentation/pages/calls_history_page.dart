import 'package:flutter/material.dart';
import '../../../../core/services/api_client.dart';

class CallsHistoryPage extends StatefulWidget {
  // Параметры делаем необязательными (?), чтобы можно было вызывать конструктор без них
  final String? soldierName;
  final List<CallItem>? calls;

  const CallsHistoryPage({
    super.key,
    this.soldierName,
    this.calls,
  });

  @override
  State<CallsHistoryPage> createState() => _CallsHistoryPageState();
}

class _CallsHistoryPageState extends State<CallsHistoryPage> {
  bool _isLoading = false;
  // Список для отображения (хранит звонок + имя солдата)
  List<_HistoryRowData> _items = [];
  String _title = 'История звонков';

  @override
  void initState() {
    super.initState();
    _initData();
  }

  // Если вдруг родительский виджет обновит параметры
  @override
  void didUpdateWidget(covariant CallsHistoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.calls != widget.calls) {
      _initData();
    }
  }

  void _initData() {
    if (widget.calls != null) {
      // РЕЖИМ 1: Просмотр конкретного солдата (данные переданы)
      final name = widget.soldierName ?? '';
      setState(() {
        _title = name.isEmpty ? 'История звонков' : 'История: $name';
        _items = widget.calls!
            .map((c) => _HistoryRowData(call: c, soldierName: name))
            .toList()
          ..sort((a, b) => b.call.dateTime.compareTo(a.call.dateTime));
        _isLoading = false;
      });
    } else {
      // РЕЖИМ 2: Общая вкладка (данных нет, грузим всё сами)
      _loadGlobalHistory();
    }
  }

  Future<void> _loadGlobalHistory() async {
    setState(() {
      _isLoading = true;
      _title = 'История звонков';
    });

    try {
      // Запрашиваем дашборд, чтобы вытащить оттуда все звонки всех солдат
      final data = await ApiClient.getParentDashboard();
      final allRows = <_HistoryRowData>[];

      for (var soldier in data.soldiers) {
        // Добавляем список calls
        for (var call in soldier.calls) {
          allRows.add(_HistoryRowData(call: call, soldierName: soldier.name));
        }
        
        // Если lastCall есть и он новее/отсутствует в calls, можно добавить и его,
        // но обычно бэкенд возвращает всё в calls. Оставим простую логику:
        // берем только list 'calls', предполагая, что там полная история.
      }

      // Сортировка: от новых к старым
      allRows.sort((a, b) => b.call.dateTime.compareTo(a.call.dateTime));

      if (mounted) {
        setState(() {
          _items = allRows;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // Можно показать ошибку или пустой экран
        debugPrint('Ошибка загрузки истории: $e');
      }
    }
  }

  // --- Вспомогательные методы UI ---

  String _formatDateTime(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$d.$m.$y в $hh:$mm';
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0 мин';
    final minutes = (seconds / 60).ceil();
    return '$minutes мин';
  }

  IconData _iconByType(CallType type) {
    return type == CallType.answered ? Icons.call_made : Icons.call_missed;
  }

  Color _colorByType(CallType type) {
    return type == CallType.answered ? Colors.green : Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  // Обновляем только если это "общий" режим
                  onRefresh: () async {
                    if (widget.calls == null) await _loadGlobalHistory();
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _items.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      return _buildHistoryItem(_items[index]);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'История звонков пуста',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            if (widget.calls == null) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: _loadGlobalHistory,
                child: const Text('Обновить'),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(_HistoryRowData item) {
    final call = item.call;
    final isMissed = call.type == CallType.missed;
    
    // Если мы в общем списке (widget.soldierName == null), показываем имя солдата
    // Если зашли в конкретного солдата, имя и так в заголовке, можно не дублировать
    final bool showNameInRow = (widget.soldierName == null);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _colorByType(call.type).withOpacity(0.1),
        child: Icon(
          _iconByType(call.type),
          color: _colorByType(call.type),
          size: 20,
        ),
      ),
      title: Text(
        showNameInRow 
            ? '${item.soldierName} (${_formatDateTime(call.dateTime)})'
            : _formatDateTime(call.dateTime),
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: Text(
        isMissed
            ? 'Не дозвонился'
            : 'Длительность: ${_formatDuration(call.durationSeconds)}',
        style: TextStyle(
          color: isMissed ? Colors.red : Colors.grey.shade600,
          fontSize: 13,
        ),
      ),
      trailing: isMissed
          ? const Icon(Icons.error_outline, color: Colors.red, size: 20)
          : const Icon(Icons.check, color: Colors.green, size: 20),
    );
  }
}

/// Вспомогательный класс для отображения в списке
class _HistoryRowData {
  final CallItem call;
  final String soldierName;

  _HistoryRowData({required this.call, required this.soldierName});
}