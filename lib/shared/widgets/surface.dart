import 'package:flutter/material.dart';

/// Scolaris surface — helpers pour les decorations de cartes avec profondeur 3D.
///
/// Tous les dashboards utilisent ces helpers au lieu d'un `color: Colors.white` plat.
class ScolarisSurface {
  ScolarisSurface._();

  static const _bgBase   = Color(0xFFF5EEE6);
  static const _inkLight = Color(0xFF3E1A00);
  static const _terra    = Color(0xFF8B1A00);

  /// Carte standard — flotte au-dessus du fond beige avec ombre chaude 3D.
  static BoxDecoration card({
    double radius = 16,
    Color? borderColor,
  }) {
    return BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFFFFFFF), Color(0xFFFBF5EE)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? const Color(0xFFEDE0CE), width: 1),
      boxShadow: [
        BoxShadow(
          color: _inkLight.withOpacity(0.10),
          blurRadius: 22,
          offset: const Offset(0, 8),
          spreadRadius: -4,
        ),
        BoxShadow(
          color: _terra.withOpacity(0.05),
          blurRadius: 5,
          offset: const Offset(0, 2),
          spreadRadius: 0,
        ),
        BoxShadow(
          color: Colors.white.withOpacity(0.90),
          blurRadius: 0,
          offset: const Offset(0, -1),
          spreadRadius: 0,
        ),
      ],
    );
  }

  /// Carte avec teinte d'accent — pour les stat pills colorés.
  static BoxDecoration accent({
    required Color color,
    double radius = 14,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Color.lerp(Colors.white, color, 0.06)!,
          Color.lerp(Colors.white, color, 0.12)!,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: color.withOpacity(0.20), width: 1),
      boxShadow: [
        BoxShadow(
          color: color.withOpacity(0.18),
          blurRadius: 18,
          offset: const Offset(0, 6),
          spreadRadius: -3,
        ),
        BoxShadow(
          color: color.withOpacity(0.06),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ],
    );
  }

  /// Carte enfoncée légèrement — pour les éléments de liste secondaires.
  static BoxDecoration subtle({double radius = 12}) {
    return BoxDecoration(
      color: const Color(0xFFFEFBF8),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: const Color(0xFFEEE5D8), width: 1),
      boxShadow: [
        BoxShadow(
          color: _inkLight.withOpacity(0.06),
          blurRadius: 10,
          offset: const Offset(0, 4),
          spreadRadius: -2,
        ),
      ],
    );
  }

  /// Section/container de fond — légèrement plus clair que le bg.
  static BoxDecoration inner({double radius = 10}) {
    return BoxDecoration(
      color: const Color(0xFFF7F0E8),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: const Color(0xFFE8DCCF), width: 1),
    );
  }
}
