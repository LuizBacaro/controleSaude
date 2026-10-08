import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/auth/domain/app_user.dart';
import '../features/exams/data/exams_repository.dart';
import '../features/exams/domain/exam_report.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'SharedPreferences deve ser sobrescrito no bootstrap.',
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final repo = AuthRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

/// Sessão atual — atualizado via [authRevisionProvider] após login/logout.
final authRevisionProvider = NotifierProvider<AuthRevision, int>(
  AuthRevision.new,
);

class AuthRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final currentUserProvider = Provider<AppUser?>((ref) {
  ref.watch(authRevisionProvider);
  return ref.watch(authRepositoryProvider).currentUser;
});

final examsRepositoryProvider = Provider<ExamsRepository>((ref) {
  return ExamsRepository(prefs: ref.watch(sharedPreferencesProvider));
});

final examsRevisionProvider = NotifierProvider<ExamsRevision, int>(
  ExamsRevision.new,
);

class ExamsRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final examReportsProvider = Provider<List<ExamReport>>((ref) {
  ref.watch(examsRevisionProvider);
  return ref.watch(examsRepositoryProvider).reports;
});

final dashboardSummaryProvider = Provider((ref) {
  ref.watch(examsRevisionProvider);
  return ref.watch(examsRepositoryProvider).summary();
});

final markerSeriesProvider = Provider((ref) {
  ref.watch(examsRevisionProvider);
  return ref.watch(examsRepositoryProvider).buildSeries();
});

final hasExamsProvider = Provider<bool>((ref) {
  ref.watch(examsRevisionProvider);
  return ref.watch(examsRepositoryProvider).hasReports;
});
