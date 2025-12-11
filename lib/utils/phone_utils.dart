class PhoneUtils {
  /// Нормализуем номер Казахстана к формату +7XXXXXXXXXX
  /// Примеры:
  ///  - "8 701 123 45 67"  -> "+77011234567"
  ///  - "+7 (701) 123-45-67" -> "+77011234567"
  ///  - "7011234567" -> "+77011234567"
  static String normalizeKzPhone(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');

    if (digits.isEmpty) {
      throw const FormatException('Пустой номер телефона');
    }

    String normalizedDigits;

    if (digits.length == 11 && digits.startsWith('7')) {
      // уже в виде 7XXXXXXXXXX
      normalizedDigits = digits;
    } else if (digits.length == 11 && digits.startsWith('8')) {
      // 8XXXXXXXXXXX -> 7XXXXXXXXXXX
      normalizedDigits = '7${digits.substring(1)}';
    } else if (digits.length == 10) {
      // без первой 7, считаем что это 7ХХХХХХХХХ
      normalizedDigits = '7$digits';
    } else {
      throw const FormatException('Некорректная длина номера');
    }

    return '+$normalizedDigits';
  }
}