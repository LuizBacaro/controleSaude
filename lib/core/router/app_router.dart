import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/profile_page.dart';
import '../../features/auth/presentation/register_page.dart';
import '../../features/auth/presentation/welcome_page.dart';
import '../../features/care/presentation/doctors_page.dart';
import '../../features/care/presentation/office_page.dart';
import '../../features/care/presentation/patient_evolution_page.dart';
import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/dashboard/presentation/evolution_page.dart';
import '../../features/dashboard/presentation/marker_detail_page.dart';
import '../../features/exams/presentation/history_page.dart';
import '../../features/exams/presentation/report_detail_page.dart';
import '../../features/onboarding/presentation/import_exam_page.dart';
import '../providers.dart';
import '../widgets/app_shell.dart';
import 'home_location.dart';

final _rootKey = GlobalKey<NavigatorState>();

final goRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final loggedIn = ref.read(authRepositoryProvider).isLoggedIn;
      final isPublic = loc == '/' || loc == '/entrar' || loc == '/criar-conta';
      final isDoctor =
          ref.read(authRepositoryProvider).currentUser?.isDoctor ?? false;
      final home = homeLocation(
        isDoctor: isDoctor,
        hasExams: ref.read(examsRepositoryProvider).hasReports,
      );

      if (!loggedIn && !isPublic) return '/';
      if (loggedIn && isPublic) return home;
      if (loggedIn && isDoctor && isPatientArea(loc)) return '/consultorio';
      if (loggedIn && !isDoctor && loc.startsWith('/consultorio')) return home;
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const WelcomePage()),
      GoRoute(path: '/entrar', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/criar-conta',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/importar',
        builder: (context, state) {
          final onboarding = state.uri.queryParameters['onboarding'] == '1';
          return ImportExamPage(isOnboarding: onboarding);
        },
      ),
      GoRoute(
        path: '/marcador',
        builder: (context, state) {
          final name = state.uri.queryParameters['nome'] ?? '';
          return MarkerDetailPage(markerName: name);
        },
      ),
      GoRoute(
        path: '/laudo/:id',
        builder: (context, state) =>
            ReportDetailPage(reportId: state.pathParameters['id']!),
      ),
      StatefulShellRoute(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        navigatorContainerBuilder: lazyBranchContainer,
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app',
                builder: (context, state) => const DashboardPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/evolucao',
                builder: (context, state) => const EvolutionPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/historico',
                builder: (context, state) => const HistoryPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/medicos',
                builder: (context, state) => const DoctorsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/perfil',
                builder: (context, state) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/consultorio',
        builder: (context, state) => const OfficePage(),
        routes: [
          GoRoute(
            path: 'paciente/:id',
            builder: (context, state) => PatientEvolutionPage(
              patientId: state.pathParameters['id']!,
              patientName: state.uri.queryParameters['nome'] ?? 'Paciente',
            ),
            routes: [
              GoRoute(
                path: 'marcador',
                builder: (context, state) => GrantedMarkerPage(
                  patientId: state.pathParameters['id']!,
                  markerName: state.uri.queryParameters['nome'] ?? '',
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(this.ref) {
    ref.listen(authRevisionProvider, (_, _) => notifyListeners());
    ref.listen(examsRevisionProvider, (_, _) => notifyListeners());
  }

  final Ref ref;
}
