import 'dart:io';
import 'package:android_intent_plus/android_intent.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PermissionsService {
  static const String _kAutoStartSeen = 'auto_start_seen_key';
  
  Future<void> requestBatteryOptimization() async {
    if (!Platform.isAndroid) return;
    var status = await Permission.ignoreBatteryOptimizations.status;
    if (!status.isGranted) {
      await Permission.ignoreBatteryOptimizations.request();
    }
  }

  Future<void> requestSystemAlertWindow() async {
    if (!Platform.isAndroid) return;
    var status = await Permission.systemAlertWindow.status;
    if (!status.isGranted) {
      await Permission.systemAlertWindow.request();
    }
  }

  Future<void> openAutoStartSettings(BuildContext context) async {
    if (!Platform.isAndroid) return;

    final prefs = await SharedPreferences.getInstance();
    final bool alreadySeen = prefs.getBool(_kAutoStartSeen) ?? false;
    
    if (alreadySeen) return;

    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final manufacturer = androidInfo.manufacturer.toLowerCase();

    // Бренды, где есть "Связанный старт" или жесткий "Автозапуск"
    const aggressiveBrands = [
      'xiaomi', 'redmi', 'poco', 
      'huawei', 'honor', 
      'zte', 'nubia', 
      'oppo', 'vivo', 'realme', 
      'meizu', 'oneplus', 
      'infinix', 'tecno'
    ];

    bool isAggressive = aggressiveBrands.any((brand) => manufacturer.contains(brand));
    if (!isAggressive) return;

    if (!context.mounted) return;

    // ✅ ОБНОВЛЕННАЯ ИНСТРУКЦИЯ ПРО СВЯЗАННЫЙ СТАРТ
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Разрешение на звонки'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('На телефонах $manufacturer система блокирует запуск звонка из пуш-уведомления.\n'),
              
              const Text(
                'Обязательно включите:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildStep('1. Автозапуск (Auto-start)'),
              _buildStep('2. Связанный старт (Associated Start)'),
              const SizedBox(height: 8),
              const Text('Без "Связанного старта" звонок не пройдет!'),
              
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: const Text(
                  'Путь: Настройки -> Приложения -> IntelVT -> Батарея / Запуск -> Включить все галочки.',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Позже'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Открыть настройки'),
          ),
        ],
      ),
    );

    await prefs.setBool(_kAutoStartSeen, true);

    if (result == true) {
      await _jumpToAutoStart(manufacturer);
    }
  }

  Widget _buildStep(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Future<void> _jumpToAutoStart(String manufacturer) async {
    try {
      if (manufacturer.contains('xiaomi') || manufacturer.contains('redmi') || manufacturer.contains('poco')) {
        await const AndroidIntent(
          action: 'miui.intent.action.OP_AUTO_START',
          componentName: 'com.miui.securitycenter/com.miui.permcenter.autostart.AutoStartManagementActivity',
        ).launch();
      } 
      else if (manufacturer.contains('nubia')) {
        try {
          // Попытка открыть управление автозапуском Nubia
          await const AndroidIntent(
            componentName: 'cn.nubia.security/cn.nubia.security.appmanage.SelfStartActivity',
          ).launch();
        } catch (_) {
           // Запасной вариант (ZTE)
           await const AndroidIntent(
             componentName: 'com.zte.heartyservice/com.zte.heartyservice.autorun.AppAutoRunManager',
          ).launch();
        }
      }
      else if (manufacturer.contains('zte')) {
        await const AndroidIntent(
          componentName: 'com.zte.heartyservice/com.zte.heartyservice.autorun.AppAutoRunManager',
        ).launch();
      } 
      else if (manufacturer.contains('huawei') || manufacturer.contains('honor')) {
        await const AndroidIntent(
          componentName: 'com.huawei.systemmanager/com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity',
        ).launch();
      } 
      else if (manufacturer.contains('oppo')) {
        await const AndroidIntent(
          componentName: 'com.coloros.safecenter/com.coloros.safecenter.permission.startup.StartupAppListActivity',
        ).launch();
      } 
      else if (manufacturer.contains('vivo')) {
        await const AndroidIntent(
          componentName: 'com.vivo.permissionmanager/com.vivo.permissionmanager.activity.BgStartUpManagerActivity',
        ).launch();
      } 
      else {
        await openAppSettings();
      }
    } catch (e) {
      await openAppSettings();
    }
  }
}