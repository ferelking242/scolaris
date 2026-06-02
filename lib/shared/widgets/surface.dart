import 'package:flutter/material.dart';

/// Scolaris surface — décoration de cartes avec profondeur 3D bien visible.
///
/// Fond cible : #EDD8BE (beige moyen-foncé) → cartes blanches contrastent bien.
/// Bordures sombres, ombres fortes → "vrais bords" visibles à l'écran.
class ScolarisSurface {
  ScolarisSurface._();

  // Palette interne
  static const _shadow = Color(0xFF3E1A00);  // brun très foncé
  static const _terra  = Color(0xFF8B1A00);
  static const _border = Color(0xFFB8946A);  // bordure beige-brun bien visible

  // ── CARTE PRINCIPALE ──────────────────────────────────────────────────
  /// Blanc pur + bordure visible + ombre profonde.
  /// Le fond de l'app DOIT être ≤ #EDD8BE pour que le blanc ressorte.
  static BoxDecoration card({double radius = 16, Color? borderColor}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? _border, width: 1.5),
      boxShadow: [
        // Ombre principale
        BoxShadow(
          color: _shadow.withOpacity(0.25),
          blurRadius: 18,
          offset: const Offset(0, 7),
          spreadRadius: -3,
        ),
        // Contact
        BoxShadow(
          color: _terra.withOpacity(0.10),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  // ── CARTE ACCENT ──────────────────────────────────────────────────────
  /// Teinte colorée plus visible + bordure colorée marquée.
  static BoxDecoration accent({required Color color, double radius = 14}) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Color.lerp(Colors.white, color, 0.14)!,
          Color.lerp(Colors.white, color, 0.26)!,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: color.withOpacity(0.45), width: 1.5),
      boxShadow: [
        BoxShadow(
          color: color.withOpacity(0.22),
          blurRadius: 14,
          offset: const Offset(0, 5),
          spreadRadius: -2,
        ),
      ],
    );
  }

  // ── CARTE SUBTLE ─────────────────────────────────────────────────────
  /// Item secondaire dans liste — fond légèrement teinté, bordure visible.
  static BoxDecoration subtle({double radius = 12}) {
    return BoxDecoration(
      color: const Color(0xFFFDF8F2),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: const Color(0xFFCBB08A), width: 1.2),
      boxShadow: [
        BoxShadow(
          color: _shadow.withOpacity(0.12),
          blurRadius: 8,
          offset: const Offset(0, 3),
          spreadRadius: -1,
        ),
      ],
    );
  }

  // ── INNER ────────────────────────────────────────────────────────────
  /// Container intérieur (fond teinté, bordure fine, pas d'ombre).
  static BoxDecoration inner({double radius = 10}) {
    return BoxDecoration(
      color: const Color(0xFFEEE0CC),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: const Color(0xFFCBB08A), width: 1),
    );
  }
}
