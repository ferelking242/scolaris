import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';

/// Progression du prof dans le programme de ses cours.
///
/// Le programme (texte + nombre total de chapitres) reste écrit par
/// l'admin/staff — commun à tous les profs d'une même matière. Ici, chaque
/// prof indique juste où il en est réellement (`chapters_done`), sans
/// pouvoir réécrire le programme officiel.
class TeacherProgramPage extends ConsumerWidget {
  const TeacherProgramPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(coursesTaughtByMeProvider);
    return PageScaffold(
      title: 'Programme',
      onRefresh: () async {
        ref.invalidate(coursesTaughtByMeProvider);
        await ref.read(coursesTaughtByMeProvider.future);
      },
      subtitle: 'Où en êtes-vous dans le programme de chacun de vos cours ?',
      child: coursesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (courses) => courses.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                    child: Text('Aucun cours ne vous est assigné.',
                        style: TextStyle(color: muted))),
              )
            : Column(children: [
                for (final c in courses) ...[
                  _CourseProgressCard(course: c),
                  const SizedBox(height: 12),
                ],
              ]),
      ),
    );
  }
}

class _CourseProgressCard extends ConsumerStatefulWidget {
  final SbCourse course;
  const _CourseProgressCard({required this.course});

  @override
  ConsumerState<_CourseProgressCard> createState() => _CourseProgressCardState();
}

class _CourseProgressCardState extends ConsumerState<_CourseProgressCard> {
  late int _done = widget.course.chaptersDone;
  bool _saving = false;

  Future<void> _save(int value) async {
    final total = widget.course.chapterCount;
    final clamped = total != null && total > 0
        ? value.clamp(0, total)
        : value.clamp(0, 1000000);
    setState(() { _done = clamped; _saving = true; });
    try {
      await SupabaseDbSource.setCourseChaptersDone(
        courseId: widget.course.id,
        chaptersDone: clamped,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _done = widget.course.chaptersDone);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Échec : $e'),
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.course.chapterCount;
    final hasProgram = total != null && total > 0;
    return DataPanel(
      title: widget.course.name,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!hasProgram)
          const Text(
            "L'admin n'a pas encore renseigné de programme pour ce cours.",
            style: TextStyle(color: muted, fontSize: 12.5),
          )
        else ...[
          Row(children: [
            Expanded(
              child: LinearProgressIndicator(
                value: _done / total,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Text('$_done / $total chapitres',
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w700, color: ink)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: _saving || _done <= 0 ? null : () => _save(_done - 1),
            ),
            Text('Chapitre $_done', style: const TextStyle(color: muted)),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: _saving || _done >= total ? null : () => _save(_done + 1),
            ),
            if (_saving) ...[
              const SizedBox(width: 8),
              const SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ]),
        ],
      ]),
    );
  }
}
