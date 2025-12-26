import 'package:flutter/material.dart';
import 'parent_dashboard_page.dart';
import 'calls_history_page.dart';
import 'notifications_page.dart';
import 'profile_page.dart';
import '/services/permissions_service.dart';
import '/services/api_client.dart';
import 'dart:io'; // Обязательно добавь для Platform
import 'package:device_info_plus/device_info_plus.dart'; // Полезно для имен

class MainNavigationPage extends StatefulWidget {
  final int userId;
  final String phone;
  final String? fullName;

  const MainNavigationPage({
    super.key,
    required this.userId,
    required this.phone,
    this.fullName,
  });

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _currentIndex = 0;
  int _previousIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    _pages = [
      const ParentDashboardPage(),   
      const CallsHistoryPage(),
      const NotificationsPage(),
      ProfilePage(
        userId: widget.userId,
        phone: widget.phone,
        fullName: widget.fullName,
      ),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermissions();
    });
  }

  Future<void> _checkPermissions() async {
  // 1. Регистрируем устройство с учетом платформы
  try {
    String deviceDisplayName = 'Unknown Device';
    
    if (Platform.isIOS) {
      deviceDisplayName = 'iPhone User';
    } else if (Platform.isAndroid) {
      deviceDisplayName = 'Android Parent';
    }

    // Вызываем регистрацию ОДИН раз
    await ApiClient.registerDevice(deviceName: deviceDisplayName); 
    
  } catch (e) {
    debugPrint("⚠️ Не удалось обновить токен: $e");
  }

  // 2. Специфические разрешения только для Android
  if (Platform.isAndroid) {
    final service = PermissionsService();
    
    // Просим игнорировать оптимизацию батареи
    await service.requestBatteryOptimization();
    
    // Просим разрешение рисовать поверх окон
    await service.requestSystemAlertWindow();

    // Если это Xiaomi/Meizu/Huawei - просим включить автозапуск
    if (mounted) {
      await service.openAutoStartSettings(context);
    }
  }
}

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final inFromRight = _currentIndex >= _previousIndex;
          final offsetAnimation = Tween<Offset>(
            begin: Offset(inFromRight ? 0.1 : -0.1, 0),
            end: Offset.zero,
          ).animate(animation);

          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: offsetAnimation,
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey<int>(_currentIndex),
          child: _pages[_currentIndex],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: colorScheme.surface.withOpacity(0.96),
              boxShadow: [
                BoxShadow(
                  blurRadius: 18,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                  color: Colors.black.withOpacity(0.12),
                ),
              ],
            ),
            child: NavigationBar(
              height: 64,
              elevation: 0,
              selectedIndex: _currentIndex,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              onDestinationSelected: (index) {
                setState(() {
                  _previousIndex = _currentIndex;
                  _currentIndex = index;
                });
              },
              destinations: const [
                NavigationDestination(
                  icon: _NavIcon(icon: Icons.home_outlined),
                  selectedIcon:
                      _NavIcon(icon: Icons.home_rounded, isSelected: true),
                  label: 'Главная',
                ),
                NavigationDestination(
                  icon: _NavIcon(icon: Icons.history),
                  selectedIcon:
                      _NavIcon(icon: Icons.history_rounded, isSelected: true),
                  label: 'Звонки',
                ),
                NavigationDestination(
                  icon: _NavIcon(icon: Icons.notifications_none),
                  selectedIcon:
                      _NavIcon(icon: Icons.notifications, isSelected: true),
                  label: 'Уведомления',
                ),
                NavigationDestination(
                  icon: _NavIcon(icon: Icons.person_outline),
                  selectedIcon:
                      _NavIcon(icon: Icons.person, isSelected: true),
                  label: 'Профиль',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Иконка с лёгкой анимацией масштаба
class _NavIcon extends StatelessWidget {
  final IconData icon;
  final bool isSelected;

  const _NavIcon({
    required this.icon,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 1, end: isSelected ? 1.15 : 1.0),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: Icon(
            icon,
            size: 24,
            color: isSelected
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
        );
      },
    );
  }
}