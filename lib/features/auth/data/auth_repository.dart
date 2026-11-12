import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../domain/app_user.dart';
import 'password_reset.dart';

class AuthRepository extends ChangeNotifier {
  AuthRepository({SupabaseClient? client, this._appLinks})
    : _client = client ?? Supabase.instance.client {
    _authSub = _client.auth.onAuthStateChange.listen((state) {
      if (state.event != AuthChangeEvent.passwordRecovery) return;
      _recoveryPending = true;
      _recoveryError = null;
      notifyListeners();
    });
  }

  final SupabaseClient _client;
  final AppLinks? _appLinks;
  StreamSubscription<AuthState>? _authSub;

  AppUser? _currentUser;
  var _recoveryPending = false;
  String? _recoveryError;

  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  /// A pessoa abriu o link do e-mail e ainda precisa escolher a senha nova.
  bool get recoveryPending => _recoveryPending;

  String? get recoveryError => _recoveryError;

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
    required String role,
    DateTime? birthDate,
    String? sex,
    String? crmUf,
    String? crmNumber,
  }) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty || !normalized.contains('@')) {
      throw AppException('Informe um e-mail válido.');
    }
    if (password.length < 6) {
      throw AppException('A senha precisa ter pelo menos 6 caracteres.');
    }

    final name = displayName.trim().isEmpty
        ? normalized.split('@').first
        : displayName.trim();

    try {
      final response = await _call(
        () => _client.auth.signUp(
          email: normalized,
          password: password,
          data: {
            'display_name': name,
            'role': role == 'doctor' ? 'doctor' : 'patient',
            if (sex != null && sex.isNotEmpty) 'sex': sex,
            if (birthDate != null) 'birth_date': _isoDate(birthDate),
            if (role == 'doctor' && crmUf != null) 'crm_uf': crmUf,
            if (role == 'doctor' && crmNumber != null) 'crm_number': crmNumber,
          },
        ),
      );
      final user = response.user;
      if (user == null || response.session == null) {
        throw AppException(
          'Conta criada. Abra o e-mail que enviamos, toque em confirmar e volte aqui para entrar.',
        );
      }
      if (birthDate != null) {
        await _call(
          () => _client
              .from('profiles')
              .update({'birth_date': _isoDate(birthDate)})
              .eq('id', user.id),
        );
      }
      _currentUser = await _call(() => _profileFor(user));
      notifyListeners();
      return _currentUser!;
    } on AppException {
      rethrow;
    } catch (error) {
      if (role == 'doctor' &&
          error is AuthException &&
          error.message.toLowerCase().contains('database')) {
        throw AppException(
          'Não foi possível criar a conta. Confira o CRM; ele pode já estar em uso.',
        );
      }
      throw AppException.from(
        error,
        fallback: 'Não foi possível criar a conta. Tente de novo.',
      );
    }
  }

  /// Pede o e-mail com o link para escolher outra senha.
  ///
  /// Se o e-mail não tiver conta, a chamada termina do mesmo jeito. A tela
  /// não conta se o endereço existe.
  Future<void> requestPasswordReset(String email) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty || !normalized.contains('@')) {
      throw AppException('Informe um e-mail válido.');
    }
    _recoveryError = null;
    try {
      await _call(
        () => _client.auth.resetPasswordForEmail(
          normalized,
          redirectTo: passwordResetRedirect(
            web: kIsWeb,
            webOrigin: Uri.base.origin,
          ),
        ),
      );
    } on AuthException catch (error) {
      final lower = error.message.toLowerCase();
      if (lower.contains('not found') || lower.contains('does not exist')) {
        return;
      }
      throw AppException.from(
        error,
        fallback: 'Não foi possível enviar o e-mail. Tente de novo.',
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException.from(
        error,
        fallback: 'Não foi possível enviar o e-mail. Tente de novo.',
      );
    }
  }

  /// Troca a senha da sessão aberta pelo link do e-mail.
  Future<void> updatePassword(String password) async {
    if (password.length < 6) {
      throw AppException('A senha precisa ter pelo menos 6 caracteres.');
    }
    if (_client.auth.currentSession == null) {
      throw AppException('Este link expirou. Peça outro na tela de entrar.');
    }
    try {
      await _call(
        () => _client.auth.updateUser(UserAttributes(password: password)),
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException.from(
        error,
        fallback: 'Não foi possível salvar a senha. Tente de novo.',
      );
    }
    _recoveryPending = false;
    _recoveryError = null;
    final user = _client.auth.currentUser;
    if (user != null) {
      try {
        _currentUser = await _call(() => _profileFor(user));
      } catch (_) {
        _currentUser = _userFromMetadata(user);
      }
    }
    notifyListeners();
  }

  /// O link de recuperação já foi trocado por sessão, ou falhou ao abrir.
  ///
  /// No navegador o Supabase consome o código antes desta chamada. No celular
  /// o endereço inicial continua disponível. Nos dois casos a rota
  /// [passwordResetPath] marca que a senha nova ainda não foi escolhida.
  Future<void> captureRecoveryFromLaunch() async {
    final uri = kIsWeb
        ? Uri.base
        : await (_appLinks ?? AppLinks()).getInitialLink();
    if (uri == null || !isPasswordRecoveryUri(uri)) return;
    if (_client.auth.currentSession != null) {
      _recoveryPending = true;
      _recoveryError = null;
      notifyListeners();
      return;
    }
    final params = {
      ...uri.queryParameters,
      ...Uri.splitQueryString(uri.fragment),
    };
    final description = params['error_description'] ?? params['error'];
    _recoveryError = description == null
        ? 'Abra o link no mesmo aparelho em que pediu a nova senha.'
        : AppException.messageOf(AuthException(description));
    notifyListeners();
  }

  void clearRecoveryError() {
    if (_recoveryError == null) return;
    _recoveryError = null;
    notifyListeners();
  }

  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    final normalized = email.trim().toLowerCase();
    _recoveryPending = false;
    _recoveryError = null;
    try {
      final response = await _call(
        () => _client.auth.signInWithPassword(
          email: normalized,
          password: password,
        ),
      );
      final user = response.user;
      if (user == null) {
        throw AppException('E-mail ou senha não conferem.');
      }
      _currentUser = await _call(() => _profileFor(user));
      notifyListeners();
      return _currentUser!;
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException.from(
        error,
        fallback: 'Não foi possível entrar. Tente de novo.',
      );
    }
  }

  /// Completa sexo e data de nascimento, usados nas faixas de referência.
  Future<AppUser> updateHealthProfile({
    required DateTime birthDate,
    required String sex,
  }) async {
    final user = _client.auth.currentUser;
    final current = _currentUser;
    if (user == null || current == null) {
      throw AppException('Entre na conta para salvar o perfil.');
    }
    try {
      await _call(
        () => _client
            .from('profiles')
            .update({'birth_date': _isoDate(birthDate), 'sex': sex})
            .eq('id', user.id),
      );
      await _call(
        () => _client.auth.updateUser(
          UserAttributes(data: {'birth_date': _isoDate(birthDate), 'sex': sex}),
        ),
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException.from(
        error,
        fallback: 'Não foi possível salvar os dados. Tente de novo.',
      );
    }
    _currentUser = current.copyWith(birthDate: birthDate, sex: sex);
    notifyListeners();
    return _currentUser!;
  }

  String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Future<void> logout() async {
    _recoveryPending = false;
    _recoveryError = null;
    await _client.auth.signOut();
    _currentUser = null;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_authSub?.cancel());
    super.dispose();
  }

  Future<AppUser> _profileFor(User user) async {
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    final meta = user.userMetadata ?? const <String, dynamic>{};
    final metaBirth = DateTime.tryParse(meta['birth_date'] as String? ?? '');
    if (row == null) return _userFromMetadata(user);
    final profile = AppUser.fromJson(Map<String, dynamic>.from(row));
    return AppUser(
      id: profile.id,
      email: profile.email,
      displayName: profile.displayName,
      birthDate: profile.birthDate ?? metaBirth,
      sex: profile.sex ?? meta['sex'] as String?,
      role: profile.role,
      crmUf: profile.crmUf,
      crmNumber: profile.crmNumber,
    );
  }

  AppUser _userFromMetadata(User user) {
    final meta = user.userMetadata ?? const <String, dynamic>{};
    return AppUser(
      id: user.id,
      email: user.email ?? '',
      displayName:
          meta['display_name'] as String? ??
          (user.email ?? '').split('@').first,
      sex: meta['sex'] as String?,
      birthDate: DateTime.tryParse(meta['birth_date'] as String? ?? ''),
      role: meta['role'] == 'doctor' ? 'doctor' : 'patient',
      crmUf: meta['crm_uf'] as String?,
      crmNumber: meta['crm_number'] as String?,
    );
  }

  /// Repete só falha de rede. O DNS do celular, logo depois de instalar,
  /// às vezes responde vazio na primeira consulta e acerta na seguinte.
  Future<T> _call<T>(Future<T> Function() action) async {
    var attempt = 0;
    while (true) {
      try {
        return await action();
      } catch (error) {
        attempt++;
        if (attempt >= 3 || !AppException.isTransientNetwork(error)) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
      }
    }
  }
}
