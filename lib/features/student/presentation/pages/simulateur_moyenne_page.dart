import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';

const _terra  = ScolarisPalette.terracotta;
const _gold   = ScolarisPalette.gold;
const _green  = ScolarisPalette.forestGreen;

// ── Matière avec coefficient ───────────────────────────────────────────────────
class _Matiere {
  final String nom;
  final int coeff;
  double? note;
  _Matiere({required this.nom, required this.coeff});
}

// ── Page principale ───────────────────────────────────────────────────────────
// Calculateur de moyenne pondérée. L'élève saisit ses propres matières,
// coefficients et notes — aucun preset codé en dur (l'ancien « Terminale EMI »
// n'était vrai que pour une série, et faux pour tous les autres). Les notes et
// la moyenne suivent le barème du cycle de l'élève (/10, /20, /100…).
class SimulateurMoyennePage extends ConsumerStatefulWidget {
  const SimulateurMoyennePage({super.key});
  @override
  ConsumerState<SimulateurMoyennePage> createState() =>
      _SimulateurMoyennePageState();
}

class _SimulateurMoyennePageState extends ConsumerState<SimulateurMoyennePage> {
  final _matieres = <_Matiere>[];

  double? _calcMoyenne(List<_Matiere> mats) {
    final valides = mats.where((m) => m.note != null).toList();
    if (valides.isEmpty) return null;
    final sumPond = valides.fold<double>(0, (s, m) => s + m.note! * m.coeff);
    final sumCoeff = valides.fold<int>(0, (s, m) => s + m.coeff);
    return sumPond / sumCoeff;
  }

  // Seuils sur le ratio 0→1 pour rester justes quel que soit le barème.
  Color _moyColor(double ratio) =>
      ratio >= 0.7 ? _green : ratio >= 0.5 ? _gold : _terra;
  String _mention(double ratio) {
    if (ratio >= 0.8) return 'Très Bien';
    if (ratio >= 0.7) return 'Bien';
    if (ratio >= 0.6) return 'Assez Bien';
    if (ratio >= 0.5) return 'Passable';
    return 'Insuffisant';
  }

  @override
  Widget build(BuildContext context) {
    final fmt = ref.watch(studentFormatProvider);
    final maxScore = fmt.maxScore;
    final isLetter = fmt.gradingScale == 'letter';
    final moyenne = _calcMoyenne(_matieres);
    final ratio = moyenne == null ? null : (moyenne / maxScore).clamp(0.0, 1.0);

    return PageScaffold(
      title: 'Simulateur de moyenne',
      subtitle: 'Calcule ta moyenne pondérée',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Résultat ────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: ratio == null
                  ? [const Color(0xFF2A1A00), const Color(0xFF4A2800)]
                  : [const Color(0xFF1A0500), _moyColor(ratio)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.calculate_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Moyenne calculée', style: TextStyle(color: Colors.white60, fontSize: 12)),
              const SizedBox(height: 4),
              moyenne == null
                  ? const Text('—', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900))
                  : Text(
                      isLetter
                          ? fmt.grade(moyenne)
                          : '${moyenne.toStringAsFixed(2)} / ${maxScore.toStringAsFixed(0)}',
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
              if (ratio != null) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_mention(ratio),
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
            ])),
            if (moyenne != null) ...[
              Column(children: [
                Text('${_matieres.where((m) => m.note != null).length}',
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                const Text('matières', style: TextStyle(color: Colors.white60, fontSize: 10)),
              ]),
            ],
          ]),
        ),
        const SizedBox(height: 16),

        // ── Bouton reset ────────────────────────────────────────────────────
        if (_matieres.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => setState(() { for (final m in _matieres) m.note = null; }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: context.cBorder),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.refresh_rounded, size: 13, color: context.cMuted),
                    const SizedBox(width: 5),
                    Text('Réinitialiser', style: TextStyle(fontSize: 11.5, color: context.cMuted, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
          ),
        if (_matieres.isNotEmpty) const SizedBox(height: 12),

        // ── Formulaire d'ajout ──────────────────────────────────────────────
        _AddMatiereForm(
          onAdd: (nom, coeff) {
            setState(() => _matieres.add(_Matiere(nom: nom, coeff: coeff)));
          },
        ),
        const SizedBox(height: 12),

        // ── Liste matières ──────────────────────────────────────────────────
        if (_matieres.isEmpty)
          const EmptyState(
            icon: Icons.add_circle_outline_rounded,
            title: 'Aucune matière',
            description: 'Ajoute tes matières avec le formulaire ci-dessus, saisis tes notes et coefficients pour estimer ta moyenne.',
          )
        else
          ..._matieres.asMap().entries.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _MatiereRow(
              mat: entry.value,
              maxScore: maxScore,
              onChanged: (v) => setState(() => entry.value.note = v),
              onDelete: () => setState(() => _matieres.removeAt(entry.key)),
            ),
          )),
      ]),
    );
  }
}

// ── Ligne matière ─────────────────────────────────────────────────────────────
class _MatiereRow extends StatefulWidget {
  final _Matiere mat;
  final double maxScore;
  final ValueChanged<double?> onChanged;
  final VoidCallback? onDelete;
  const _MatiereRow({
    required this.mat, required this.maxScore,
    required this.onChanged, this.onDelete,
  });
  @override
  State<_MatiereRow> createState() => _MatiereRowState();
}

class _MatiereRowState extends State<_MatiereRow> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: widget.mat.note?.toString() ?? '');
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Color get _noteColor {
    final n = widget.mat.note;
    if (n == null) return context.cMuted;
    final ratio = n / widget.maxScore;
    if (ratio >= 0.7) return const Color(0xFF1B5E20);
    if (ratio >= 0.5) return const Color(0xFFC17F24);
    return const Color(0xFF8B1A00);
  }

  @override
  Widget build(BuildContext context) {
    final maxLabel = widget.maxScore.toStringAsFixed(0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.cCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.cBorder),
      ),
      child: Row(children: [
        // Coefficient badge
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: _terra.withOpacity(.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(child: Text('×${widget.mat.coeff}',
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: _terra))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(widget.mat.nom,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.cInk))),
        // Input note
        SizedBox(
          width: 64,
          child: TextField(
            controller: _ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _noteColor),
            decoration: InputDecoration(
              hintText: '/$maxLabel',
              hintStyle: TextStyle(color: context.cMuted, fontSize: 12),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: context.cBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _terra, width: 1.5),
              ),
            ),
            onChanged: (v) {
              final d = double.tryParse(v);
              widget.onChanged(
                  d != null && d >= 0 && d <= widget.maxScore ? d : null);
            },
          ),
        ),
        if (widget.onDelete != null) ...[
          const SizedBox(width: 8),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: widget.onDelete,
              child: Icon(Icons.close_rounded, size: 18, color: context.cMuted),
            ),
          ),
        ],
      ]),
    );
  }
}

// ── Formulaire ajout matière ──────────────────────────────────────────────────
class _AddMatiereForm extends StatefulWidget {
  final void Function(String nom, int coeff) onAdd;
  const _AddMatiereForm({required this.onAdd});
  @override
  State<_AddMatiereForm> createState() => _AddMatiereFormState();
}

class _AddMatiereFormState extends State<_AddMatiereForm> {
  final _nomCtrl = TextEditingController();
  int _coeff = 1;

  @override
  void dispose() { _nomCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _terra.withOpacity(.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _terra.withOpacity(.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Ajouter une matière',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _terra)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _nomCtrl,
              style: TextStyle(fontSize: 13, color: context.cInk),
              decoration: InputDecoration(
                hintText: 'Nom de la matière',
                hintStyle: TextStyle(color: context.cMuted, fontSize: 13),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: context.cBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _terra, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Coefficient stepper
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: context.cBorder),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              _StepBtn(icon: Icons.remove, onTap: () { if (_coeff > 1) setState(() => _coeff--); }),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('×$_coeff', style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800, color: context.cInk)),
              ),
              _StepBtn(icon: Icons.add, onTap: () { if (_coeff < 20) setState(() => _coeff++); }),
            ]),
          ),
          const SizedBox(width: 10),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                if (_nomCtrl.text.trim().isNotEmpty) {
                  widget.onAdd(_nomCtrl.text.trim(), _coeff);
                  _nomCtrl.clear();
                  setState(() => _coeff = 1);
                }
              },
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: _terra,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    child: GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 32, height: 42,
        child: Icon(icon, size: 16, color: context.cMuted),
      ),
    ),
  );
}
