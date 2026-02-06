import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/services/security_service.dart';
import '../../../../core/api/client/api_client.dart';
import '../../../home/presentation/pages/main_navigation_page.dart';
import 'login_page.dart';

enum PinMode { create, auth }

class PinCodePage extends StatefulWidget {
  final PinMode mode;
  
  final int? userId;
  final String? phone;
  final String? fullName;

  const PinCodePage({
    super.key,
    required this.mode,
    this.userId,
    this.phone,
    this.fullName,
  });

  @override
  State<PinCodePage> createState() => _PinCodePageState();
}

class _PinCodePageState extends State<PinCodePage> {
  String _currentPin = "";
  String? _firstPin; 
  String _message = "";
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _updateMessage();
    
    // Если это вход - сразу пробуем FaceID
    if (widget.mode == PinMode.auth) {
      _tryBiometrics();
    }
  }

  void _updateMessage() {
    setState(() {
      if (widget.mode == PinMode.auth) {
        _message = "Введите код доступа";
      } else {
        if (_firstPin == null) {
          _message = "Придумайте код доступа";
        } else {
          _message = "Повторите код доступа";
        }
      }
    });
  }

  Future<void> _tryBiometrics() async {
    final enabled = await SecurityService.isBiometricsEnabled();
    if (!enabled) return;

    final authenticated = await SecurityService.authenticateBio();
    if (authenticated) _onSuccess();
  }

  void _onDigitPress(String digit) {
    if (_currentPin.length < 4) {
      setState(() {
        _isError = false;
        _currentPin += digit;
      });
      if (_currentPin.length == 4) _validatePin();
    }
  }

  void _onDeletePress() {
    if (_currentPin.isNotEmpty) {
      setState(() {
        _isError = false;
        _currentPin = _currentPin.substring(0, _currentPin.length - 1);
      });
    }
  }

  Future<void> _validatePin() async {
    if (widget.mode == PinMode.create) {
      // --- СОЗДАНИЕ ---
      if (_firstPin == null) {
        setState(() {
          _firstPin = _currentPin;
          _currentPin = "";
          _message = "Повторите код доступа";
        });
      } else {
        if (_currentPin == _firstPin) {
          await SecurityService.setPin(_currentPin);
          if (mounted) await _askBiometrics();
          if (mounted) _onSuccess();
        } else {
          _showError("Коды не совпадают");
          Future.delayed(const Duration(milliseconds: 500), () {
             if(mounted) setState(() { _firstPin = null; _currentPin = ""; _updateMessage(); });
          });
        }
      }
    } else {
      // --- ВХОД ---
      final isValid = await SecurityService.checkPin(_currentPin);
      if (isValid) {
        _onSuccess();
      } else {
        _showError("Неверный код");
      }
    }
  }

  void _showError(String msg) {
    HapticFeedback.vibrate();
    setState(() {
      _isError = true;
      _message = msg;
      _currentPin = "";
    });
  }

  Future<void> _askBiometrics() async {
    final allow = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Биометрия'),
        content: const Text('Использовать FaceID / отпечаток для быстрого входа?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Нет')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Да')),
        ],
      ),
    );
    if (allow == true) await SecurityService.setBiometricsEnabled(true);
  }

  void _onSuccess() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => MainNavigationPage(
          userId: widget.userId ?? 0,
          phone: widget.phone ?? "",
          fullName: widget.fullName,
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            const Icon(Icons.lock_outline, size: 40, color: Colors.blue),
            const SizedBox(height: 16),
            Text(
              _message,
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold,
                color: _isError ? Colors.red : Colors.black,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final filled = index < _currentPin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 14, height: 14,
                  decoration: BoxDecoration(
                    color: filled ? (_isError ? Colors.red : Colors.blue) : Colors.grey.shade300,
                    shape: BoxShape.circle,
                  ),
                );
              }),
            ),
            const Spacer(),
            _buildKeyboard(),
            const SizedBox(height: 30),
            if (widget.mode == PinMode.auth)
              TextButton(
                onPressed: () async {
                  await SecurityService.clear();
                  await ApiClient.logout();
                  if (context.mounted) {
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
                  }
                },
                child: const Text("Сменить аккаунт / Забыли код?"),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyboard() {
    return Column(
      children: [
        for (var row in [['1','2','3'], ['4','5','6'], ['7','8','9']])
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row.map((e) => _numBtn(e)).toList(),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
             // Кнопка биометрии
            SizedBox(width: 72, height: 72, child: widget.mode == PinMode.auth 
              ? IconButton(icon: const Icon(Icons.fingerprint, size: 36, color: Colors.blue), onPressed: _tryBiometrics) 
              : null),
            _numBtn('0'),
            SizedBox(width: 72, height: 72, child: IconButton(icon: const Icon(Icons.backspace_outlined), onPressed: _onDeletePress)),
          ],
        ),
      ],
    );
  }

  Widget _numBtn(String text) {
    return Container(
      margin: const EdgeInsets.all(10),
      width: 72, height: 72,
      child: InkWell(
        borderRadius: BorderRadius.circular(36),
        onTap: () => _onDigitPress(text),
        child: Center(child: Text(text, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w500))),
      ),
    );
  }
}