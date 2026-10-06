import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Environment values loaded from the `.env` asset (never committed).
abstract final class Env {
  static String get supabaseUrl => _require('SUPABASE_URL');

  static String get supabaseAnonKey => _require('SUPABASE_ANON_KEY');

  static String _require(String key) {
    final value = dotenv.env[key]?.trim();
    if (value == null ||
        value.isEmpty ||
        value.contains('your-project') ||
        value.endsWith('_xxx')) {
      throw StateError(
        'Missing .env value for "$key". Copy .env.example to .env and fill '
        'in your Supabase project URL and publishable (anon) key.',
      );
    }
    return value;
  }
}
