import 'package:flutter/material.dart';

class ImpostiColors {
  static const Color primary = Color(0xFF0D6EFD);
  static const Color sidebarBg = Color(0xFF212529);
  static const Color bodyBg = Color(0xFFF5F6FA);
  static const Color success = Color(0xFF198754);
  static const Color warning = Color(0xFFFFC107);
  static const Color info = Color(0xFF0DCAF0);
  static const Color danger = Color(0xFFDC3545);
  static const Color secondary = Color(0xFF6C757D);
  static const Color cardBorder = Color(0xFFE9ECEF);

  static Color parseHex(String? hex, {Color fallback = secondary}) {
    if (hex == null || hex.isEmpty) return fallback;
    final cleaned = hex.replaceAll('#', '').trim();
    if (cleaned.length == 6) {
      final val = int.tryParse('FF$cleaned', radix: 16);
      if (val != null) return Color(val);
    }
    return fallback;
  }

  static Color statusColor(String status) {
    switch (status) {
      case 'pending':
        return secondary;
      case 'in_progress':
        return warning;
      case 'completed':
        return success;
      case 'approved':
        return const Color(0xFF17A2B8);
      case 'rejected':
        return danger;
      default:
        return secondary;
    }
  }

  static Color equipmentStatusColor(String status) {
    switch (status) {
      case 'active':
        return success;
      case 'maintenance':
        return warning;
      case 'broken':
        return danger;
      case 'inactive':
      default:
        return secondary;
    }
  }

  static String statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'მოლოდინში';
      case 'in_progress':
        return 'მიმდინარე';
      case 'completed':
        return 'დასრულებული';
      case 'approved':
        return 'დამტკიცებული';
      case 'rejected':
        return 'უარყოფილი';
      default:
        return status;
    }
  }

  static String equipmentStatusLabel(String status) {
    switch (status) {
      case 'active':
        return 'აქტიური';
      case 'inactive':
        return 'არააქტიური';
      case 'maintenance':
        return 'მომსახურებაში';
      case 'broken':
        return 'გაფუჭებული';
      default:
        return status;
    }
  }

  static IconData bootstrapIcon(String? iconName) {
    switch (iconName) {
      case 'bi-fan':
        return Icons.mode_fan_off_outlined;
      case 'bi-snow':
        return Icons.ac_unit;
      case 'bi-fire':
        return Icons.local_fire_department;
      case 'bi-wind':
        return Icons.air;
      case 'bi-thermometer':
        return Icons.thermostat;
      case 'bi-lightning':
        return Icons.bolt;
      case 'bi-droplet':
        return Icons.water_drop;
      case 'bi-gear':
      default:
        return Icons.settings;
    }
  }
}

ThemeData buildImpostiTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: ImpostiColors.bodyBg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: ImpostiColors.primary,
      primary: ImpostiColors.primary,
      secondary: ImpostiColors.info,
      error: ImpostiColors.danger,
      surface: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: ImpostiColors.sidebarBg,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFDEE2E6)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFDEE2E6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: ImpostiColors.primary, width: 1.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: ImpostiColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
  );
}
