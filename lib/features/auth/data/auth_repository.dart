import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../domain/app_user.dart';

const _sessionKey = 'controle_saude_session';
const _usersKey = 'controle_saude_users';

class AuthRepository extends ChangeNotifier {
  AuthRepository({
    required this.prefs,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final SharedPreferences prefs;
  final Uuid _uuid;

  AppUser? _currentUser;
  final Map<String, _StoredUser> _users = {};

  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  Future<void> load() async {
    final usersRaw = prefs.getString(_usersKey);
    if (usersRaw != null && usersRaw.isNotEmpty) {
      final map = jsonDecode(usersRaw) as Map<String, dynamic>;
      for (final entry in map.entries) {
        final data = entry.value as Map<String, dynamic>;
        _users[entry.key] = _StoredUser(
          user: AppUser.fromJson(data['user'] as Map<String, dynamic>),
          password: data['password'] as String,
        );
      }
    }

    final sessionId = prefs.getString(_sessionKey);
    if (sessionId != null && _users.containsKey(sessionId)) {
      _currentUser = _users[sessionId]!.user;
    }
    notifyListeners();
  }

  Future<void> _persistUsers() async {
    final map = <String, dynamic>{};
    for (final entry in _users.entries) {
      map[entry.key] = {
        'user': entry.value.user.toJson(),
        'password': entry.value.password,
      };
    }
    await prefs.setString(_usersKey, jsonEncode(map));
  }

  Future<AppUser> register({
    required String email,
    required String password,
    required String displayName,
    DateTime? birthDate,
    String? sex,
  }) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty || password.length < 4) {
      throw Exception('Informe e-mail e senha com pelo menos 4 caracteres.');
    }
    if (_users.values.any((u) => u.user.email == normalized)) {
      throw Exception('Já existe uma conta com este e-mail.');
    }

    final user = AppUser(
      id: _uuid.v4(),
      email: normalized,
      displayName: displayName.trim().isEmpty
          ? normalized.split('@').first
          : displayName.trim(),
      birthDate: birthDate,
      sex: sex,
    );
    _users[user.id] = _StoredUser(user: user, password: password);
    await _persistUsers();
    await prefs.setString(_sessionKey, user.id);
    _currentUser = user;
    notifyListeners();
    return user;
  }

  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    final normalized = email.trim().toLowerCase();
    _StoredUser? match;
    for (final stored in _users.values) {
      if (stored.user.email == normalized && stored.password == password) {
        match = stored;
        break;
      }
    }
    if (match == null) {
      throw Exception('E-mail ou senha inválidos.');
    }
    await prefs.setString(_sessionKey, match.user.id);
    _currentUser = match.user;
    notifyListeners();
    return match.user;
  }

  Future<void> logout() async {
    await prefs.remove(_sessionKey);
    _currentUser = null;
    notifyListeners();
  }
}

class _StoredUser {
  const _StoredUser({required this.user, required this.password});
  final AppUser user;
  final String password;
}
