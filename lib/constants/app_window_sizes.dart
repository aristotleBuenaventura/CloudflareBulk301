import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Minimum window sizes per screen. Matches the smallest usable layout —
/// the window cannot be resized smaller than these values.
abstract final class AppWindowSizes {
  /// Login card (480) + horizontal padding (32×2) + frame margin.
  static const login = Size(560, 712);

  /// Bulk redirect side-by-side layout at minimum height.
  static const bulk = Size(900, 712);

  static Future<void> applyLoginMinimum() async {
    await windowManager.setMinimumSize(login);
  }

  static Future<void> applyBulkMinimum() async {
    await windowManager.setMinimumSize(bulk);
  }
}
