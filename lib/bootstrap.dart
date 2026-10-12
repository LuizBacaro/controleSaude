import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/providers.dart';
import 'core/supabase_config.dart';

/// Conecta o Supabase. A sessão e os laudos entram depois, para a primeira
/// tela não ficar presa na rede.
Future<void> openServices() {
  return Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  );
}

Future<void> loadSession(ProviderContainer container) async {
  try {
    await container.read(authRepositoryProvider).load();
  } catch (_) {}
  try {
    await container.read(examsRepositoryProvider).load();
  } catch (_) {}
  container.read(authRevisionProvider.notifier).bump();
  container.read(examsRevisionProvider.notifier).bump();
}
