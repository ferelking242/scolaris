import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/auth_providers.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/data/features_catalog.dart';
import '../../../../shared/widgets/page_scaffold.dart';
import 'attendance_page.dart';
import 'grades_page.dart';
import 'student_payments_page.dart';

const _terra  = ScolarisPalette.terracotta;
const _orange = ScolarisPalette.orange;
const _gold   = ScolarisPalette.gold;
const _green  = ScolarisPalette.forestGreen;
const _cyan   = Color(0xFF0891B2);

// ══════════════════════════════════════════════════════════════════════════
// Modèle de notification (flux agrégé — aucune table dédiée)
// ══════════════════════════════════════════════════════════════════════════
enum _NotifKind { grade, absence, payment }

class _Notif {
  final _NotifKind kind;
  final String title;
  final String body;
  final DateTime? date;
  const _Notif({
    required this.kind,
    required this.title,
    required this.body,
    this.date,
  });

  Color get color => switch (kind) {
        _NotifKind.grade        => _gold,
        _NotifKind.absence      => _terra,
        _NotifKind.payment      => _orange,
      };

  IconData get icon => switch (kind) {
        _NotifKind.grade        => Icons.grading_rounded,
        _NotifKind.absence      => Icons.event_busy_rounded,
        _NotifKind.payment      => Icons.account_balance_wallet_rounded,
      };

  String get categoryLabel => switch (kind) {
        _NotifKind.grade        => 'Note',
        _NotifKind.absence      => 'Présence',
        _NotifKind.payment      => 'Paiement',
      };
}

// ══════════════════════════════════════════════════════════════════════════
// Page
// ══════════════════════════════════════════════════════════════════════════
class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});
  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  _NotifKind? _filter;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);

    // En primaire, la finance est du ressort du parent : pas d'alerte facture.
    final isPrimaire = ref.watch(studentSchoolLevelProvider).valueOrNull ==
        SchoolLevel.primaire;

    // Sources réelles — null tant que non chargé (on tolère les chargements
    // partiels : le flux s'enrichit au fur et à mesure).
    final gradesAsync = session != null
        ? ref.watch(gradesForStudentProvider(session.id))
        : const AsyncValue<List<SbGrade>>.data([]);
    final absencesAsync = ref.watch(myAbsencesProvider);
    final invoicesAsync = isPrimaire
        ? const AsyncValue<List<SbInvoice>>.data([])
        : ref.watch(myInvoicesProvider);

    final stillLoading = gradesAsync.isLoading &&
        absencesAsync.isLoading &&
        invoicesAsync.isLoading;

    final feed = _buildFeed(
      grades: gradesAsync.valueOrNull ?? const [],
      absences: absencesAsync.valueOrNull ?? const [],
      invoices: invoicesAsync.valueOrNull ?? const [],
    );

    final visible = _filter == null
        ? feed
        : feed.where((n) => n.kind == _filter).toList();

    final unread = feed.length;

    return PageScaffold(
      title: 'Notifications',
      subtitle: unread == 0
          ? 'Aucune notification'
          : '$unread notification(s) récente(s)',
      child: stillLoading
          ? const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FilterBar(
                  current: _filter,
                  counts: _countByKind(feed),
                  kinds: _NotifKind.values
                      .where((k) => !isPrimaire || k != _NotifKind.payment)
                      .toList(),
                  onTap: (k) => setState(() => _filter = _filter == k ? null : k),
                ),
                const SizedBox(height: 14),
                if (visible.isEmpty)
                  _EmptyState(filtered: _filter != null)
                else
                  for (final n in visible) ...[
                    _NotifCard(notif: n, onTap: () => _open(n.kind)),
                    const SizedBox(height: 10),
                  ],
              ],
            ),
    );
  }

  void _open(_NotifKind kind) {
    final Widget page = switch (kind) {
      _NotifKind.grade        => const GradesPage(),
      _NotifKind.absence      => const AttendancePage(),
      _NotifKind.payment      => const StudentPaymentsPage(),
    };
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Map<_NotifKind, int> _countByKind(List<_Notif> feed) {
    final m = <_NotifKind, int>{};
    for (final n in feed) {
      m[n.kind] = (m[n.kind] ?? 0) + 1;
    }
    return m;
  }

  /// Agrège les signaux réels de l'élève en un flux trié (plus récent d'abord).
  List<_Notif> _buildFeed({
    required List<SbGrade> grades,
    required List<SbAbsence> absences,
    required List<SbInvoice> invoices,
  }) {
    final out = <_Notif>[];

    for (final g in grades) {
      out.add(_Notif(
        kind: _NotifKind.grade,
        title: 'Nouvelle note — ${g.subjectName ?? g.title ?? 'Évaluation'}',
        body: '${g.score.toStringAsFixed(1)}/${g.maxScore.toStringAsFixed(0)}'
            '${g.period != null ? ' · ${g.period}' : ''}',
        date: g.gradedAt,
      ));
    }

    for (final a in absences) {
      out.add(_Notif(
        kind: _NotifKind.absence,
        title: a.justified ? 'Absence justifiée' : 'Absence à justifier',
        body: [
          if (a.absenceDate != null) _formatDate(a.absenceDate!),
          if (a.reason != null && a.reason!.isNotEmpty) a.reason!,
        ].join(' · '),
        date: a.absenceDate,
      ));
    }


    for (final inv in invoices) {
      final s = inv.status.toLowerCase();
      if (s == 'paid' || s == 'cancelled') continue;
      out.add(_Notif(
        kind: _NotifKind.payment,
        title: s == 'overdue' ? 'Paiement en retard' : 'Paiement à effectuer',
        body: '${inv.description ?? inv.invoiceNumber ?? 'Facture'} · '
            '${inv.amount.toStringAsFixed(0)} ${inv.currency}'
            '${inv.dueDate != null ? ' · échéance ${_formatDate(inv.dueDate!)}' : ''}',
        date: inv.dueDate,
      ));
    }

    out.sort((a, b) {
      final da = a.date, db = b.date;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });
    return out;
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Filtres
// ══════════════════════════════════════════════════════════════════════════
class _FilterBar extends StatelessWidget {
  final _NotifKind? current;
  final Map<_NotifKind, int> counts;
  final List<_NotifKind> kinds;
  final ValueChanged<_NotifKind> onTap;
  const _FilterBar({required this.current, required this.counts,
      required this.kinds, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (final k in kinds) ...[
          _Chip(
            label: _label(k),
            count: counts[k] ?? 0,
            color: _color(k),
            active: current == k,
            onTap: () => onTap(k),
          ),
          const SizedBox(width: 8),
        ],
      ]),
    );
  }

  String _label(_NotifKind k) => switch (k) {
        _NotifKind.grade        => 'Notes',
        _NotifKind.absence      => 'Présences',
        _NotifKind.payment      => 'Paiements',
      };

  Color _color(_NotifKind k) => switch (k) {
        _NotifKind.grade        => _gold,
        _NotifKind.absence      => _terra,
        _NotifKind.payment      => _orange,
      };
}

class _Chip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool active;
  final VoidCallback onTap;
  const _Chip({
    required this.label,
    required this.count,
    required this.color,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? color : border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
              style: TextStyle(
                  color: active ? Colors.white : muted,
                  fontSize: 12.5,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: active ? Colors.white.withValues(alpha: .25) : color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$count',
                  style: TextStyle(
                      color: active ? Colors.white : color,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800)),
            ),
          ],
        ]),
      ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Carte notification
// ══════════════════════════════════════════════════════════════════════════
class _NotifCard extends StatelessWidget {
  final _Notif notif;
  final VoidCallback onTap;
  const _NotifCard({required this.notif, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const tappable = true;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
      onTap: tappable ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: notif.color.withValues(alpha: .18)),
          boxShadow: [
            BoxShadow(
              color: notif.color.withValues(alpha: .05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: notif.color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(notif.icon, color: notif.color, size: 20),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: notif.color.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(notif.categoryLabel,
                      style: TextStyle(
                          color: notif.color, fontSize: 9.5, fontWeight: FontWeight.w800)),
                ),
                const Spacer(),
                if (notif.date != null)
                  Text(_relative(notif.date!),
                      style: const TextStyle(color: muted, fontSize: 10.5)),
              ]),
              const SizedBox(height: 6),
              Text(notif.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: ink, fontSize: 13.5, fontWeight: FontWeight.w700)),
              if (notif.body.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(notif.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: muted, fontSize: 12, height: 1.35)),
              ],
            ]),
          ),
          if (tappable) ...[
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded,
                color: muted.withValues(alpha: .5), size: 20),
          ],
        ]),
      ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// État vide
// ══════════════════════════════════════════════════════════════════════════
class _EmptyState extends StatelessWidget {
  final bool filtered;
  const _EmptyState({required this.filtered});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: _green.withValues(alpha: .08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.notifications_none_rounded,
                  color: _green, size: 34),
            ),
            const SizedBox(height: 14),
            Text(filtered ? 'Rien dans cette catégorie' : 'Tout est à jour',
                style: const TextStyle(
                    color: ink, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
                filtered
                    ? 'Essaie un autre filtre.'
                    : 'Tu seras notifié des nouvelles notes, absences et annonces.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: muted, fontSize: 13)),
          ]),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════════════
// Helpers date
// ══════════════════════════════════════════════════════════════════════════
String _relative(DateTime d) {
  final now = DateTime.now();
  final diff = now.difference(d);
  if (diff.inMinutes < 1) return "à l'instant";
  if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
  if (diff.inDays < 7) return 'il y a ${diff.inDays} j';
  return _formatDate(d);
}

String _formatDate(DateTime d) {
  const mois = [
    'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
    'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'
  ];
  return '${d.day} ${mois[d.month - 1]}';
}
