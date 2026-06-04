import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

const _terra = ScolarisPalette.terracotta;
const _green = ScolarisPalette.forestGreen;
const _gold  = ScolarisPalette.gold;
const _white = Colors.white;

// ── Modèles ───────────────────────────────────────────────────────────────────
class _BulletinRow {
  final String matiere;
  final int coef;
  final double s1;
  final double s2;
  final String appreciation;
  const _BulletinRow({
    required this.matiere,
    required this.coef,
    required this.s1,
    required this.s2,
    required this.appreciation,
  });
  double moyennePonderee(bool isS1) => (isS1 ? s1 : s2) * coef;
}

const _bulletinTleC = [
  _BulletinRow(matiere: 'Mathématiques',     coef: 7, s1: 16.5, s2: 17.2, appreciation: 'Très bon travail, continuez ainsi'),
  _BulletinRow(matiere: 'Sciences Physiques',coef: 6, s1: 14.0, s2: 15.5, appreciation: 'Des progrès notables ce semestre'),
  _BulletinRow(matiere: 'SVT',               coef: 5, s1: 15.0, s2: 14.8, appreciation: 'Bon niveau, attention aux schémas'),
  _BulletinRow(matiere: 'Français',          coef: 4, s1: 12.5, s2: 13.0, appreciation: 'Doit approfondir l\'analyse littéraire'),
  _BulletinRow(matiere: 'Philosophie',       coef: 3, s1: 14.0, s2: 15.0, appreciation: 'Excellent sens de l\'argumentation'),
  _BulletinRow(matiere: 'Histoire-Géo',      coef: 3, s1: 13.5, s2: 14.5, appreciation: 'Bonne maîtrise des faits historiques'),
  _BulletinRow(matiere: 'Anglais',           coef: 3, s1: 12.0, s2: 13.0, appreciation: 'Efforts à faire à l\'écrit'),
  _BulletinRow(matiere: 'EPS',               coef: 2, s1: 17.0, s2: 16.5, appreciation: 'Excellent comportement sportif'),
];

double _calcMoyenne(List<_BulletinRow> rows, bool s1) {
  final totalPts  = rows.fold<double>(0, (a, r) => a + r.moyennePonderee(s1));
  final totalCoef = rows.fold<int>(0, (a, r) => a + r.coef);
  return totalPts / totalCoef;
}

String _mention(double moy) {
  if (moy >= 16) return 'Très Bien';
  if (moy >= 14) return 'Bien';
  if (moy >= 12) return 'Assez Bien';
  if (moy >= 10) return 'Passable';
  return 'Insuffisant';
}

Color _mentionColor(double moy) {
  if (moy >= 16) return ScolarisPalette.forestGreen;
  if (moy >= 14) return const Color(0xFF0EA5E9);
  if (moy >= 12) return ScolarisPalette.gold;
  if (moy >= 10) return ScolarisPalette.orange;
  return ScolarisPalette.terracotta;
}

// ── Page ──────────────────────────────────────────────────────────────────────
class BulletinPage extends StatefulWidget {
  const BulletinPage({super.key});
  @override
  State<BulletinPage> createState() => _BulletinPageState();
}

class _BulletinPageState extends State<BulletinPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  bool get _isS1 => _tab.index == 0;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this)
      ..addListener(() => setState(() {}));
  }
  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final rows   = _bulletinTleC;
    final moy    = _calcMoyenne(rows, _isS1);
    final mention = _mention(moy);
    final mColor  = _mentionColor(moy);

    return Container(
      color: cs.surfaceContainerLow,
      child: Column(children: [
        _BulletinHeader(tab: _tab),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _StudentInfoCard(isS1: _isS1),
              const SizedBox(height: 14),
              _GradesTable(rows: rows, isS1: _isS1),
              const SizedBox(height: 14),
              _SummaryCard(moyenne: moy, mention: mention, mColor: mColor, isS1: _isS1),
              const SizedBox(height: 14),
              _CouncilCard(isS1: _isS1),
              const SizedBox(height: 14),
              const _PrintBtn(),
              const SizedBox(height: 40),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ── Header + tabs ─────────────────────────────────────────────────────────────
class _BulletinHeader extends StatelessWidget {
  final TabController tab;
  const _BulletinHeader({required this.tab});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surface,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF1A0A00), Color(0xFF8B1A00)]),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Center(child: Icon(Icons.receipt_long_rounded, color: _white, size: 20)),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Bulletins Scolaires',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                      color: cs.onSurface)),
              Text('Complexe Scolaire Saint-Gabriel · Tle C',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ]),
          ]),
        ),
        TabBar(
          controller: tab,
          labelColor: _terra,
          unselectedLabelColor: cs.onSurfaceVariant,
          indicatorColor: _terra,
          indicatorWeight: 2.5,
          dividerColor: cs.outline.withValues(alpha: 0.2),
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          tabs: const [Tab(text: 'Semestre 1'), Tab(text: 'Semestre 2')],
        ),
      ]),
    );
  }
}

// ── Student info ──────────────────────────────────────────────────────────────
class _StudentInfoCard extends StatelessWidget {
  final bool isS1;
  const _StudentInfoCard({required this.isS1});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1A0A00), _terra]),
              shape: BoxShape.circle,
            ),
            child: const Center(child: Text('JM', style: TextStyle(
                color: _white, fontSize: 16, fontWeight: FontWeight.w900))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Junior Mafoua', style: TextStyle(
                color: cs.onSurface, fontSize: 15, fontWeight: FontWeight.w800)),
            Text('Tle C · Saint-Gabriel · ${isS1 ? "Sem. 1" : "Sem. 2"} 2025–2026',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11.5)),
          ])),
        ]),
        const SizedBox(height: 12),
        Divider(height: 1, color: cs.outline.withValues(alpha: 0.2)),
        const SizedBox(height: 10),
        Row(children: [
          _InfoPill('N° Matricule', 'SG-LYC-001'),
          const SizedBox(width: 8),
          _InfoPill('Classe', 'Tle C'),
          const SizedBox(width: 8),
          _InfoPill('Rang', '2e / 32'),
        ]),
      ]),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String label;
  final String value;
  const _InfoPill(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w600)),
        const SizedBox(height: 3),
        Text(value, style: TextStyle(fontSize: 12.5, color: cs.onSurface,
            fontWeight: FontWeight.w800)),
      ]),
    ));
  }
}

// ── Grades table ──────────────────────────────────────────────────────────────
class _GradesTable extends StatelessWidget {
  final List<_BulletinRow> rows;
  final bool isS1;
  const _GradesTable({required this.rows, required this.isS1});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1A0A00),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
          ),
          child: const Row(children: [
            Expanded(flex: 5, child: Text('Matière',
                style: TextStyle(color: _white, fontSize: 12, fontWeight: FontWeight.w700))),
            Expanded(flex: 1, child: Text('C',
                style: TextStyle(color: _white, fontSize: 12, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center)),
            Expanded(flex: 2, child: Text('Note/20',
                style: TextStyle(color: _white, fontSize: 12, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center)),
          ]),
        ),
        // Rows
        ...rows.asMap().entries.map((e) {
          final i = e.key;
          final r = e.value;
          final note = isS1 ? r.s1 : r.s2;
          final isEven = i % 2 == 0;
          final noteColor = note >= 14 ? _green : note >= 10
              ? ScolarisPalette.orange : _terra;
          return Container(
            color: isEven
                ? cs.surfaceContainerHighest.withValues(alpha: 0.35)
                : cs.surface,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(flex: 5, child: Text(r.matiere, style: TextStyle(
                    color: cs.onSurface, fontSize: 13, fontWeight: FontWeight.w600))),
                Expanded(flex: 1, child: Center(child: Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                      color: _terra.withValues(alpha: .1), shape: BoxShape.circle),
                  child: Center(child: Text('${r.coef}', style: TextStyle(
                      color: _terra, fontSize: 10, fontWeight: FontWeight.w800))),
                ))),
                Expanded(flex: 2, child: Center(child: Text(
                  note.toStringAsFixed(1),
                  style: TextStyle(color: noteColor, fontSize: 14,
                      fontWeight: FontWeight.w800),
                ))),
              ]),
              const SizedBox(height: 2),
              Text(r.appreciation, style: TextStyle(
                  fontSize: 10.5, color: cs.onSurfaceVariant,
                  fontStyle: FontStyle.italic)),
            ]),
          );
        }),
        Divider(height: 1, color: cs.outline.withValues(alpha: 0.2)),
        // Total row
        Builder(builder: (_) {
          final totalCoef = rows.fold<int>(0, (a, r) => a + r.coef);
          final moyenne   = _calcMoyenne(rows, isS1);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.25),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(13)),
            ),
            child: Row(children: [
              Expanded(flex: 5, child: Text('Moyenne Générale',
                  style: TextStyle(color: cs.onSurface, fontSize: 13,
                      fontWeight: FontWeight.w800))),
              Expanded(flex: 1, child: Center(child: Text('$totalCoef',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11,
                      fontWeight: FontWeight.w700)))),
              Expanded(flex: 2, child: Center(child: Text(moyenne.toStringAsFixed(2),
                  style: const TextStyle(color: _terra, fontSize: 16,
                      fontWeight: FontWeight.w900)))),
            ]),
          );
        }),
      ]),
    );
  }
}

// ── Summary card ──────────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final double moyenne;
  final String mention;
  final Color mColor;
  final bool isS1;
  const _SummaryCard({
    required this.moyenne, required this.mention,
    required this.mColor,  required this.isS1,
  });
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [mColor.withValues(alpha: .10), mColor.withValues(alpha: .03)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: mColor.withValues(alpha: .25)),
      ),
      child: Row(children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
              color: mColor.withValues(alpha: .15), shape: BoxShape.circle),
          child: Center(child: Text(moyenne.toStringAsFixed(2),
              style: TextStyle(color: mColor, fontSize: 16,
                  fontWeight: FontWeight.w900))),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Mention : $mention',
              style: TextStyle(color: mColor, fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(isS1 ? 'Semestre 1 · Rang : 2e/32' : 'Semestre 2 · Rang : 2e/32',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: moyenne / 20,
              backgroundColor: mColor.withValues(alpha: .1),
              valueColor: AlwaysStoppedAnimation<Color>(mColor),
              minHeight: 5,
            ),
          ),
        ])),
      ]),
    );
  }
}

// ── Council card ──────────────────────────────────────────────────────────────
class _CouncilCard extends StatelessWidget {
  final bool isS1;
  const _CouncilCard({required this.isS1});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = isS1
        ? 'Excellent trimestre pour Junior. Il fait preuve d\'une grande rigueur en mathématiques et sciences. Encouragé à maintenir cet effort au semestre 2.'
        : 'Semestre remarquable. Junior confirme son potentiel scientifique. Il est fortement encouragé à poursuivre en classe préparatoire ou en licence scientifique.';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.groups_2_rounded, size: 18, color: _gold),
          const SizedBox(width: 8),
          Text('Appréciation du Conseil de Classe',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                  color: cs.onSurface)),
        ]),
        const SizedBox(height: 10),
        Text(text, style: TextStyle(color: cs.onSurfaceVariant,
            fontSize: 12.5, height: 1.6, fontStyle: FontStyle.italic)),
        const SizedBox(height: 10),
        Row(children: [
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('M. Ngakosso Jean-Pierre', style: TextStyle(
                color: cs.onSurface, fontSize: 11, fontWeight: FontWeight.w700)),
            Text('Professeur Principal · Tle C',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 10.5)),
          ]),
        ]),
      ]),
    );
  }
}

// ── Print button ──────────────────────────────────────────────────────────────
class _PrintBtn extends StatelessWidget {
  const _PrintBtn();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: _green,
              content: const Row(children: [
                Icon(Icons.download_done_rounded, color: _white, size: 18),
                SizedBox(width: 10),
                Text('Bulletin téléchargé en PDF',
                    style: TextStyle(color: _white, fontWeight: FontWeight.w600)),
              ]),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        },
        icon: const Icon(Icons.download_rounded, size: 18),
        label: const Text('Télécharger le bulletin (PDF)',
            style: TextStyle(fontWeight: FontWeight.w700)),
        style: FilledButton.styleFrom(
          backgroundColor: _terra,
          foregroundColor: _white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
