import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/auth_providers.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';

const _terra = ScolarisPalette.terracotta;
const _gold  = ScolarisPalette.gold;
const _white = Colors.white; // sur fond de marque coloré

// ══════════════════════════════════════════════════════════════════════════
// Récompenses — CÔTÉ ENSEIGNANT (l'attribution).
//
// Le pendant du cahier de liaison : la lecture existe déjà chez l'élève et le
// parent, mais sans écran pour ATTRIBUER, le carnet reste vide. Le prof choisit
// une de ses classes, puis un élève, et lui donne un bon point (1 à 3 étoiles)
// ou lui décerne un badge du catalogue de l'école.
//
// La RLS exige `recompenses.attribuer` et `awarded_by = moi`.
// ══════════════════════════════════════════════════════════════════════════
class TeacherRewardsPage extends ConsumerStatefulWidget {
  const TeacherRewardsPage({super.key});
  @override
  ConsumerState<TeacherRewardsPage> createState() => _TeacherRewardsPageState();
}

class _TeacherRewardsPageState extends ConsumerState<TeacherRewardsPage> {
  SbClass? _class;

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(teacherClassesProvider);

    return classesAsync.when(
      loading: () => const PageScaffold(
        title: 'Récompenses',
        child: Center(child: Padding(
          padding: EdgeInsets.only(top: 60),
          child: CircularProgressIndicator(),
        )),
      ),
      error: (e, _) => PageScaffold(
        title: 'Récompenses',
        child: Center(child: Text('Erreur : $e',
            style: TextStyle(color: context.cMuted))),
      ),
      data: (classes) {
        if (classes.isEmpty) {
          return const PageScaffold(
            title: 'Récompenses',
            child: EmptyState(
              icon: Icons.class_outlined,
              title: 'Aucune classe',
              description:
                  'Vous n\'êtes affecté à aucune classe. Contactez la direction.',
            ),
          );
        }

        final selected = _class ?? classes.first;
        final studentsAsync =
            ref.watch(studentsByClassProvider(selected.name));

        return PageScaffold(
          title: 'Récompenses',
          subtitle: 'Bons points et badges · ${selected.name}',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            if (classes.length > 1) ...[
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: classes.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final c = classes[i];
                    final sel = c.id == selected.id;
                    return GestureDetector(
                      onTap: () => setState(() => _class = c),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: sel ? _terra : context.cCard,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: sel ? _terra : context.cBorder),
                        ),
                        child: Text(c.name, style: TextStyle(
                            color: sel ? _white : context.cMuted,
                            fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
            ],

            studentsAsync.when(
              loading: () => const Center(child: Padding(
                padding: EdgeInsets.only(top: 40),
                child: CircularProgressIndicator(),
              )),
              error: (e, _) => Text('Erreur : $e',
                  style: TextStyle(color: context.cMuted)),
              data: (students) {
                if (students.isEmpty) {
                  return EmptyState(
                    icon: Icons.people_outline_rounded,
                    title: 'Aucun élève',
                    description: '${selected.name} ne compte aucun élève.',
                  );
                }
                return Column(children: [
                  for (final s in students)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _StudentRow(
                        student: s,
                        onAward: () => _award(s),
                      ),
                    ),
                ]);
              },
            ),
          ]),
        );
      },
    );
  }

  Future<void> _award(SbStudent student) async {
    final session  = ref.read(authSessionProvider);
    final schoolId = ref.read(currentSchoolIdProvider);
    if (session == null || schoolId == null) return;

    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AwardSheet(
        student: student,
        schoolId: schoolId,
        teacherId: session.id,
      ),
    );

    if (done == true) {
      ref.invalidate(meritPointsForStudentProvider(student.id));
      ref.invalidate(badgesForStudentProvider(student.id));
    }
  }
}

// ── Ligne élève ───────────────────────────────────────────────────────────────
class _StudentRow extends ConsumerWidget {
  final SbStudent student;
  final VoidCallback onAward;
  const _StudentRow({required this.student, required this.onAward});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final points = ref.watch(meritPointsForStudentProvider(student.id))
        .valueOrNull ?? const <SbMeritPoint>[];
    final etoiles = points.fold<int>(0, (s, p) => s + p.stars);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cCard,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: context.cBorder),
      ),
      child: Row(children: [
        Avatar(name: student.fullName, size: 38),
        const SizedBox(width: 12),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(student.fullName, style: TextStyle(
              fontSize: 13.5, fontWeight: FontWeight.w700,
              color: context.cInk),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(etoiles == 0
                  ? 'Aucune étoile'
                  : '$etoiles étoile(s) · ${points.length} bon(s) point(s)',
              style: TextStyle(fontSize: 11, color: context.cMuted)),
        ])),
        ActionButton(
          label: 'Récompenser',
          icon: Icons.star_rounded,
          primary: true,
          onTap: onAward,
        ),
      ]),
    );
  }
}

// ── Feuille d'attribution ─────────────────────────────────────────────────────
class _AwardSheet extends ConsumerStatefulWidget {
  final SbStudent student;
  final String schoolId, teacherId;
  const _AwardSheet({
    required this.student,
    required this.schoolId,
    required this.teacherId,
  });

  @override
  ConsumerState<_AwardSheet> createState() => _AwardSheetState();
}

class _AwardSheetState extends ConsumerState<_AwardSheet> {
  final _reason  = TextEditingController();
  final _subject = TextEditingController();
  int _stars = 1;
  bool _saving = false;

  @override
  void dispose() {
    _reason.dispose();
    _subject.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final badges = ref.watch(badgesForStudentProvider(widget.student.id))
        .valueOrNull ?? const <SbBadge>[];
    // On ne propose que les badges pas encore obtenus : la contrainte
    // `unique(student_id, badge_id)` refuserait un doublon de toute façon.
    final available = badges.where((b) => !b.earned).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: BoxDecoration(
          color: context.cPage,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: context.cBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Récompenser ${widget.student.prenom}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                      color: context.cInk)),
            ),
            const SizedBox(height: 18),

            // ── Bon point ───────────────────────────────────────────────
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Donner un bon point', style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: context.cInk)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _reason,
              decoration: const InputDecoration(
                labelText: 'Motif',
                hintText: 'Excellent devoir de calcul',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _subject,
              decoration: const InputDecoration(
                labelText: 'Matière (facultatif)',
                hintText: 'Calcul, Lecture, Conduite…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Text('Étoiles', style: TextStyle(
                  fontSize: 12.5, color: context.cMuted,
                  fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              for (var i = 1; i <= 3; i++)
                IconButton(
                  onPressed: () => setState(() => _stars = i),
                  icon: Icon(
                    i <= _stars
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: i <= _stars ? _gold : context.cBorder,
                    size: 28,
                  ),
                ),
            ]),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _savePoint,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: _white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _white))
                    : const Text('Donner le bon point',
                        style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),

            const SizedBox(height: 22),
            Divider(color: context.cBorder),
            const SizedBox(height: 14),

            // ── Badge ───────────────────────────────────────────────────
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Décerner un badge', style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: context.cInk)),
            ),
            const SizedBox(height: 10),
            if (available.isEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                    badges.isEmpty
                        ? 'L\'école n\'a défini aucun badge. '
                            'La direction peut en créer dans les réglages.'
                        : '${widget.student.prenom} a déjà tous les badges.',
                    style: TextStyle(fontSize: 12, color: context.cMuted,
                        height: 1.4)),
              )
            else
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final b in available)
                  GestureDetector(
                    onTap: _saving ? null : () => _awardBadge(b),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: context.cCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.cBorder),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(b.emoji ?? '🏅',
                            style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Text(b.title, style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: context.cInk)),
                      ]),
                    ),
                  ),
              ]),
          ]),
        ),
      ),
    );
  }

  Future<void> _savePoint() async {
    final reason = _reason.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Indiquez le motif du bon point.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await SupabaseDbSource.awardMeritPoint(
        schoolId: widget.schoolId,
        studentId: widget.student.id,
        awardedBy: widget.teacherId,
        reason: reason,
        subject: _subject.text.trim().isEmpty ? null : _subject.text.trim(),
        stars: _stars,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Attribution refusée : $e')),
      );
    }
  }

  Future<void> _awardBadge(SbBadge badge) async {
    setState(() => _saving = true);
    try {
      await SupabaseDbSource.awardBadgeToStudent(
        schoolId: widget.schoolId,
        studentId: widget.student.id,
        badgeId: badge.id,
        awardedBy: widget.teacherId,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Badge refusé : $e')),
      );
    }
  }
}
