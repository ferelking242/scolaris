import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/auth_providers.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';

const _terra  = ScolarisPalette.terracotta;
const _gold   = ScolarisPalette.gold;
const _green  = ScolarisPalette.forestGreen;

// ── Type de note : couleur + libellé ──────────────────────────────────────────
_NoteType _typeInfo(String? type) {
  if (type == null) return const _NoteType('—', Color(0xFF9E9E9E));
  final t = type.toLowerCase();
  if (t.contains('devoir'))        return const _NoteType('Devoir',       Color(0xFF1565C0));
  if (t.contains('compos'))        return const _NoteType('Composition',  Color(0xFF6A1B9A));
  if (t.contains('session'))       return const _NoteType('Session',      Color(0xFF00695C));
  if (t.contains('exam'))          return const _NoteType('Examen',       Color(0xFF6A1B9A));
  if (t.contains('interro') || t.contains('interrogation'))
                                   return const _NoteType('Interrogation',Color(0xFF0288D1));
  if (t.contains('contrôle') || t.contains('controle'))
                                   return const _NoteType('Contrôle',     Color(0xFF00838F));
  if (t.contains('tp'))            return const _NoteType('TP',           Color(0xFF2E7D32));
  if (t.contains('projet'))        return const _NoteType('Projet',       Color(0xFFE65100));
  if (t.contains('pratique'))      return const _NoteType('Pratique',     Color(0xFF558B2F));
  if (t.contains('rédac') || t.contains('redac'))
                                   return const _NoteType('Rédaction',    Color(0xFF6D4C41));
  if (t.contains('dissert'))       return const _NoteType('Dissertation', Color(0xFF4527A0));
  if (t.contains('express'))       return const _NoteType('Expression',   Color(0xFF00695C));
  return _NoteType(type, const Color(0xFF616161));
}

class _NoteType {
  final String label;
  final Color color;
  const _NoteType(this.label, this.color);
}

// ── Page principale ───────────────────────────────────────────────────────────
class GradesPage extends ConsumerWidget {
  const GradesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);
    final gradesAsync = session != null
        ? ref.watch(gradesForStudentProvider(session.id))
        : const AsyncValue<List<SbGrade>>.data([]);

    return gradesAsync.when(
      loading: () => const PageScaffold(
        title: 'Mes notes',
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => PageScaffold(
        title: 'Mes notes',
        child: Center(child: Text('Erreur : $e')),
      ),
      data: (grades) {
        final avg = grades.isEmpty
            ? 0.0
            : grades.fold<double>(0, (s, g) => s + g.outOf20) / grades.length;
        final best = grades.isEmpty
            ? null
            : grades.reduce((a, b) => a.outOf20 >= b.outOf20 ? a : b);

        return PageScaffold(
          title: 'Mes notes',
          subtitle: '${grades.isEmpty ? "Aucun" : grades.length} résultat(s)',
          actions: [
            ActionButton(
                label: 'Export PDF',
                icon: Icons.picture_as_pdf_rounded,
                onTap: () => _exportPdf(context, grades)),
          ],
          child: grades.isEmpty
              ? const _EmptyGrades()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IntrinsicHeight(
                      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Expanded(child: _MetricCard(
                          label: 'Moyenne générale',
                          value: avg.toStringAsFixed(1),
                          unit: '/ 20',
                          color: avg >= 14 ? _green : avg >= 10 ? _gold : _terra,
                          icon: Icons.grading_rounded,
                        )),
                        const SizedBox(width: 10),
                        Expanded(child: _MetricCard(
                          label: 'Meilleure matière',
                          value: best?.subjectName?.split(' ').first ?? '—',
                          unit: best != null
                              ? '${best.outOf20.toStringAsFixed(1)}/20'
                              : '',
                          color: _green,
                          icon: Icons.emoji_events_rounded,
                        )),
                        const SizedBox(width: 10),
                        Expanded(child: _MetricCard(
                          label: 'Notes enregistrées',
                          value: '${grades.length}',
                          unit: 'total',
                          color: _terra,
                          icon: Icons.format_list_numbered_rounded,
                        )),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    _GradesList(grades: grades),
                  ],
                ),
        );
      },
    );
  }

  void _exportPdf(BuildContext context, List<SbGrade> grades) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(children: [
          Icon(Icons.info_outline_rounded, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Text('Export PDF — disponible prochainement'),
        ]),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// ── Notes mock EMI — Ferel Ondongo (affichées si Supabase vide) ───────────────
const _mockEmiGrades = [
  (sub: 'Mathématiques',      type: 'Devoir',       period: 'T2', score: 17.5, max: 20.0, date: '14 Jun'),
  (sub: 'Sciences Physiques', type: 'Interrogation', period: 'T2', score: 15.0, max: 20.0, date: '11 Jun'),
  (sub: 'Électronique',       type: 'TP',            period: 'T2', score: 16.5, max: 20.0, date: '06 Jun'),
  (sub: 'Algorithmique',      type: 'Devoir',        period: 'T2', score: 18.0, max: 20.0, date: '03 Jun'),
  (sub: 'Chimie',             type: 'Interrogation', period: 'T2', score: 13.5, max: 20.0, date: '28 Mai'),
  (sub: 'Français',           type: 'Rédaction',     period: 'T2', score: 14.0, max: 20.0, date: '25 Mai'),
  (sub: 'Philosophie',        type: 'Dissertation',  period: 'T2', score: 15.5, max: 20.0, date: '20 Mai'),
  (sub: 'Anglais',            type: 'Expression',    period: 'T2', score: 16.0, max: 20.0, date: '16 Mai'),
  (sub: 'Mathématiques',      type: 'Contrôle',      period: 'T1', score: 16.0, max: 20.0, date: '12 Avr'),
  (sub: 'Sciences Physiques', type: 'TP',            period: 'T1', score: 14.5, max: 20.0, date: '08 Avr'),
  (sub: 'Électronique',       type: 'Contrôle',      period: 'T1', score: 15.0, max: 20.0, date: '02 Avr'),
  (sub: 'Algorithmique',      type: 'Projet',        period: 'T1', score: 19.0, max: 20.0, date: '25 Mar'),
  (sub: 'Histoire-Géo',       type: 'Devoir',        period: 'T1', score: 13.0, max: 20.0, date: '18 Mar'),
  (sub: 'Chimie',             type: 'TP',            period: 'T1', score: 14.0, max: 20.0, date: '10 Mar'),
  (sub: 'EPS',                type: 'Pratique',      period: 'T1', score: 17.0, max: 20.0, date: '05 Mar'),
];

// ── Etat vide — données mock EMI ──────────────────────────────────────────────
class _EmptyGrades extends StatelessWidget {
  const _EmptyGrades();

  @override
  Widget build(BuildContext context) {
    final avg = _mockEmiGrades.fold<double>(0, (s, g) => s + g.score) /
        _mockEmiGrades.length;
    final best = _mockEmiGrades.reduce((a, b) => a.score >= b.score ? a : b);
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Banner EMI
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF0F766E), Color(0xFF059669)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .2),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.precision_manufacturing_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Ferel Ondongo — Filière EMI',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
              Text('Terminale · Électronique, Math & Informatique',
                  style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 10.5)),
            ])),
          ]),
        ),
        // Métriques
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: _MetricCard(
                label: 'Moyenne générale', value: avg.toStringAsFixed(1),
                unit: '/ 20', icon: Icons.grading_rounded,
                color: avg >= 14 ? _green : avg >= 10 ? _gold : _terra)),
            const SizedBox(width: 10),
            Expanded(child: _MetricCard(
                label: 'Meilleure matière', value: best.sub.split(' ').first,
                unit: '${best.score.toStringAsFixed(1)}/20', icon: Icons.emoji_events_rounded,
                color: _green)),
            const SizedBox(width: 10),
            Expanded(child: _MetricCard(
                label: 'Notes enregistrées', value: '${_mockEmiGrades.length}',
                unit: 'total', icon: Icons.format_list_numbered_rounded,
                color: _terra)),
          ]),
        ),
        const SizedBox(height: 16),
        // Liste
        _MockGradesList(),
      ],
    );
  }
}

// ── Type badge widget ─────────────────────────────────────────────────────────
class _TypeBadge extends StatelessWidget {
  final String? type;
  const _TypeBadge(this.type);

  @override
  Widget build(BuildContext context) {
    final info = _typeInfo(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: info.color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: info.color.withValues(alpha: .3)),
      ),
      child: Text(info.label,
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: info.color)),
    );
  }
}

// ── Liste mock ────────────────────────────────────────────────────────────────
class _MockGradesList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DataPanel(
      title: 'Toutes les notes — EMI',
      child: DataTablePanel(
        columns: const ['Matière', 'Type', 'Pér.', 'Note', '/Max'],
        flex: const [3, 2, 1, 2, 1],
        rows: [
          for (final g in _mockEmiGrades)
            [
              Text(g.sub, style: TextStyle(
                  color: cs.onSurface, fontSize: 12.5, fontWeight: FontWeight.w600)),
              _TypeBadge(g.type),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: g.period == 'T2'
                      ? const Color(0xFF0891B2).withValues(alpha: .10)
                      : const Color(0xFFC17F24).withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(g.period, style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: g.period == 'T2'
                        ? const Color(0xFF0891B2)
                        : const Color(0xFFC17F24))),
              ),
              Text(
                g.score.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w900,
                  color: g.score / g.max >= 0.7 ? _green
                      : g.score / g.max >= 0.5 ? _gold
                      : _terra,
                ),
              ),
              Text(g.max.toStringAsFixed(0),
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ],
        ],
      ),
    );
  }
}

// ── Liste réelle ──────────────────────────────────────────────────────────────
class _GradesList extends StatelessWidget {
  final List<SbGrade> grades;
  const _GradesList({required this.grades});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DataPanel(
      title: 'Toutes les notes',
      child: DataTablePanel(
        columns: const ['Matière', 'Type', 'Pér.', 'Note', '/Max'],
        flex: const [3, 2, 1, 2, 1],
        rows: [
          for (final g in grades)
            [
              Text(g.subjectName ?? g.title ?? '—',
                  style: TextStyle(
                      color: cs.onSurface, fontSize: 12.5, fontWeight: FontWeight.w600)),
              _TypeBadge(g.type),
              Text(g.period ?? '—',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              Text(
                g.score.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: g.outOf20 >= 14
                      ? _green
                      : g.outOf20 >= 10
                          ? _gold
                          : _terra,
                ),
              ),
              Text(g.maxScore.toStringAsFixed(0),
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ],
        ],
      ),
    );
  }
}

// ── Carte métrique ────────────────────────────────────────────────────────────
class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;
  final IconData icon;
  const _MetricCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: .25)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: .07),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(height: 10),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color, height: 1)),
        ),
        if (unit.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(unit,
              style: TextStyle(fontSize: 10.5, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
        ],
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(fontSize: 10.5, color: cs.onSurfaceVariant),
            maxLines: 2, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}
