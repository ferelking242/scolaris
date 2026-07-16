import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';

const _terra  = ScolarisPalette.terracotta;
const _orange = ScolarisPalette.orange;
const _gold   = ScolarisPalette.gold;
const _green  = ScolarisPalette.forestGreen;

// La base ne stocke QUE les absences/retards (pas les jours de présence). On
// affiche donc uniquement du réel : compteurs (absences, retards, justifiées /
// non justifiées) + la liste détaillée — pas de « taux de présence » fabriqué.
class AttendancePage extends ConsumerWidget {
  /// Élève ciblé. `null` = l'élève connecté (vue élève).
  /// Renseigné = vue parent sur un de ses enfants.
  final String? studentId;
  final String? title;
  const AttendancePage({super.key, this.studentId, this.title});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heading = title ?? 'Mes présences';
    final absencesAsync = studentId != null
        ? ref.watch(absencesForStudentProvider(studentId!))
        : ref.watch(myAbsencesProvider);

    return absencesAsync.when(
      loading: () => PageScaffold(
        title: heading,
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => PageScaffold(
        title: heading,
        child: Center(child: Text('Erreur : $e',
            style: TextStyle(color: context.cMuted))),
      ),
      data: (absences) {
        final retards     = absences.where((a) => a.status == 'late').length;
        final absencesNb  = absences.length - retards;
        final justifiees  = absences.where((a) => a.justified).length;
        final nonJust     = absences.length - justifiees;

        return PageScaffold(
          title: heading,
          subtitle: absences.isEmpty
              ? 'Aucune absence enregistrée'
              : '${absences.length} événement(s) · $nonJust non justifiée(s)',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Compteurs réels ──────────────────────────────────────────
            _SummaryCards(
              absences: absencesNb,
              retards: retards,
              justifiees: justifiees,
              nonJustifiees: nonJust,
            ),
            const SizedBox(height: 18),

            // ── Détail (réel) ────────────────────────────────────────────
            const _SectionHeader(
                icon: Icons.list_alt_rounded,
                title: 'Détail des absences & retards'),
            const SizedBox(height: 10),
            _AttendanceDetail(studentId: studentId),
          ]),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Section header
// ══════════════════════════════════════════════════════════════════════════
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_terra, _orange],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 15),
      ),
      const SizedBox(width: 8),
      Text(title, style: TextStyle(
          fontSize: 14, color: context.cInk, fontWeight: FontWeight.w800)),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════
// 4 cartes résumé — toutes dérivées des vraies absences
// ══════════════════════════════════════════════════════════════════════════
class _SummaryCards extends StatelessWidget {
  final int absences, retards, justifiees, nonJustifiees;
  const _SummaryCards({
    required this.absences,
    required this.retards,
    required this.justifiees,
    required this.nonJustifiees,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      (icon: Icons.cancel_rounded,        label: 'Absences',       val: '$absences',      color: _terra),
      (icon: Icons.access_time_rounded,   label: 'Retards',        val: '$retards',       color: _gold),
      (icon: Icons.verified_rounded,      label: 'Justifiées',     val: '$justifiees',    color: _green),
      (icon: Icons.report_problem_rounded,label: 'Non justifiées', val: '$nonJustifiees', color: _orange),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10, mainAxisSpacing: 10,
      childAspectRatio: 1.8,
      children: items.map((it) => _SummaryCard(
        icon: it.icon, label: it.label, val: it.val, color: it.color,
      )).toList(),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label, val;
  final Color color;
  const _SummaryCard({required this.icon, required this.label, required this.val, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25), width: 1.5),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.10), blurRadius: 12, offset: const Offset(0, 4), spreadRadius: -2),
        ],
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color, color.withOpacity(0.75)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: color.withOpacity(0.30), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(val, style: TextStyle(fontSize: 22, color: color, fontWeight: FontWeight.w900)),
          Text(label, style: TextStyle(fontSize: 11, color: context.cMuted, fontWeight: FontWeight.w600),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Détail absences et retards (réel)
// ══════════════════════════════════════════════════════════════════════════
class _AttendanceDetail extends ConsumerWidget {
  final String? studentId;
  const _AttendanceDetail({this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final absencesAsync = studentId != null
        ? ref.watch(absencesForStudentProvider(studentId!))
        : ref.watch(myAbsencesProvider);
    final absences = absencesAsync.value ?? [];
    if (absences.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: context.cCard, borderRadius: BorderRadius.circular(13)),
        child: Center(child: Text('Aucune absence ou retard enregistré.',
            style: TextStyle(color: context.cMuted, fontSize: 13))),
      );
    }
    return Column(
      children: absences.map((a) {
        final isAbsence = a.status == 'absent';
        final justified = a.justified;
        final color = justified ? _gold : (isAbsence ? _terra : _orange);
        final typeLabel = isAbsence ? 'Absence' : 'Retard';
        final motifLabel = justified ? 'Justifiée' : 'Non justifiée';
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.cCard,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color, color.withOpacity(0.75)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isAbsence ? Icons.cancel_rounded : Icons.access_time_rounded,
                color: Colors.white, size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(typeLabel, style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(a.date ?? '—', style: TextStyle(
                  color: context.cInk, fontSize: 13, fontWeight: FontWeight.w700)),
              if (a.reason != null && a.reason!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(a.reason!, style: TextStyle(color: context.cMuted, fontSize: 11.5)),
              ],
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (justified ? _green : _terra).withOpacity(0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: (justified ? _green : _terra).withOpacity(0.30)),
              ),
              child: Text(motifLabel,
                  style: TextStyle(
                      color: justified ? _green : _terra,
                      fontSize: 10, fontWeight: FontWeight.w800)),
            ),
          ]),
        );
      }).toList(),
    );
  }
}
