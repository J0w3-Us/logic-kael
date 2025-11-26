import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'screens/home/home_screen.dart';
import 'screens/home/providers/settings_config_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load .env if present and initialize Supabase if keys available
  try {
    await dotenv.load();
  } catch (e) {
    debugPrint('⚠️ .env load failed: $e');
  }

  // Try to initialize Supabase if env variables available. If not,
  // continue running in local-only mode.
  try {
    final url = dotenv.env['SUPABASE_URL'];
    final anon = dotenv.env['SUPABASE_ANON_KEY'];
    if (url != null && anon != null && url.isNotEmpty && anon.isNotEmpty) {
      await Supabase.initialize(url: url, anonKey: anon);
      debugPrint('✅ Supabase initialized');
    } else {
      debugPrint('⚠️ Supabase env vars missing; running in local mode');
    }
  } catch (e) {
    debugPrint('⚠️ Supabase initialization failed: $e');
  }
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(
    ChangeNotifierProvider(
      create: (_) => SettingsConfigProvider(),
      child: const MaterialApp(
        home: HomeScreen(),
        debugShowCheckedModeBanner: false,
      ),
    ),
  );
}
