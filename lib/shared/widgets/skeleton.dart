import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

export 'package:skeletonizer/skeletonizer.dart' show Skeletonizer;

const _boneColor  = Color(0xFFDDD6CE);
const _boneHigh   = Color(0xFFEFEAE3);

/// Boîte skeleton générique — remplace les anciens SkeletonBox shimmer.
class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      effect: const ShimmerEffect(
        baseColor: _boneColor,
        highlightColor: _boneHigh,
      ),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: _boneColor,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// Skeleton d'une stat card (icône + label + valeur).
class SkeletonStatCard extends StatelessWidget {
  const SkeletonStatCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      effect: const ShimmerEffect(baseColor: _boneColor, highlightColor: _boneHigh),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: _boneColor,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: 60, height: 10,
              decoration: BoxDecoration(
                color: _boneColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: 40, height: 18,
              decoration: BoxDecoration(
                color: _boneColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton d'une ligne de liste (avatar + deux lignes de texte).
class SkeletonListRow extends StatelessWidget {
  const SkeletonListRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      effect: const ShimmerEffect(baseColor: _boneColor, highlightColor: _boneHigh),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: _boneColor,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 12,
                decoration: BoxDecoration(
                  color: _boneColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 120, height: 10,
                decoration: BoxDecoration(
                  color: _boneColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          )),
          const SizedBox(width: 12),
          Container(
            width: 40, height: 24,
            decoration: BoxDecoration(
              color: _boneColor,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Nombre dynamique : shimmers si null, affiche la valeur sinon.
class SkeletonNumber extends StatelessWidget {
  final String? value;
  final TextStyle? style;
  const SkeletonNumber({super.key, this.value, this.style});

  @override
  Widget build(BuildContext context) {
    if (value != null) return Text(value!, style: style);
    return Skeletonizer(
      enabled: true,
      effect: const ShimmerEffect(baseColor: _boneColor, highlightColor: _boneHigh),
      child: Container(
        width: 28, height: 14,
        decoration: BoxDecoration(
          color: _boneColor,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}
