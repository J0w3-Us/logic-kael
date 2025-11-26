// Game API client that talks to Supabase and exposes level loading and RPCs
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flame/components.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Shared small API to avoid circular imports between game and components.
enum GameState { playing, won, intro, gameOver }

abstract class GameApi {
  GameState get gameState;
  double get groundHeight;
  Vector2 get size;
  void onPlayerDied();
}

class GameApiClient {
  GameApiClient._();

  /// Ensure Supabase is initialized. Returns true when ready.
  static Future<bool> _ensureInitialized() async {
    try {
      // If Supabase was initialized in main.dart this is a no-op.
      Supabase.instance.client;
      return true;
    } catch (_) {
      // Try to initialize from dotenv (if not already loaded). If load
      // throws because dotenv was already loaded, ignore that — we still
      // try to read values from `dotenv.env`.
      try {
        await dotenv.load();
      } catch (_) {
        // ignore: avoid_print
        print('dotenv could not be loaded or already loaded');
      }

      try {
        final url = dotenv.env['SUPABASE_URL'];
        final anon = dotenv.env['SUPABASE_ANON_KEY'];
        if (url != null && anon != null && url.isNotEmpty && anon.isNotEmpty) {
          await Supabase.initialize(url: url, anonKey: anon);
          debugPrint('✅ Supabase initialized from GameApiClient');
          return true;
        } else {
          debugPrint('⚠️ Supabase env vars missing in GameApiClient');
          return false;
        }
      } catch (e, st) {
        debugPrint('⚠️ Supabase initialization failed in GameApiClient: $e');
        debugPrint('$st');
        return false;
      }
    }
  }

  static SupabaseClient get _client => Supabase.instance.client;

  /// Load level data from table `NivelesConfig`, selecting `configuracion_nivel`.
  /// Returns the `obstaculos` list from the JSON or an empty list on error.
  static Future<List<dynamic>> loadLevelData(int levelId) async {
    try {
      final ok = await _ensureInitialized();
      if (!ok) {
        debugPrint('⚠️ Supabase not initialized; returning empty level data');
        return [];
      }

      final resp = await _client
          .from('NivelesConfig')
          .select('configuracion_nivel')
          .eq('nivel_id', levelId)
          .maybeSingle();

      if (resp == null) {
        debugPrint('⚠️ NivelesConfig: no row for nivel_id=$levelId');
        return [];
      }

      dynamic config = resp;
      if (config is Map && config.containsKey('configuracion_nivel')) {
        config = config['configuracion_nivel'];
      }

      if (config is String) {
        try {
          config = json.decode(config);
        } catch (e) {
          debugPrint('⚠️ Failed to decode configuracion_nivel JSON: $e');
          return [];
        }
      }

      if (config is Map &&
          config.containsKey('obstaculos') &&
          config['obstaculos'] is List) {
        final List<dynamic> obstacles = List<dynamic>.from(
          config['obstaculos'] as List,
        );
        debugPrint(
          '✅ loadLevelData: loaded ${obstacles.length} obstacles for level $levelId',
        );

        // Log Kaelen asset integration for debugging
        () async {
          try {
            final bd = await rootBundle.load('assets/snippet/Kaelen.png');
            final bytes = bd.buffer.asUint8List();
            final codec = await ui.instantiateImageCodec(bytes);
            final frame = await codec.getNextFrame();
            final image = frame.image;
            debugPrint(
              '🔍 Kaelen asset present: ${image.width}x${image.height}',
            );
          } catch (e) {
            debugPrint('🔍 Kaelen asset missing or failed to decode: $e');
          }
        }();

        return obstacles;
      }

      debugPrint(
        '⚠️ loadLevelData: configuracion_nivel missing or invalid for level $levelId',
      );
      return [];
    } catch (e, st) {
      debugPrint('⚠️ GameApiClient.loadLevelData error: $e');
      debugPrint('$st');
      return [];
    }
  }

  /// Call RPC `registrar_muerte_y_contar` and return the new death count (int) if available.
  static Future<int?> recordDeath() async {
    try {
      final ok = await _ensureInitialized();
      if (!ok) {
        debugPrint('⚠️ Supabase not initialized; skipping recordDeath');
        return null;
      }
      final res = await _client.rpc('registrar_muerte_y_contar');
      if (res is Map && res.containsKey('count')) {
        final val = res['count'];
        if (val is num) return val.toInt();
      }
      if (res is num) return res.toInt();
      debugPrint('⚠️ recordDeath: unexpected RPC result: $res');
      return null;
    } catch (e, st) {
      debugPrint('⚠️ GameApiClient.recordDeath error: $e');
      debugPrint('$st');
      return null;
    }
  }

  /// Call RPC `completar_seccion` with parameter `p_seccion_completada_id`.
  /// Returns the next level id (int) on success or null on failure.
  static Future<int?> completeLevel(int levelId) async {
    try {
      final ok = await _ensureInitialized();
      if (!ok) {
        debugPrint('⚠️ Supabase not initialized; skipping completeLevel');
        return null;
      }
      final res = await _client.rpc(
        'completar_seccion',
        params: {'p_seccion_completada_id': levelId},
      );
      if (res is Map && res.containsKey('next_level')) {
        final v = res['next_level'];
        if (v is num) return v.toInt();
      }
      if (res is num) return res.toInt();
      if (res is Map && res.containsKey('id')) {
        final v = res['id'];
        if (v is num) return v.toInt();
      }
      debugPrint('⚠️ completeLevel: unexpected RPC result: $res');
      return null;
    } catch (e, st) {
      debugPrint('⚠️ GameApiClient.completeLevel error: $e');
      debugPrint('$st');
      return null;
    }
  }
}
