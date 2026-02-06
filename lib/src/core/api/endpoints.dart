class Endpoints {
  static const String baseUrl = "https://api.intelvt.kz/api/mobile";
  static const String baseUrlAgora = "https://api.intelvt.kz/api/agora";

  // Auth Endpoints
  static const String register = "/register";
  static const String login = "/login";
  static const String refreshToken = "/refresh-token";
  static const String verifyCode = "/verify-code";
  static const String sendCode = "/send-code";
  static const String deleteAccount = "/delete-account";
  static const String resetPassword = "/reset-password";

  // Home and etc.
  static const String updateName = "update-name";  
  static const String updateSoldierName = "update-soldier-name";  
  static const String changePassword = "change-password";  
  static const String parentDashboard = "parent-dashboard";  
  static const String endCall = "endCall";  
  static const String notifications = "notifications";  

  // Agora
  static const String getRtcToken = "/rtc-token";  
}