import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presentation/providers/db_providers.dart';

/// Sélecteur d'école (Phase B — identité portable). N'apparaît que si le compte
/// a au moins 2 adhésions (`school_members`). Choisir une école bascule
/// `activeSchoolIdProvider` → toutes les données se rechargent pour cette école.
class SchoolSwitcher extends ConsumerWidget {
  const SchoolSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberships =
        ref.watch(myMembershipsProvider).valueOrNull ?? const [];
    if (memberships.length < 2) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final activeId = ref.watch(currentSchoolIdProvider);
    final active = memberships.firstWhere(
      (m) => m.schoolId == activeId,
      orElse: () => memberships.first,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: PopupMenuButton<String>(
        tooltip: 'Changer d\'école',
        onSelected: (sid) =>
            ref.read(activeSchoolIdProvider.notifier).state = sid,
        itemBuilder: (_) => [
          for (final m in memberships)
            PopupMenuItem(
              value: m.schoolId,
              child: Row(children: [
                Icon(
                  m.schoolId == active.schoolId
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  size: 16,
                  color: m.schoolId == active.schoolId
                      ? const Color(0xFF1B5E20)
                      : cs.onSurface.withOpacity(.4),
                ),
                const SizedBox(width: 10),
                Text(m.schoolName ?? 'École'),
              ]),
            ),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: cs.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outline.withOpacity(.3)),
          ),
          child: Row(children: [
            Icon(Icons.apartment_rounded, size: 16, color: cs.onSurface.withOpacity(.6)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('École active',
                      style: TextStyle(
                          fontSize: 9.5,
                          color: cs.onSurface.withOpacity(.5),
                          fontWeight: FontWeight.w600)),
                  Text(active.schoolName ?? 'École',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurface,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            Icon(Icons.unfold_more_rounded, size: 18, color: cs.onSurface.withOpacity(.5)),
          ]),
        ),
      ),
    );
  }
}
