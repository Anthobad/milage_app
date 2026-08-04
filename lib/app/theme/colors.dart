import 'package:flutter/material.dart';

/// TripRank color palette.
/// Primary accent is blue. Status colors: green, orange, red.
class AppColors {
  AppColors._();

  // --- Primary ---
  static const Color primary = Color(0xFF2563EB); // Blue
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color primaryDark = Color(0xFF1D4ED8);

  // --- Status ---
  static const Color success = Color(0xFF22C55E); // Green — active driving
  static const Color warning = Color(0xFFF97316); // Orange — warnings
  static const Color error = Color(0xFFEF4444); // Red — errors / critical

  // --- Dark theme surfaces ---
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color surfaceVariantDark = Color(0xFF334155);

  // --- Light theme surfaces ---
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceVariantLight = Color(0xFFF1F5F9);

  // --- Text ---
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF64748B);

  // --- Divider / Border ---
  static const Color dividerDark = Color(0xFF334155);
  static const Color dividerLight = Color(0xFFE2E8F0);
}
