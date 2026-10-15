import 'package:flutter/foundation.dart';
import '../models/auth_user.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  final ApiService api;
  AuthUser? _user;
  AuthService({ApiService? api}) : api = api ?? ApiService();
  AuthUser? get user => _user;
  bool get isAuthenticated => _user != null;
  Future<void> login(String username, String password) async {
    final data = await api.post('/login', {'username': username.trim(), 'password': password, 'device_name': 'flutter-web'});
    api.setToken(data['access_token'] as String);
    _user = AuthUser.fromJson(Map<String, dynamic>.from(data['user'] as Map));
    notifyListeners();
  }
  Future<void> refreshUser() async { final data = await api.get('/user'); _user = AuthUser.fromJson(Map<String, dynamic>.from(data['user'] as Map)); notifyListeners(); }
  Future<void> logout() async { try { await api.post('/logout', {}); } finally { api.setToken(null); _user = null; notifyListeners(); } }
  @override void dispose() { api.dispose(); super.dispose(); }
}
