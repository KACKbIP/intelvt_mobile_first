import 'package:flutter/material.dart';

class CallsHistoryPage extends StatelessWidget {
  const CallsHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('История звонков')),
      body: const Center(
        child: Text('Здесь будет полная история звонков'),
      ),
    );
  }
}