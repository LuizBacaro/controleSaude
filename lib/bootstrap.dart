import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/providers.dart';

Future<ProviderContainer> bootstrap() async {
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );

  await container.read(authRepositoryProvider).load();
  await container.read(examsRepositoryProvider).load();
  return container;
}
