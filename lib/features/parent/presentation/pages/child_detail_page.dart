import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/data/features_catalog.dart';
import '../../../../shared/widgets/page_scaffold.dart';
import '../../../student/presentation/pages/attendance_page.dart';
import '../../../student/presentation/pages/cahier_liaison_page.dart';
import '../../../student/presentation/pages/carnet_recompenses_page.dart';
import '../../../student/presentation/pages/grades_page.dart';
import '../../../student/presentation/pages/menu_cantine_page.dart';
import '../../../student/presentation/pages/schedule_page.dart';

const _terra  = ScolarisPalette.terracotta;
const _gold   = ScolarisPalette.gold;
const _green  = ScolarisPalette.forestGreen;
const _orange = ScolarisPalette.orange;

/// Fiche d'un enfant — porte d'entrée unique vers sa scolarité.
///
/// Choix de navigation (décidé avec l'utilisateur) : PAS de sélecteur d'enfant
/// global. Le parent ouvre « Mes enfants », clique sur un enfant, et tout ce
/// qu'il voit ici concerne cet enfant-là. L'`studentId` est passé explicitement
/// à chaque page — aucune ambiguïté possible sur « de qui parle cet écran ».
class ChildDetailPage extends ConsumerWidget {
  final SbStudent child;
  const ChildDetailPage({super.key, required this.child});

  void _push(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Le cycle de CET enfant, déduit de sa classe (« CE1 » → primaire).
    // On ne peut pas se servir de `studentSchoolLevelProvider` : il décrit
    // l'utilisateur connecté — ici, le parent, qui n'a pas de niveau.
    final level = SchoolLevel.fromClassName(child.classe ?? child.niveau);
    final isPrimaire = level == SchoolLevel.primaire;

    final grades   = ref.watch(gradesForStudentProvider(child.id));
    final absences = ref.watch(absencesForStudentProvider(child.id));
    final invoices = ref.watch(invoicesForStudentProvider(child.id));

    final gradeList = grades.valueOrNull ?? const <SbGrade>[];
    final moyenne = gradeList.isEmpty
        ? null
        : gradeList.fold<double>(0, (s, g) => s + g.outOf20) / gradeList.length;

    final absenceList = absences.valueOrNull ?? const <SbAbsence>[];
    final unpaid = (invoices.valueOrNull ?? const <SbInvoice>[])
        .where((i) => !i.isPaid)
        .length;

    final recent = ([...gradeList]..sort((a, b) =>
            (b.gradedAt ?? DateTime(2000)).compareTo(a.gradedAt ?? DateTime(2000))))
        .take(3)
        .toList();

    return PageScaffold(
      title: child.fullName,
      subtitle: [
        if (child.classe?.isNotEmpty == true) child.classe!,
        if (child.matricule?.isNotEmpty == true) child.matricule!,
      ].join(' · '),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Résumé ────────────────────────────────────────────────────────
        Row(children: [
          Expanded(child: _StatCard(
            icon: Icons.star_rounded,
            label: 'Moyenne',
            value: moyenne?.toStringAsFixed(1) ?? '—',
            suffix: moyenne != null ? '/20' : '',
            color: _gold,
            loading: grades.isLoading,
          )),
          const SizedBox(width: 10),
          Expanded(child: _StatCard(
            icon: Icons.event_busy_rounded,
            label: 'Absences',
            value: '${absenceList.length}',
            suffix: absenceList.length > 1 ? ' jours' : ' jour',
            color: absenceList.isEmpty ? _green : _terra,
            loading: absences.isLoading,
          )),
          const SizedBox(width: 10),
          Expanded(child: _StatCard(
            icon: Icons.receipt_long_rounded,
            label: 'Impayés',
            value: '$unpaid',
            suffix: unpaid > 1 ? ' factures' : ' facture',
            color: unpaid == 0 ? _green : _orange,
            loading: invoices.isLoading,
          )),
        ]),
        const SizedBox(height: 20),

        // ── Sa scolarité ──────────────────────────────────────────────────
        Text('Sa scolarité', style: TextStyle(
            color: context.cInk, fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        _NavTile(
          icon: Icons.grading_rounded, color: _gold,
          title: 'Notes',
          subtitle: gradeList.isEmpty
              ? 'Aucune note pour l\'instant'
              : '${gradeList.length} note(s)',
          onTap: () => _push(context, GradesPage(
              studentId: child.id, title: 'Notes de ${child.prenom}')),
        ),
        const SizedBox(height: 8),
        _NavTile(
          icon: Icons.calendar_month_rounded, color: _terra,
          title: 'Emploi du temps',
          subtitle: child.classe ?? 'Classe non renseignée',
          onTap: () => _push(context, SchedulePage(studentId: child.id)),
        ),
        const SizedBox(height: 8),
        _NavTile(
          icon: Icons.fact_check_rounded, color: _green,
          title: 'Présences',
          subtitle: absenceList.isEmpty
              ? 'Aucune absence'
              : '${absenceList.length} événement(s)',
          onTap: () => _push(context, AttendancePage(
              studentId: child.id, title: 'Présences de ${child.prenom}')),
        ),
        // Pas de bulletin : retiré des espaces élève ET parent (décision
        // utilisateur). Le bulletin reste produit et publié côté admin.

        // ── Outils du primaire ────────────────────────────────────────────
        // La fiche s'adapte à la classe de CET enfant : un parent peut avoir un
        // enfant en CE1 et un autre en Terminale, et voir deux fiches
        // différentes. Le niveau est une propriété de l'ENFANT, pas du parent —
        // c'est pourquoi il se dérive ici et pas dans le shell.
        if (isPrimaire) ...[
          const SizedBox(height: 8),
          _NavTile(
            icon: Icons.import_contacts_rounded, color: _terra,
            title: 'Cahier de liaison',
            subtitle: 'Les mots de l\'enseignant',
            onTap: () => _push(context, CahierLiaisonPage(
                studentId: child.id,
                title: 'Cahier de ${child.prenom}')),
          ),
          const SizedBox(height: 8),
          _NavTile(
            icon: Icons.emoji_events_rounded, color: _gold,
            title: 'Carnet de récompenses',
            subtitle: 'Bons points et badges',
            onTap: () => _push(context, CarnetRecompensesPage(
                studentId: child.id,
                title: 'Récompenses de ${child.prenom}')),
          ),
          const SizedBox(height: 8),
          _NavTile(
            icon: Icons.restaurant_rounded, color: _green,
            title: 'Menu de la cantine',
            subtitle: 'Les repas de la semaine',
            // Le menu appartient à l'école, pas à l'enfant : pas de studentId.
            onTap: () => _push(context, const MenuCantinePage()),
          ),
        ],
        const SizedBox(height: 22),

        // ── Dernières notes ───────────────────────────────────────────────
        Text('Dernières notes', style: TextStyle(
            color: context.cInk, fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        if (grades.isLoading)
          const Center(child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(),
          ))
        else if (recent.isEmpty)
          _Empty(label: 'Aucune note enregistrée pour ${child.prenom}.')
        else
          for (final g in recent) ...[
            _GradeRow(grade: g),
            const SizedBox(height: 8),
          ],
      ]),
    );
  }
}

// ── Carte statistique ───────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label, value, suffix;
  final Color color;
  final bool loading;
  const _StatCard({required this.icon, required this.label,
      required this.value, required this.suffix,
      required this.color, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.cBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: color.withOpacity(.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 15),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(
            color: context.cMuted, fontSize: 10, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        if (loading)
          SizedBox(
            height: 18,
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: color.withOpacity(.5)),
              ),
            ),
          )
        else
          RichText(text: TextSpan(children: [
            TextSpan(text: value, style: TextStyle(
                color: context.cInk, fontSize: 17, fontWeight: FontWeight.w900)),
            TextSpan(text: suffix, style: TextStyle(
                color: context.cMuted, fontSize: 10)),
          ])),
      ]),
    );
  }
}

// ── Tuile de navigation ─────────────────────────────────────────────────────
class _NavTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final VoidCallback onTap;
  const _NavTile({required this.icon, required this.color,
      required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.cCard,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.cBorder),
          ),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(
                  color: context.cInk, fontSize: 13.5,
                  fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(
                  color: context.cMuted, fontSize: 11)),
            ])),
            Icon(Icons.chevron_right_rounded,
                color: context.cMuted, size: 20),
          ]),
        ),
      ),
    );
  }
}

// ── Ligne de note ───────────────────────────────────────────────────────────
class _GradeRow extends StatelessWidget {
  final SbGrade grade;
  const _GradeRow({required this.grade});

  @override
  Widget build(BuildContext context) {
    final on20  = grade.outOf20;
    final color = on20 >= 14 ? _green : on20 >= 10 ? _gold : _terra;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.cCard,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: context.cBorder),
      ),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: color.withOpacity(.12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Center(child: Text(
            grade.score.toStringAsFixed(1),
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w900),
          )),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(grade.subjectName ?? grade.title ?? '—',
              style: TextStyle(
                  color: context.cInk, fontSize: 13,
                  fontWeight: FontWeight.w700),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text('sur ${grade.maxScore.toStringAsFixed(0)}'
              '${grade.period != null ? ' · ${grade.period}' : ''}',
              style: TextStyle(color: context.cMuted, fontSize: 11)),
        ])),
        Text(_fmt(grade.gradedAt),
            style: TextStyle(color: context.cMuted, fontSize: 10)),
      ]),
    );
  }

  static String _fmt(DateTime? d) {
    if (d == null) return '';
    const mois = ['janv.','févr.','mars','avr.','mai','juin','juil.','août',
                  'sept.','oct.','nov.','déc.'];
    return '${d.day} ${mois[d.month - 1]}';
  }
}

// ── État vide ───────────────────────────────────────────────────────────────
class _Empty extends StatelessWidget {
  final String label;
  const _Empty({required this.label});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: context.cCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.cBorder),
        ),
        child: Text(label, textAlign: TextAlign.center,
            style: TextStyle(color: context.cMuted, fontSize: 12.5)),
      );
}
