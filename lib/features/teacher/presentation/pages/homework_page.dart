import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

const _terra  = ScolarisPalette.terracotta;
const _orange = ScolarisPalette.orange;
const _gold   = ScolarisPalette.gold;
const _green  = ScolarisPalette.forestGreen;
const _ink    = Color(0xFF1A0A00);
const _muted  = Color(0xFF7A5C44);
const _border = Color(0xFFDDCCBB);
const _white  = Colors.white;
const _bg     = Color(0xFFF5EEE6);

// ── Modèle ────────────────────────────────────────────────────────────────────
class _HW {
  final String id;
  final String matiere;
  final String classe;
  final String titre;
  final String description;
  final DateTime echeance;
  final int rendu;
  final int total;
  const _HW({
    required this.id,
    required this.matiere,
    required this.classe,
    required this.titre,
    required this.description,
    required this.echeance,
    required this.rendu,
    required this.total,
  });
}

final _mockHW = <_HW>[
  _HW(
    id: 'hw1',
    matiere: 'Mathématiques',
    classe: 'Tle C',
    titre: 'Exercices — Fonctions logarithmiques',
    description:
        'Résoudre les exercices 14, 15, 16 du manuel (pp. 248–251). Justifier toutes les étapes.',
    echeance: DateTime(2026, 5, 28),
    rendu: 21,
    total: 32,
  ),
  _HW(
    id: 'hw2',
    matiere: 'Mathématiques',
    classe: '1ère C',
    titre: 'DS à faire à la maison — Intégration',
    description:
        'Calcul intégral, changement de variable. Copies individuelles uniquement.',
    echeance: DateTime(2026, 6, 2),
    rendu: 7,
    total: 30,
  ),
  _HW(
    id: 'hw3',
    matiere: 'Mathématiques',
    classe: '2nde A',
    titre: 'Exercices — Statistiques descriptives',
    description:
        'Exercices 1 à 8 de la fiche distribuée en classe. Utiliser tableau & graphique.',
    echeance: DateTime(2026, 5, 24),
    rendu: 28,
    total: 30,
  ),
  _HW(
    id: 'hw4',
    matiere: 'Mathématiques',
    classe: 'Tle C',
    titre: 'Compte-rendu — TP probabilités',
    description:
        'Rédiger un compte-rendu de 1 à 2 pages de la simulation de Monte Carlo réalisée en classe.',
    echeance: DateTime(2026, 6, 10),
    rendu: 0,
    total: 32,
  ),
];

// ── Page principale ────────────────────────────────────────────────────────────
class HomeworkPage extends StatefulWidget {
  const HomeworkPage({super.key});
  @override
  State<HomeworkPage> createState() => _HomeworkPageState();
}

class _HomeworkPageState extends State<HomeworkPage> {
  String _filterClasse = 'Toutes';
  final List<_HW> _homeworks = List.from(_mockHW);

  List<_HW> get _filtered => _filterClasse == 'Toutes'
      ? _homeworks
      : _homeworks.where((h) => h.classe == _filterClasse).toList();

  List<String> get _classes => [
        'Toutes',
        ..._homeworks.map((h) => h.classe).toSet().toList()..sort(),
      ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      child: Column(children: [
        _TopBar(
          onAdd: () => _showCreateSheet(context),
        ),
        _FilterRow(
          classes: _classes,
          selected: _filterClasse,
          onSelect: (c) => setState(() => _filterClasse = c),
        ),
        Expanded(
          child: _filtered.isEmpty
              ? _EmptyState(filter: _filterClasse)
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _HWCard(
                    hw: _filtered[i],
                    onDelete: () =>
                        setState(() => _homeworks.remove(_filtered[i])),
                  ),
                ),
        ),
      ]),
    );
  }

  void _showCreateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateSheet(
        onSave: (hw) => setState(() => _homeworks.insert(0, hw)),
      ),
    );
  }
}

// ── Top bar ────────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final VoidCallback onAdd;
  const _TopBar({required this.onAdd});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _white,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF1A0A00), _terra]),
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Center(child: Icon(Icons.assignment_rounded, color: _white, size: 20)),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Devoirs & Travaux',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
            Text('Gérez les devoirs par classe',
                style: TextStyle(fontSize: 12, color: _muted)),
          ]),
        ),
        TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded, size: 18, color: _white),
          label: const Text('Créer', style: TextStyle(color: _white, fontWeight: FontWeight.w700)),
          style: TextButton.styleFrom(
            backgroundColor: _terra,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ]),
    );
  }
}

// ── Filter row ─────────────────────────────────────────────────────────────────
class _FilterRow extends StatelessWidget {
  final List<String> classes;
  final String selected;
  final ValueChanged<String> onSelect;
  const _FilterRow(
      {required this.classes, required this.selected, required this.onSelect});
  @override
  Widget build(BuildContext context) {
    return Container(
      color: _white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: classes.map((c) {
            final sel = c == selected;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onSelect(c),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel ? _ink : _bg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sel ? _ink : _border),
                  ),
                  child: Text(c, style: TextStyle(
                      fontSize: 12, color: sel ? _white : _ink,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── Homework card ──────────────────────────────────────────────────────────────
class _HWCard extends StatelessWidget {
  final _HW hw;
  final VoidCallback onDelete;
  const _HWCard({required this.hw, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysLeft = hw.echeance.difference(now).inDays;
    final overdue = daysLeft < 0;
    final dueSoon = !overdue && daysLeft <= 2;
    final pct = hw.total > 0 ? hw.rendu / hw.total : 0.0;

    Color statusColor;
    String statusLabel;
    if (overdue) {
      statusColor = _terra;
      statusLabel = 'Expiré';
    } else if (dueSoon) {
      statusColor = _orange;
      statusLabel = daysLeft == 0 ? 'Aujourd\'hui' : 'J-$daysLeft';
    } else {
      statusColor = _green;
      statusLabel = 'J-$daysLeft';
    }

    return Container(
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: const [BoxShadow(
            color: Color(0x07000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: _terra.withOpacity(.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(child: Icon(Icons.assignment_outlined, color: _terra, size: 18)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  _ClassBadge(hw.classe),
                  const SizedBox(width: 6),
                  _MatiereTag(hw.matiere),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(statusLabel, style: TextStyle(
                        color: statusColor, fontSize: 10.5, fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: 6),
                Text(hw.titre, style: const TextStyle(
                    color: _ink, fontSize: 13.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(hw.description, style: const TextStyle(
                    color: _muted, fontSize: 12, height: 1.4),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            )),
          ]),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          decoration: BoxDecoration(
            color: _bg.withOpacity(.5),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
          ),
          child: Row(children: [
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('${hw.rendu}/${hw.total} rendus',
                      style: const TextStyle(fontSize: 11.5, color: _ink,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  Text('(${(pct * 100).toStringAsFixed(0)}%)',
                      style: TextStyle(fontSize: 11, color: _muted)),
                ]),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: _border,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        pct >= .8 ? _green : pct >= .5 ? _orange : _terra),
                    minHeight: 5,
                  ),
                ),
              ],
            )),
            const SizedBox(width: 12),
            Row(children: [
              Icon(Icons.calendar_today_outlined, size: 12, color: _muted),
              const SizedBox(width: 4),
              Text(
                '${hw.echeance.day.toString().padLeft(2,'0')}/${hw.echeance.month.toString().padLeft(2,'0')}/${hw.echeance.year}',
                style: const TextStyle(color: _muted, fontSize: 11),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onDelete,
                child: Icon(Icons.delete_outline_rounded, size: 18,
                    color: _muted.withOpacity(.5)),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _ClassBadge extends StatelessWidget {
  final String c;
  const _ClassBadge(this.c);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: _ink, borderRadius: BorderRadius.circular(6)),
    child: Text(c, style: const TextStyle(color: _white, fontSize: 10, fontWeight: FontWeight.w700)),
  );
}

class _MatiereTag extends StatelessWidget {
  final String m;
  const _MatiereTag(this.m);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: _gold.withOpacity(.15), borderRadius: BorderRadius.circular(6),
      border: Border.all(color: _gold.withOpacity(.3))),
    child: Text(m, style: const TextStyle(color: _gold, fontSize: 10, fontWeight: FontWeight.w600)),
  );
}

// ── Empty state ────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final String filter;
  const _EmptyState({required this.filter});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.assignment_outlined, size: 56, color: _muted.withOpacity(.3)),
      const SizedBox(height: 12),
      Text('Aucun devoir pour "$filter"',
          style: const TextStyle(color: _muted, fontSize: 14, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      const Text('Créez un devoir avec le bouton ci-dessus.',
          style: TextStyle(color: _muted, fontSize: 12)),
    ]),
  );
}

// ── Create sheet ───────────────────────────────────────────────────────────────
class _CreateSheet extends StatefulWidget {
  final void Function(_HW) onSave;
  const _CreateSheet({required this.onSave});
  @override
  State<_CreateSheet> createState() => _CreateSheetState();
}

class _CreateSheetState extends State<_CreateSheet> {
  final _titreCtrl = TextEditingController();
  final _descCtrl  = TextEditingController();
  final _form = GlobalKey<FormState>();
  String _matiere = 'Mathématiques';
  String _classe  = 'Tle C';
  DateTime _due   = DateTime.now().add(const Duration(days: 7));
  bool _saving    = false;

  static const _matieres = [
    'Mathématiques', 'Français', 'Sciences Physiques', 'SVT',
    'Histoire-Géographie', 'Anglais', 'Philosophie', 'Informatique',
  ];
  static const _classes = [
    'CP A','CE2 A','CM2 B','6e A','5e A','4e B','3e A',
    '2nde A','2nde C','1ère A','1ère C','Tle A','Tle C','Tle D',
  ];

  @override
  void dispose() { _titreCtrl.dispose(); _descCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: .88, minChildSize: .5, maxChildSize: .95,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Form(
          key: _form,
          child: Column(children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: _border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              child: Row(children: [
                const Text('Nouveau devoir', style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800, color: _ink)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: _muted),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.all(20),
                children: [
                  _Field('Titre du devoir'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _titreCtrl,
                    style: const TextStyle(fontSize: 14, color: _ink),
                    decoration: _inputDecor('Ex: Exercices sur les intégrales'),
                    validator: (v) => v!.trim().isEmpty ? 'Requis' : null,
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Field('Matière'),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _matiere,
                          decoration: _inputDecor(''),
                          style: const TextStyle(fontSize: 13, color: _ink),
                          items: _matieres.map((m) =>
                              DropdownMenuItem(value: m, child: Text(m))).toList(),
                          onChanged: (v) => setState(() => _matiere = v!),
                        ),
                      ],
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Field('Classe'),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _classe,
                          decoration: _inputDecor(''),
                          style: const TextStyle(fontSize: 13, color: _ink),
                          items: _classes.map((c) =>
                              DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: (v) => setState(() => _classe = v!),
                        ),
                      ],
                    )),
                  ]),
                  const SizedBox(height: 16),
                  _Field('Date limite'),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _due,
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2027),
                        builder: (_, child) => Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.light(primary: _terra)),
                          child: child!,
                        ),
                      );
                      if (d != null) setState(() => _due = d);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: _border),
                        borderRadius: BorderRadius.circular(12),
                        color: _bg.withOpacity(.5),
                      ),
                      child: Row(children: [
                        const Icon(Icons.calendar_today_outlined, size: 16, color: _muted),
                        const SizedBox(width: 10),
                        Text(
                          '${_due.day.toString().padLeft(2,'0')}/${_due.month.toString().padLeft(2,'0')}/${_due.year}',
                          style: const TextStyle(fontSize: 14, color: _ink, fontWeight: FontWeight.w500),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Field('Description / Instructions'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descCtrl,
                    maxLines: 4,
                    style: const TextStyle(fontSize: 13.5, color: _ink, height: 1.5),
                    decoration: _inputDecor('Indiquez les exercices, pages ou consignes…'),
                    validator: (v) => v!.trim().isEmpty ? 'Requis' : null,
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: _white))
                          : const Icon(Icons.check_rounded, size: 18),
                      label: Text(_saving ? 'Enregistrement…' : 'Publier le devoir',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _terra,
                        foregroundColor: _white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    final hw = _HW(
      id: 'hw${DateTime.now().millisecondsSinceEpoch}',
      matiere: _matiere,
      classe: _classe,
      titre: _titreCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      echeance: _due,
      rendu: 0,
      total: 30,
    );
    widget.onSave(hw);
    Navigator.pop(context);
  }

  InputDecoration _inputDecor(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: _muted.withOpacity(.5), fontSize: 13),
    filled: true,
    fillColor: _bg.withOpacity(.5),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _border)),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _border)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _terra, width: 1.5)),
    errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _terra)),
  );
}

class _Field extends StatelessWidget {
  final String t;
  const _Field(this.t);
  @override
  Widget build(BuildContext context) => Text(t, style: const TextStyle(
      fontSize: 13, fontWeight: FontWeight.w700, color: _ink));
}
