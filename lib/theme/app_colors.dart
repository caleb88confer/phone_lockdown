import 'package:flutter/material.dart';

class AppColors {
  // Primary
  static const primary = Color(0xFF7C5800);
  static const primaryContainer = Color(0xFFFFB800); // Signature Gold
  static const primaryFixed = Color(0xFFFFDEA8);
  static const onPrimaryContainer = Color(0xFF6B4C00);

  // Secondary (Red — errors/destructive)
  static const secondary = Color(0xFFB02D28);

  // Tertiary (Blue — info/secondary interactive)
  static const tertiary = Color(0xFF005BBE);
  static const tertiaryContainer = Color(0xFFA9C5FF);

  // Surfaces (tonal nesting)
  static const surface = Color(0xFFFBF9F2);
  static const surfaceContainerLow = Color(0xFFF6F4EC);
  static const surfaceContainerHigh = Color(0xFFEAE8E1);
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const onSurface = Color(0xFF1B1C18);

  // Outline
  static const outline = Color(0xFF837560);
  static const outlineVariant = Color(0xFFD5C4AB);

  // App-specific backgrounds
  static const blockingBackground = Color(0xFF3D1111);
  static const nonBlockingBackground = Color(0xFF1A1E2C);
}
