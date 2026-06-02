import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/auth_providers.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';

class ChildrenPage extends ConsumerWidget {
  const ChildrenPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Parents see students linked to them; fallback: all students
    final studentsAsync = ref.watch(studentsProvider);
    return studentsAsync.when(
      loading: () => const PageScaffold(
        title: 'Mes enfants',
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => PageScaffold(
        title: 'Mes enfants',
        child: Center(child: Text('Erreur : $e')),
      ),
      data: (students) {
        final session = ref.read(authSessionProvider);
        // Filter by parent_id if available; otherwise show first 3 as demo
        final kids = students
            .where((s) =>
                session != null && s.id.contains(session.id)
                    ? true
                    : false)
            .toList();
        final displayed = kids.isEmpty ? students.take(3).toList() : kids;
        return PageScaffold(
          title: 'Mes enfants',
          subtitle: '${displayed.length} enfant(s) inscrit(s)',
          child: LayoutBuilder(builder: (ctx, c) {
            final cols = c.maxWidth > 720 ? 2 : 1;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayed.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: 180,
              ),
              itemBuilder: (_, i) => _ChildCard(student: displayed[i]),
            );
          }),
        );
      },
    );
  }
}

class _ChildCard extends StatelessWidget {
  final SbStudent student;
  const _ChildCard({required this.student});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .06),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Avatar(name: student.fullName, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(student.fullName,
                          style: const TextStyle(
                              fontSize: 14,
                              color: ink,
                              fontWeight: FontWeight.w700)),
                      Text(student.classe ?? '—',
                          style: const TextStyle(fontSize: 12, color: muted)),
                    ]),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              _InfoChip(
                  label: student.niveau ?? '—',
                  icon: Icons.school_outlined),
              const SizedBox(width: 8),
              _InfoChip(
                  label: student.matricule ?? '—',
                  icon: Icons.badge_outlined),
            ]),
            const Spacer(),
            Row(children: [
              Expanded(
                child: _ActionBtn(
                    label: 'Notes',
                    icon: Icons.grading_rounded,
                    onTap: () {}),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionBtn(
                    label: 'Présences',
                    icon: Icons.event_available_rounded,
                    onTap: () {}),
              ),
            ]),
          ],
        ),
      );
}

class _InfoChip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _InfoChip({required this.label, required this.icon});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: muted),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: muted)),
      ]);
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.label, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFF5EEE6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 14, color: muted),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12, color: ink)),
          ]),
        ),
      );
}
