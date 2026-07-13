import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/page_scaffold.dart';

const _terra  = ScolarisPalette.terracotta;
const _gold   = ScolarisPalette.gold;
const _green  = ScolarisPalette.forestGreen;

// ── Matière avec coefficient ───────────────────────────────────────────────────
class _Matiere {
  final String nom;
  final int coeff;
  double? note;
  _Matiere({required this.nom, required this.coeff, this.note});
}

// ── Page principale ───────────────────────────────────────────────────────────
class SimulateurMoyennePage extends StatefulWidget {
  const SimulateurMoyennePage({super.key});
  @override
  State<SimulateurMoyennePage> createState() => _SimulateurMoyennePageState();
}

class _SimulateurMoyennePageState extends State<SimulateurMoyennePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  final _matieresBac = [
    _Matiere(nom: 'Mathématiques',       coeff: 7),
    _Matiere(nom: 'Sciences Physiques',  coeff: 6),
    _Matiere(nom: 'Chimie',              coeff: 4),
    _Matiere(nom: 'Algorithmique',       coeff: 4),
    _Matiere(nom: 'Électronique',        coeff: 4),
    _Matiere(nom: 'Français',            coeff: 3),
    _Matiere(nom: 'Anglais',             coeff: 2),
    _Matiere(nom: 'Histoire-Géo',        coeff: 2),
    _Matiere(nom: 'Philosophie',         coeff: 2),
    _Matiere(nom: 'EPS',                 coeff: 1),
  ];

  final _matieresLibre = <_Matiere>[];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  double? _calcMoyenne(List<_Matiere> mats) {
    final valides = mats.where((m) => m.note != null).toList();
    if (valides.isEmpty) return null;
    final sumPond = valides.fold<double>(0, (s, m) => s + m.note! * m.coeff);
    final sumCoeff = valides.fold<int>(0, (s, m) => s + m.coeff);
    return sumPond / sumCoeff;
  }

  Color _moyColor(double m) => m >= 14 ? _green : m >= 10 ? _gold : _terra;
  String _mention(double m) {
    if (m >= 16) return 'Très Bien';
    if (m >= 14) return 'Bien';
    if (m >= 12) return 'Assez Bien';
    if (m >= 10) return 'Passable';
    return 'Insuffisant';
  }

  @override
  Widget build(BuildContext context) {
    final mats = _tab.index == 0 ? _matieresBac : _matieresLibre;
    final moyenne = _calcMoyenne(mats);

    return PageScaffold(
      title: 'Simulateur de moyenne',
      subtitle: 'Calcule ta moyenne pondérée',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Tabs ────────────────────────────────────────────────────────────
        Container(
          height: 42,
          decoration: BoxDecoration(
            color: context.cBorder.withOpacity(.3),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(4),
          child: TabBar(
            controller: _tab,
            indicator: BoxDecoration(
              color: context.cCard,
              borderRadius: BorderRadius.circular(9),
              boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 4)],
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: _terra,
            unselectedLabelColor: context.cMuted,
            labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            unselectedLabelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
            tabs: const [Tab(text: 'Terminale EMI'), Tab(text: 'Personnalisé')],
          ),
        ),
        const SizedBox(height: 16),

        // ── Résultat ────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: moyenne == null
                  ? [const Color(0xFF2A1A00), const Color(0xFF4A2800)]
                  : [const Color(0xFF1A0500), _moyColor(moyenne)],
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
                  : Text('${moyenne.toStringAsFixed(2)} / 20',
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
              if (moyenne != null) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_mention(moyenne),
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
            ])),
            if (moyenne != null) ...[
              Column(children: [
                Text('${mats.where((m) => m.note != null).length}',
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                const Text('matières', style: TextStyle(color: Colors.white60, fontSize: 10)),
              ]),
            ],
          ]),
        ),
        const SizedBox(height: 16),

        // ── Bouton reset ────────────────────────────────────────────────────
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () => setState(() { for (final m in mats) m.note = null; }),
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
        const SizedBox(height: 12),

        // ── Formulaire d'ajout (onglet personnalisé) ─────────────────────────
        if (_tab.index == 1) ...[
          _AddMatiereForm(
            onAdd: (nom, coeff) {
              setState(() => _matieresLibre.add(_Matiere(nom: nom, coeff: coeff)));
            },
          ),
          const SizedBox(height: 12),
        ],

        // ── Liste matières ──────────────────────────────────────────────────
        if (mats.isEmpty)
          const EmptyState(
            icon: Icons.add_circle_outline_rounded,
            title: 'Aucune matière',
            description: 'Ajoutez des matières avec le formulaire ci-dessus.',
          )
        else
          ...mats.asMap().entries.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _MatiereRow(
              mat: entry.value,
              onChanged: (v) => setState(() => entry.value.note = v),
              onDelete: _tab.index == 1
                  ? () => setState(() => _matieresLibre.removeAt(entry.key))
                  : null,
            ),
          )),
      ]),
    );
  }
}

// ── Ligne matière ─────────────────────────────────────────────────────────────
class _MatiereRow extends StatefulWidget {
  final _Matiere mat;
  final ValueChanged<double?> onChanged;
  final VoidCallback? onDelete;
  const _MatiereRow({required this.mat, required this.onChanged, this.onDelete});
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
    if (n >= 14) return const Color(0xFF1B5E20);
    if (n >= 10) return const Color(0xFFC17F24);
    return const Color(0xFF8B1A00);
  }

  @override
  Widget build(BuildContext context) {
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
          width: 60,
          child: TextField(
            controller: _ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _noteColor),
            decoration: InputDecoration(
              hintText: '—',
              hintStyle: TextStyle(color: context.cMuted),
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
              widget.onChanged(d != null && d >= 0 && d <= 20 ? d : null);
            },
          ),
        ),
        if (widget.onDelete != null) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: widget.onDelete,
            child: Icon(Icons.close_rounded, size: 18, color: context.cMuted),
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
          GestureDetector(
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
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: SizedBox(
      width: 32, height: 42,
      child: Icon(icon, size: 16, color: context.cMuted),
    ),
  );
}
