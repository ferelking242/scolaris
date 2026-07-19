import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/page_scaffold.dart';

const _terra  = ScolarisPalette.terracotta;
const _gold   = ScolarisPalette.gold;
const _green  = ScolarisPalette.forestGreen;
const _ink    = Color(0xFF1A0A00);
const _muted  = Color(0xFF7A5C44);
const _border = Color(0xFFDDCCBB);
const _white  = Colors.white;
const _bg     = Color(0xFFF5EEE6);

// ── Data ──────────────────────────────────────────────────────────────────────
class _UE {
  final String code;
  final String nom;
  final int credits;
  final double note;
  final String statut; // 'validée' | 'en_cours' | 'non_validée'
  final String semestre;
  const _UE({
    required this.code, required this.nom, required this.credits,
    required this.note, required this.statut, required this.semestre,
  });

  double get outOf20 => note;
  bool get validee => statut == 'validée';
}

const _ues = [
  // Semestre 1
  _UE(code: 'MAT101', nom: 'Analyse mathématique I', credits: 6, note: 14.5, statut: 'validée', semestre: 'S1'),
  _UE(code: 'INFO101', nom: 'Introduction à l\'informatique', credits: 6, note: 16.0, statut: 'validée', semestre: 'S1'),
  _UE(code: 'PHY101', nom: 'Physique générale I', credits: 5, note: 12.5, statut: 'validée', semestre: 'S1'),
  _UE(code: 'LNG101', nom: 'Anglais académique', credits: 3, note: 13.0, statut: 'validée', semestre: 'S1'),
  _UE(code: 'STA101', nom: 'Statistiques descriptives', credits: 4, note: 11.0, statut: 'validée', semestre: 'S1'),
  _UE(code: 'COM101', nom: 'Communication professionnelle', credits: 2, note: 15.0, statut: 'validée', semestre: 'S1'),
  // Semestre 2
  _UE(code: 'MAT201', nom: 'Analyse mathématique II', credits: 6, note: 13.5, statut: 'validée', semestre: 'S2'),
  _UE(code: 'INFO201', nom: 'Algorithmes et structures de données', credits: 6, note: 17.0, statut: 'validée', semestre: 'S2'),
  _UE(code: 'PHY201', nom: 'Physique générale II', credits: 5, note: 10.5, statut: 'validée', semestre: 'S2'),
  _UE(code: 'BD201', nom: 'Bases de données relationnelles', credits: 4, note: 15.5, statut: 'validée', semestre: 'S2'),
  _UE(code: 'STA201', nom: 'Probabilités', credits: 3, note: 9.0, statut: 'non_validée', semestre: 'S2'),
  // Semestre 3 (en cours)
  _UE(code: 'RES301', nom: 'Réseaux et systèmes', credits: 6, note: 0, statut: 'en_cours', semestre: 'S3'),
  _UE(code: 'WEB301', nom: 'Développement web avancé', credits: 5, note: 0, statut: 'en_cours', semestre: 'S3'),
  _UE(code: 'MAT301', nom: 'Mathématiques discrètes', credits: 5, note: 0, statut: 'en_cours', semestre: 'S3'),
  _UE(code: 'PRJ301', nom: 'Projet tutoré', credits: 4, note: 0, statut: 'en_cours', semestre: 'S3'),
];

// ── Page principale ───────────────────────────────────────────────────────────
class ReleveEctsPage extends StatefulWidget {
  const ReleveEctsPage({super.key});
  @override
  State<ReleveEctsPage> createState() => _ReleveEctsPageState();
}

class _ReleveEctsPageState extends State<ReleveEctsPage> {
  String _sem = 'Tous';

  List<String> get _semestres => ['Tous', ..._ues.map((u) => u.semestre).toSet().toList()..sort()];
  List<_UE> get _filtered => _ues.where((u) => _sem == 'Tous' || u.semestre == _sem).toList();

  int get _totalCredits => _ues.where((u) => u.validee).fold(0, (s, u) => s + u.credits);
  int get _maxCredits => _ues.fold(0, (s, u) => s + u.credits);
  double get _moyenne {
    final valides = _ues.where((u) => u.validee).toList();
    if (valides.isEmpty) return 0;
    final sp = valides.fold<double>(0, (s, u) => s + u.note * u.credits);
    final sc = valides.fold<int>(0, (s, u) => s + u.credits);
    return sp / sc;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final sems = _semestres;

    return PageScaffold(
      title: 'Relevé de notes ECTS',
      subtitle: 'Bilan académique universitaire',
      actions: [
        ActionButton(
          label: 'PDF',
          icon: Icons.picture_as_pdf_rounded,
          onTap: () => _showSnack(context),
        ),
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Bilan global ────────────────────────────────────────────────────
        Row(children: [
          Expanded(child: _StatCard(
            label: 'Crédits validés',
            value: '$_totalCredits / $_maxCredits',
            color: _green,
            icon: Icons.check_circle_rounded,
          )),
          const SizedBox(width: 10),
          Expanded(child: _StatCard(
            label: 'Moyenne générale',
            value: '${_moyenne.toStringAsFixed(2)} /20',
            color: _terra,
            icon: Icons.grading_rounded,
          )),
          const SizedBox(width: 10),
          Expanded(child: _StatCard(
            label: 'Semestres validés',
            value: '2 / 3',
            color: _gold,
            icon: Icons.school_rounded,
          )),
        ]),
        const SizedBox(height: 14),

        // ── Barre de progression crédits ───────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Progression de la licence',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _ink)),
              Text('$_totalCredits / 180 ECTS',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _terra)),
            ]),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _totalCredits / 180,
                backgroundColor: _border.withOpacity(.4),
                valueColor: const AlwaysStoppedAnimation(_terra),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 6),
            Text('${((_totalCredits / 180) * 100).round()} % de la licence complétés',
                style: const TextStyle(fontSize: 11, color: _muted)),
          ]),
        ),
        const SizedBox(height: 14),

        // ── Filtre semestre ─────────────────────────────────────────────────
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: sems.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, i) {
              final s = sems[i];
              final sel = s == _sem;
              return MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => setState(() => _sem = s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: sel ? _terra : _white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: sel ? _terra : _border),
                    ),
                    child: Text(s,
                        style: TextStyle(
                            color: sel ? _white : _muted,
                            fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),

        // ── Liste UEs ───────────────────────────────────────────────────────
        ...filtered.map((ue) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _UECard(ue: ue),
        )),
      ]),
    );
  }

  void _showSnack(BuildContext ctx) => ScaffoldMessenger.of(ctx).showSnackBar(
    SnackBar(
      content: const Text('Export PDF — disponible prochainement'),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}

// ── Carte UE ──────────────────────────────────────────────────────────────────
class _UECard extends StatelessWidget {
  final _UE ue;
  const _UECard({required this.ue});

  Color get _statusColor {
    switch (ue.statut) {
      case 'validée': return _green;
      case 'non_validée': return _terra;
      default: return _gold;
    }
  }

  String get _statusLabel {
    switch (ue.statut) {
      case 'validée': return 'Validée';
      case 'non_validée': return 'Non validée';
      default: return 'En cours';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Crédits
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: _statusColor.withOpacity(.1),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('${ue.credits}', style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w900, color: _statusColor)),
            Text('ECTS', style: TextStyle(fontSize: 8, color: _statusColor.withOpacity(.7), fontWeight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(ue.code, style: const TextStyle(
                  fontSize: 9.5, fontWeight: FontWeight.w700, color: _muted)),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: _gold.withOpacity(.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(ue.semestre, style: const TextStyle(
                  fontSize: 9.5, fontWeight: FontWeight.w700, color: _gold)),
            ),
          ]),
          const SizedBox(height: 4),
          Text(ue.nom, style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
          const SizedBox(height: 4),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(_statusLabel, style: TextStyle(
                  fontSize: 10.5, fontWeight: FontWeight.w700, color: _statusColor)),
            ),
          ]),
        ])),
        if (ue.statut != 'en_cours')
          Text(ue.note.toStringAsFixed(1),
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w900,
                  color: ue.validee ? _green : _terra)),
      ]),
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  const _StatCard({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w900, color: color)),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: _muted),
            maxLines: 2, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}
