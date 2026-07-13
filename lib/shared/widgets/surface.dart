import 'package:flutter/material.dart';

/// Scolaris surface — décorations de cartes adaptatives au thème.
class ScolarisSurface {
  ScolarisSurface._();

  static const _shadow = Color(0xFF3E1A00);
  static const _terra  = Color(0xFF8B1A00);
  static const _border = Color(0xFFB8946A);

  // ── CARTE PRINCIPALE (legacy — fond beige) ──────────────────────────────
  /// Blanc pur avec bordure visible. Utiliser [themedCard] pour les nouvelles
  /// pages afin de respecter le thème sombre.
  static BoxDecoration card({double radius = 16, Color? borderColor}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? _border, width: 1.5),
      boxShadow: [
        BoxShadow(
          color: _shadow.withOpacity(0.25),
          blurRadius: 18,
          offset: const Offset(0, 7),
          spreadRadius: -3,
        ),
        BoxShadow(
          color: _terra.withOpacity(0.10),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  // ── CARTE ADAPTATIVE AU THÈME ────────────────────────────────────────────
  /// Utilise les tokens du thème courant (clair / sombre / navy).
  static BoxDecoration themedCard(BuildContext context,
      {double radius = 16, Color? borderColor}) {
    final cs = Theme.of(context).colorScheme;
    return BoxDecoration(
      color: cs.surfaceContainer,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
          color: borderColor ?? cs.outline.withOpacity(.3), width: 1),
      boxShadow: [
        BoxShadow(
          color: cs.shadow.withOpacity(.06),
          blurRadius: 14,
          offset: const Offset(0, 4),
          spreadRadius: -2,
        ),
      ],
    );
  }

  // ── CARTE ACCENT ─────────────────────────────────────────────────────────
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

  // ── CARTE ACCENT ADAPTATIVE AU THÈME ─────────────────────────────────────
  /// Même rôle que [accent] (carte teintée d'une couleur de marque) mais le
  /// fond est dérivé de la surface du thème, pas du blanc → lisible en sombre.
  static BoxDecoration themedAccent(BuildContext context,
      {required Color color, double radius = 14}) {
    final cs = Theme.of(context).colorScheme;
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Color.lerp(cs.surfaceContainer, color, 0.10)!,
          Color.lerp(cs.surfaceContainer, color, 0.20)!,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: color.withOpacity(0.45), width: 1.5),
      boxShadow: [
        BoxShadow(
          color: color.withOpacity(0.18),
          blurRadius: 14,
          offset: const Offset(0, 5),
          spreadRadius: -2,
        ),
      ],
    );
  }

  // ── SUBTLE ────────────────────────────────────────────────────────────────
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

  // ── INNER ─────────────────────────────────────────────────────────────────
  static BoxDecoration inner({double radius = 10}) {
    return BoxDecoration(
      color: const Color(0xFFEEE0CC),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: const Color(0xFFCBB08A), width: 1),
    );
  }
}
