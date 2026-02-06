import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpCard extends StatelessWidget {
  const HelpCard({super.key});

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
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
                  final Uri url = Uri.parse('tg://resolve?domain=intelvt');
                  try {
                    if (!await launchUrl(
                      url,
                      mode: LaunchMode.externalApplication,
                    )) {
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
