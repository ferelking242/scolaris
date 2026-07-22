import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';

const _terra = Color(0xFF8B1A00);
const _green = Color(0xFF16A34A);
const _gold  = Color(0xFFC17F24);

const _moisAbbr = [
  'janv','févr','mars','avr','mai','juin',
  'juil','août','sept','oct','nov','déc'
];

/// Étiquette courte d'une période ('2025-09' → 'sept' · '2025-T1' → 'T1').
String _periodShort(String p) {
  final parts = p.split('-');
  if (parts.length < 2) return p;
  final tail = parts[1];
  if (tail.startsWith('T')) return tail;
  final m = int.tryParse(tail);
  return (m != null && m >= 1 && m <= 12) ? _moisAbbr[m - 1] : p;
}

enum _Cell { paid, partial, late, upcoming, none }

/// Suivi de la scolarité : matrice élève × mois, dérivée du COMPTE annuel de
/// chaque élève (même source que « Comptes scolarité » et l'espace élève/
/// parent) — pas de facture par mois : le versé se déduit en cascade sur les
/// mois via `SbTuitionAccount.periodsCovered`. Design system : `PageScaffold`
/// + `DataPanel`.
class TuitionTrackingPage extends ConsumerWidget {
  /// Si fourni, la barre de retour appelle ce callback (mode inline) au lieu de
  /// `Navigator.maybePop` (mode route).
  final VoidCallback? onBack;
  const TuitionTrackingPage({super.key, this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(studentsProvider);
    final accountsAsync = ref.watch(tuitionAccountsProvider);
    final loading = studentsAsync.isLoading || accountsAsync.isLoading;
    final error = accountsAsync.hasError ? accountsAsync.error : null;

    String? subtitle;
    final students = studentsAsync.valueOrNull;
    final accounts = accountsAsync.valueOrNull;
    if (students != null && accounts != null) {
      if (accounts.isEmpty) {
        subtitle = 'Aucune grille de frais configurée';
      } else {
        var total = 0, paid = 0;
        for (final acc in accounts.values) {
          total += acc.periods.length;
          paid += acc.periodsCovered.floor().clamp(0, acc.periods.length);
        }
        final pct = total == 0 ? 0 : (paid / total * 100).round();
        subtitle = '${accounts.length} élève(s) · $pct % réglé';
      }
    }

    return PageScaffold(
      title: 'Suivi scolarité',
      subtitle: loading ? 'Chargement…' : subtitle,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        BackLinkRow(label: 'Retour à la facturation', onTap: onBack),
        const SizedBox(height: 14),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator(color: _terra)),
          )
        else if (error != null)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Erreur : $error', style: TextStyle(color: context.cMuted)),
          )
        else
          _body(context, students ?? const [], accounts ?? const {}),
      ]),
    );
  }

  Widget _body(BuildContext context, List<SbStudent> students,
      Map<String, SbTuitionAccount> accounts) {
    final withAccount = students.where((s) => accounts.containsKey(s.id)).toList()
      ..sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));

    if (withAccount.isEmpty) {
      return const EmptyState(
        icon: Icons.event_busy_rounded,
        title: 'Aucune grille de frais',
        description:
            'Configure d\'abord les frais de scolarité par classe depuis « Frais de scolarité ».',
      );
    }

    // Union des codes de période (classes différentes = grilles différentes).
    final periodSet = <String>{};
    for (final s in withAccount) {
      for (final p in accounts[s.id]!.periods) {
        periodSet.add(p.code);
      }
    }
    final periods = periodSet.toList()..sort();

    final byStudentPeriod = <String, Map<String, _Cell>>{};
    for (final s in withAccount) {
      final acc = accounts[s.id]!;
      final today = DateTime.now();
      final covered = acc.periodsCovered;
      final map = <String, _Cell>{};
      for (int i = 0; i < acc.periods.length; i++) {
        final period = acc.periods[i];
        final fullyCovered = covered >= i + 1 - 0.001;
        final partlyCovered = !fullyCovered && covered > i + 0.001;
        final due = !period.due.isAfter(today);
        map[period.code] = fullyCovered
            ? _Cell.paid
            : partlyCovered
                ? _Cell.partial
                : due
                    ? _Cell.late
                    : _Cell.upcoming;
      }
      byStudentPeriod[s.id] = map;
    }

    int paidCount = 0, lateCount = 0, partialCount = 0, upcomingCount = 0;
    for (final map in byStudentPeriod.values) {
      for (final c in map.values) {
        switch (c) {
          case _Cell.paid: paidCount++; break;
          case _Cell.late: lateCount++; break;
          case _Cell.partial: partialCount++; break;
          case _Cell.upcoming: upcomingCount++; break;
          case _Cell.none: break;
        }
      }
    }
    final total = paidCount + lateCount + partialCount + upcomingCount;
    final pct = total == 0 ? 0 : (paidCount / total * 100).round();

    final periodPct = <String, int>{
      for (final p in periods)
        p: () {
          var tot = 0, pd = 0;
          for (final map in byStudentPeriod.values) {
            final c = map[p];
            if (c == null || c == _Cell.none) continue;
            tot++;
            if (c == _Cell.paid) pd++;
          }
          return tot == 0 ? 0 : (pd / tot * 100).round();
        }()
    };

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Vue d'ensemble.
      DataPanel(
        title: 'Vue d\'ensemble',
        child: Column(children: [
          Wrap(spacing: 10, runSpacing: 10, children: [
            _Stat(label: 'Échéances', value: '$total', color: const Color(0xFF6D28D9)),
            _Stat(label: 'Réglées', value: '$paidCount', color: _green),
            _Stat(label: 'Partielles', value: '$partialCount', color: _gold),
            _Stat(label: 'En retard', value: '$lateCount', color: _terra),
            _Stat(label: 'Taux réglé', value: '$pct %', color: _gold),
          ]),
          const SizedBox(height: 14),
          _ProgressBar(paid: paidCount, partial: partialCount, late: lateCount, upcoming: upcomingCount),
          const SizedBox(height: 12),
          const Wrap(spacing: 14, runSpacing: 8, children: [
            _LegendDot(color: _green, label: 'Réglé'),
            _LegendDot(color: _gold, label: 'Partiel'),
            _LegendDot(color: _terra, label: 'En retard'),
            _LegendDot(color: Color(0xFFB8A892), label: 'À venir'),
          ]),
        ]),
      ),
      const SizedBox(height: 14),

      // Matrice de paiement.
      DataPanel(
        title: 'Matrice de paiement',
        padding: const EdgeInsets.all(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: context.cBorder),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _corner(context),
                for (int i = 0; i < withAccount.length; i++)
                  _nameCell(context, withAccount[i].fullName, i),
              ]),
              Container(width: 1, color: context.cBorder),
              Expanded(child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    for (final p in periods) _periodHeader(context, p, periodPct[p] ?? 0),
                  ]),
                  for (int i = 0; i < withAccount.length; i++)
                    Row(children: [
                      for (final p in periods)
                        _chip(context, byStudentPeriod[withAccount[i].id]?[p] ?? _Cell.none, i),
                    ]),
                ]),
              )),
            ]),
          ),
        ),
      ),
    ]);
  }

  static const _rowH  = 46.0;
  static const _headH = 52.0;
  static const _nameW = 150.0;
  static const _cellW = 56.0;

  Color _zebra(BuildContext context, int i) =>
      i.isEven ? context.cCard : context.cSubtle;

  Widget _corner(BuildContext context) => Container(
        width: _nameW, height: _headH,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: context.cSubtle),
        child: Text('ÉLÈVE',
            style: TextStyle(color: context.cMuted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .5)),
      );

  Widget _nameCell(BuildContext context, String name, int i) => Container(
        width: _nameW, height: _rowH,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        color: _zebra(context, i),
        child: Text(name,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: context.cInk, fontSize: 12.5, fontWeight: FontWeight.w600)),
      );

  Widget _periodHeader(BuildContext context, String p, int pct) => Container(
        width: _cellW, height: _headH,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: context.cSubtle),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(_periodShort(p),
              style: TextStyle(color: context.cInk, fontSize: 10.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text('$pct%',
              style: TextStyle(
                  color: pct >= 100 ? _green : (pct == 0 ? context.cMuted : _gold),
                  fontSize: 9, fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _chip(BuildContext context, _Cell cell, int i) {
    final (color, icon) = switch (cell) {
      _Cell.paid     => (_green, Icons.check_rounded),
      _Cell.partial  => (_gold, Icons.adjust_rounded),
      _Cell.late     => (_terra, Icons.priority_high_rounded),
      _Cell.upcoming => (const Color(0xFFB8A892), Icons.schedule_rounded),
      _Cell.none     => (const Color(0xFFB8A892), Icons.remove_rounded),
    };
    return Container(
      width: _cellW, height: _rowH,
      alignment: Alignment.center,
      color: _zebra(context, i),
      child: Container(
        width: 26, height: 26,
        decoration: BoxDecoration(
          color: color.withValues(alpha: cell == _Cell.none ? .08 : .15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 15),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Stat({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        width: 150,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: .25)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: context.cMuted, fontSize: 11.5, fontWeight: FontWeight.w600)),
        ]),
      );
}

/// Barre de progression empilée : réglé / partiel / à venir / en retard.
class _ProgressBar extends StatelessWidget {
  final int paid, partial, late, upcoming;
  const _ProgressBar({required this.paid, required this.partial, required this.late, required this.upcoming});
  @override
  Widget build(BuildContext context) {
    final hasData = paid + partial + late + upcoming > 0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: Row(children: [
        if (paid > 0) Expanded(flex: paid, child: Container(height: 10, color: _green)),
        if (partial > 0) Expanded(flex: partial, child: Container(height: 10, color: _gold)),
        if (upcoming > 0) Expanded(flex: upcoming, child: Container(height: 10, color: const Color(0xFFB8A892))),
        if (late > 0) Expanded(flex: late, child: Container(height: 10, color: _terra)),
        if (!hasData) Expanded(child: Container(height: 10, color: context.cBorder)),
      ]),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: context.cMuted, fontSize: 11.5)),
      ]);
}
