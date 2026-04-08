import 'package:flutter/foundation.dart';

class AppLogger {
  static const _prefix = 'PhoneLockdown';

  static void d(String tag, String msg) => debugPrint('[$_prefix/$tag] $msg');
  static void w(String tag, String msg) =>
      debugPrint('[$_prefix/$tag] WARNING: $msg');
  static void e(String tag, String msg, [Object? error]) {
    debugPrint(
        '[$_prefix/$tag] ERROR: $msg${error != null ? ' ($error)' : ''}');
  }
}
