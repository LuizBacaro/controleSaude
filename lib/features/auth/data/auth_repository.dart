import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/app_user.dart';

class AuthRepository extends ChangeNotifier {
  AuthRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  AppUser? _currentUser;

  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  Future<void> load() async {
    final session = _client.auth.currentSession;
    if (session == null) {
      _currentUser = null;
      notifyListeners();
      return;
    }
    _currentUser = await _profileFor(session.user);
    notifyListeners();
  }

  Future<AppUser> register({
    required String email,
    required String password,
    required String displayName,
    DateTime? birthDate,
    String? sex,
  }) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty || !normalized.contains('@')) {
      throw Exception('Informe um e-mail válido.');
    }
    if (password.length < 6) {
      throw Exception('A senha precisa ter pelo menos 6 caracteres.');
    }

    final name = displayName.trim().isEmpty
        ? normalized.split('@').first
        : displayName.trim();

    try {
      final response = await _client.auth.signUp(
        email: normalized,
        password: password,
        data: {
          'display_name': name,
          if (sex != null && sex.isNotEmpty) 'sex': sex,
        },
      );
      final user = response.user;
      if (user == null || response.session == null) {
        throw Exception(
          'Conta criada. Confirme o e-mail enviado pelo Supabase e depois entre.',
        );
      }
      _currentUser = await _profileFor(user);
      notifyListeners();
      return _currentUser!;
    } on AuthException catch (error) {
      throw Exception(_authMessage(error.message));
    }
  }

  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    final normalized = email.trim().toLowerCase();
    try {
      final response = await _client.auth.signInWithPassword(
        email: normalized,
        password: password,
      );
      final user = response.user;
      if (user == null) {
        throw Exception('E-mail ou senha inválidos.');
      }
      _currentUser = await _profileFor(user);
      notifyListeners();
      return _currentUser!;
    } on AuthException catch (error) {
      throw Exception(_authMessage(error.message));
    }
  }

  Future<void> logout() async {
    await _client.auth.signOut();
    _currentUser = null;
    notifyListeners();
  }

  Future<AppUser> _profileFor(User user) async {
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    if (row == null) {
      final meta = user.userMetadata ?? const <String, dynamic>{};
      return AppUser(
        id: user.id,
        email: user.email ?? '',
        displayName:
            meta['display_name'] as String? ??
            (user.email ?? '').split('@').first,
        sex: meta['sex'] as String?,
      );
    }
    return AppUser.fromJson(Map<String, dynamic>.from(row));
  }

  String _authMessage(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('already registered') ||
        lower.contains('already been registered')) {
      return 'Já existe uma conta com este e-mail. Entre com a senha.';
    }
    if (lower.contains('invalid login') ||
        lower.contains('invalid credentials')) {
      return 'E-mail ou senha inválidos.';
    }
    if (lower.contains('password') && lower.contains('6')) {
      return 'A senha precisa ter pelo menos 6 caracteres.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Confirme o e-mail antes de entrar.';
    }
    return message;
  }
}
