import 'package:flutter/material.dart';

/// Scolaris surface — décoration de cartes avec profondeur 3D visible.
///
/// Fond de l'app : beige chaud #F0E4D0 (plus sombre → cartes blanches ressortent)
/// Ombres fortes (0.22–0.28) pour un vrai effet de profondeur.
class ScolarisSurface {
  ScolarisSurface._();

  // Palette interne
  static const _shadow  = Color(0xFF3E1A00);   // brun foncé, teinte chaude
  static const _terra   = Color(0xFF8B1A00);
  static const _border  = Color(0xFFE2CEBA);   // bordure beige foncée, visible

  /// Carte principale : blanc pur avec ombre chaude profonde.
  ///
  /// IMPORTANT : fond app doit être ≤ #F0E4D0 pour que la carte blanche ressorte.
  static BoxDecoration card({double radius = 16, Color? borderColor}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? _border, width: 1),
      boxShadow: [
        // Ombre principale — profondeur
        BoxShadow(
          color: _shadow.withOpacity(0.22),
          blurRadius: 20,
          offset: const Offset(0, 8),
          spreadRadius: -4,
        ),
        // Ombre secondaire — contact
        BoxShadow(
          color: _terra.withOpacity(0.10),
          blurRadius: 6,
          offset: const Offset(0, 2),
          spreadRadius: 0,
        ),
        // Reflet top — effet "levé"
        const BoxShadow(
          color: Colors.white,
          blurRadius: 0,
          offset: Offset(0, -1),
          spreadRadius: 0,
        ),
      ],
    );
  }

  /// Carte avec teinte de couleur — stat pills colorés.
  static BoxDecoration accent({required Color color, double radius = 14}) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Color.lerp(Colors.white, color, 0.09)!,
          Color.lerp(Colors.white, color, 0.18)!,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: color.withOpacity(0.25), width: 1),
      boxShadow: [
        BoxShadow(
          color: color.withOpacity(0.22),
          blurRadius: 16,
          offset: const Offset(0, 6),
          spreadRadius: -3,
        ),
        BoxShadow(
          color: color.withOpacity(0.08),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ],
    );
  }

  /// Item secondaire dans une liste — légèrement teinté, ombre légère.
  static BoxDecoration subtle({double radius = 12}) {
    return BoxDecoration(
      color: const Color(0xFFFAF4EE),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: const Color(0xFFE8D9C8), width: 1),
      boxShadow: [
        BoxShadow(
          color: _shadow.withOpacity(0.10),
          blurRadius: 8,
          offset: const Offset(0, 3),
          spreadRadius: -1,
        ),
      ],
    );
  }

  /// Container intérieur (fond légèrement teinté, pas d'ombre).
  static BoxDecoration inner({double radius = 10}) {
    return BoxDecoration(
      color: const Color(0xFFF3EAE0),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: const Color(0xFFE0CDB8), width: 1),
    );
  }
}
