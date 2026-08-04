import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';

class AttendanceLogPage extends ConsumerWidget {
  const AttendanceLogPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(studentsProvider);
    final now = DateTime.now();
    final dateLabel = '${now.day}/${now.month}/${now.year}';

    Future<void> refresh() async {
      ref.invalidate(studentsProvider);
      await ref.read(studentsProvider.future);
    }

    return studentsAsync.when(
      loading: () => PageScaffold(
        title: 'Journal des présences',
        subtitle: 'Présences du jour — $dateLabel',
        onRefresh: refresh,
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => PageScaffold(
        title: 'Journal des présences',
        subtitle: 'Présences du jour — $dateLabel',
        onRefresh: refresh,
        child: Center(child: Text('Erreur : $e')),
      ),
      data: (students) => PageScaffold(
        title: 'Journal des présences',
        subtitle: 'Présences du jour — $dateLabel',
        onRefresh: refresh,
        child: students.isEmpty
            ? const _EmptyState()
            : DataPanel(
                title: 'Présences du jour',
                headerActions: const [SearchInput(hint: 'Rechercher…')],
                child: DataTablePanel(
                  columns: const ['Élève', 'Classe', 'Matricule', 'Statut'],
                  flex: const [3, 2, 2, 2],
                  rows: [
                    for (final s in students)
                      [
                        Row(children: [
                          Avatar(name: s.fullName, size: 22),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(s.fullName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: ink,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ]),
                        Text(s.classe ?? '—',
                            style: const TextStyle(fontSize: 12, color: muted)),
                        Text(s.matricule ?? '—',
                            style: const TextStyle(fontSize: 12, color: muted)),
                        Align(
                            alignment: Alignment.centerLeft,
                            child: _pill('pending')),
                      ],
                  ],
                ),
              ),
      ),
    );
  }

  static Widget _pill(String status) {
    final c = status == 'present'
        ? const Color(0xFF16A34A)
        : status == 'late'
            ? const Color(0xFFEA580C)
            : const Color(0xFF6B7280);
    final label = status == 'present'
        ? 'Présent'
        : status == 'late'
            ? 'Retard'
            : 'En attente';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w700)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.fact_check_outlined, size: 48, color: muted),
              SizedBox(height: 12),
              Text('Aucune présence enregistrée',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ink)),
              SizedBox(height: 4),
              Text('Aucun élève à afficher pour cette journée.',
                  style: TextStyle(fontSize: 13, color: muted),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}
