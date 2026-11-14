import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config/app_config.dart';
import 'features/auth/data/auth_repository.dart';

/// Entry point.
///
/// White-label values are injected with `--dart-define`, e.g.:
///   flutter run --dart-define=APP_NAME="Kopi Kenangan" \
///               --dart-define=APP_ID=com.serve.kopikenangan \
///               --dart-define=SUPABASE_URL=https://xyz.supabase.co \
///               --dart-define=SUPABASE_ANON_KEY=sb_publishable_... \
///               --dart-define=PRIMARY_COLOR=#6F4E37
///
/// See docs/WHITE_LABEL.md for the full table of supported defines.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  await Supabase.initialize(
    url: config.supabaseUrl,
    publishableKey: config.supabaseAnonKey,
  );
  runApp(CafeApp(config: config, auth: AuthRepository()));
}
