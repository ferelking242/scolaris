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

// ── Modèles ───────────────────────────────────────────────────────────────────
class _TimetableSlot {
  final String matiere;
  final String enseignant;
  final String salle;
  final Color color;
  const _TimetableSlot({
    required this.matiere,
    required this.enseignant,
    required this.salle,
    required this.color,
  });
}

// Jours
const _jours = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi'];

// Plages horaires
const _plages = [
  '07h30–09h00',
  '09h15–10h45',
  '11h00–12h30',
  '14h00–15h30',
  '15h45–17h15',
];

// Matière → couleur
const _colors = {
  'Mathématiques':     Color(0xFF6D28D9),
  'Français':          Color(0xFFEA580C),
  'Sciences Physiques':Color(0xFF0EA5E9),
  'SVT':              Color(0xFF2D6A4F),
  'Histoire-Géo':     Color(0xFFDB2777),
  'Philosophie':      Color(0xFF7A5C44),
  'Anglais':          Color(0xFF0284C7),
  'EPS':              Color(0xFF16A34A),
  'Informatique':     Color(0xFF374151),
  'Arts':             Color(0xFFC17F24),
};

// Emploi du temps Tle C
const _tleCGrid = <String, Map<String, _TimetableSlot?>>{
  'Lundi': {
    '07h30–09h00': _TimetableSlot(matiere: 'Mathématiques', enseignant: 'M. Ngakosso', salle: 'B-204', color: Color(0xFF6D28D9)),
    '09h15–10h45': _TimetableSlot(matiere: 'Sciences Physiques', enseignant: 'M. Massamba', salle: 'C-301', color: Color(0xFF0EA5E9)),
    '11h00–12h30': _TimetableSlot(matiere: 'Français', enseignant: 'Mme Mavoungou', salle: 'A-205', color: Color(0xFFEA580C)),
    '14h00–15h30': _TimetableSlot(matiere: 'SVT', enseignant: 'Mme Nzaba', salle: 'C-105', color: Color(0xFF2D6A4F)),
    '15h45–17h15': _TimetableSlot(matiere: 'Histoire-Géo', enseignant: 'M. Tsimba', salle: 'B-101', color: Color(0xFFDB2777)),
  },
  'Mardi': {
    '07h30–09h00': _TimetableSlot(matiere: 'Sciences Physiques', enseignant: 'M. Massamba', salle: 'C-301', color: Color(0xFF0EA5E9)),
    '09h15–10h45': _TimetableSlot(matiere: 'SVT', enseignant: 'Mme Nzaba', salle: 'C-105', color: Color(0xFF2D6A4F)),
    '11h00–12h30': _TimetableSlot(matiere: 'Anglais', enseignant: 'Mme Banzouzi', salle: 'A-110', color: Color(0xFF0284C7)),
    '14h00–15h30': _TimetableSlot(matiere: 'Mathématiques', enseignant: 'M. Ngakosso', salle: 'B-204', color: Color(0xFF6D28D9)),
    '15h45–17h15': _TimetableSlot(matiere: 'Philosophie', enseignant: 'M. Ngandzali', salle: 'B-103', color: Color(0xFF7A5C44)),
  },
  'Mercredi': {
    '07h30–09h00': _TimetableSlot(matiere: 'Mathématiques', enseignant: 'M. Ngakosso', salle: 'B-204', color: Color(0xFF6D28D9)),
    '09h15–10h45': _TimetableSlot(matiere: 'Philosophie', enseignant: 'M. Ngandzali', salle: 'B-103', color: Color(0xFF7A5C44)),
    '11h00–12h30': _TimetableSlot(matiere: 'Histoire-Géo', enseignant: 'M. Tsimba', salle: 'B-101', color: Color(0xFFDB2777)),
    '14h00–15h30': null,
    '15h45–17h15': null,
  },
  'Jeudi': {
    '07h30–09h00': _TimetableSlot(matiere: 'Français', enseignant: 'Mme Mavoungou', salle: 'A-205', color: Color(0xFFEA580C)),
    '09h15–10h45': _TimetableSlot(matiere: 'Histoire-Géo', enseignant: 'M. Tsimba', salle: 'B-101', color: Color(0xFFDB2777)),
    '11h00–12h30': _TimetableSlot(matiere: 'SVT', enseignant: 'Mme Nzaba', salle: 'C-105', color: Color(0xFF2D6A4F)),
    '14h00–15h30': _TimetableSlot(matiere: 'EPS', enseignant: 'M. Ondamba', salle: 'Terrain', color: Color(0xFF16A34A)),
    '15h45–17h15': _TimetableSlot(matiere: 'Anglais', enseignant: 'Mme Banzouzi', salle: 'A-110', color: Color(0xFF0284C7)),
  },
  'Vendredi': {
    '07h30–09h00': _TimetableSlot(matiere: 'Sciences Physiques', enseignant: 'M. Massamba', salle: 'C-301', color: Color(0xFF0EA5E9)),
    '09h15–10h45': _TimetableSlot(matiere: 'Mathématiques', enseignant: 'M. Ngakosso', salle: 'B-204', color: Color(0xFF6D28D9)),
    '11h00–12h30': _TimetableSlot(matiere: 'Anglais', enseignant: 'Mme Banzouzi', salle: 'A-110', color: Color(0xFF0284C7)),
    '14h00–15h30': _TimetableSlot(matiere: 'Philosophie', enseignant: 'M. Ngandzali', salle: 'B-103', color: Color(0xFF7A5C44)),
    '15h45–17h15': null,
  },
};

// Emploi du temps 3e A (simplifié)
const _troisieAGrid = <String, Map<String, _TimetableSlot?>>{
  'Lundi': {
    '07h30–09h00': _TimetableSlot(matiere: 'Mathématiques', enseignant: 'M. Mouyabi', salle: 'B-101', color: Color(0xFF6D28D9)),
    '09h15–10h45': _TimetableSlot(matiere: 'Français', enseignant: 'Mme Kikhounga', salle: 'A-102', color: Color(0xFFEA580C)),
    '11h00–12h30': _TimetableSlot(matiere: 'Sciences Physiques', enseignant: 'M. Massamba', salle: 'C-201', color: Color(0xFF0EA5E9)),
    '14h00–15h30': _TimetableSlot(matiere: 'Histoire-Géo', enseignant: 'M. Tsimba', salle: 'B-102', color: Color(0xFFDB2777)),
    '15h45–17h15': _TimetableSlot(matiere: 'Anglais', enseignant: 'Mme Banzouzi', salle: 'A-110', color: Color(0xFF0284C7)),
  },
  'Mardi': {
    '07h30–09h00': _TimetableSlot(matiere: 'Français', enseignant: 'Mme Kikhounga', salle: 'A-102', color: Color(0xFFEA580C)),
    '09h15–10h45': _TimetableSlot(matiere: 'Mathématiques', enseignant: 'M. Mouyabi', salle: 'B-101', color: Color(0xFF6D28D9)),
    '11h00–12h30': _TimetableSlot(matiere: 'SVT', enseignant: 'Mme Nzaba', salle: 'C-105', color: Color(0xFF2D6A4F)),
    '14h00–15h30': _TimetableSlot(matiere: 'Informatique', enseignant: 'M. Mabika', salle: 'L-001', color: Color(0xFF374151)),
    '15h45–17h15': null,
  },
  'Mercredi': {
    '07h30–09h00': _TimetableSlot(matiere: 'Anglais', enseignant: 'Mme Banzouzi', salle: 'A-110', color: Color(0xFF0284C7)),
    '09h15–10h45': _TimetableSlot(matiere: 'SVT', enseignant: 'Mme Nzaba', salle: 'C-105', color: Color(0xFF2D6A4F)),
    '11h00–12h30': _TimetableSlot(matiere: 'Histoire-Géo', enseignant: 'M. Tsimba', salle: 'B-102', color: Color(0xFFDB2777)),
    '14h00–15h30': null,
    '15h45–17h15': null,
  },
  'Jeudi': {
    '07h30–09h00': _TimetableSlot(matiere: 'Sciences Physiques', enseignant: 'M. Massamba', salle: 'C-201', color: Color(0xFF0EA5E9)),
    '09h15–10h45': _TimetableSlot(matiere: 'Mathématiques', enseignant: 'M. Mouyabi', salle: 'B-101', color: Color(0xFF6D28D9)),
    '11h00–12h30': _TimetableSlot(matiere: 'Français', enseignant: 'Mme Kikhounga', salle: 'A-102', color: Color(0xFFEA580C)),
    '14h00–15h30': _TimetableSlot(matiere: 'EPS', enseignant: 'M. Ondamba', salle: 'Terrain', color: Color(0xFF16A34A)),
    '15h45–17h15': null,
  },
  'Vendredi': {
    '07h30–09h00': _TimetableSlot(matiere: 'Mathématiques', enseignant: 'M. Mouyabi', salle: 'B-101', color: Color(0xFF6D28D9)),
    '09h15–10h45': _TimetableSlot(matiere: 'SVT', enseignant: 'Mme Nzaba', salle: 'C-105', color: Color(0xFF2D6A4F)),
    '11h00–12h30': _TimetableSlot(matiere: 'Informatique', enseignant: 'M. Mabika', salle: 'L-001', color: Color(0xFF374151)),
    '14h00–15h30': _TimetableSlot(matiere: 'Arts', enseignant: 'Mme Makaya', salle: 'A-201', color: Color(0xFFC17F24)),
    '15h45–17h15': null,
  },
};

const _grids = {
  'Tle C': _tleCGrid,
  '3e A': _troisieAGrid,
};

// ── Page ──────────────────────────────────────────────────────────────────────
class TimetablePage extends StatefulWidget {
  const TimetablePage({super.key});
  @override
  State<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage> {
  String _selectedClass = 'Tle C';
  int _dayIdx = 0;

  @override
  Widget build(BuildContext context) {
    final grid = _grids[_selectedClass] ?? _tleCGrid;
    final day = _jours[_dayIdx];
    final dayGrid = grid[day] ?? {};

    return Container(
      color: _bg,
      child: Column(children: [
        _TopBar(
          selectedClass: _selectedClass,
          classes: _grids.keys.toList(),
          onSelect: (c) => setState(() { _selectedClass = c; }),
        ),
        _DayTabs(dayIdx: _dayIdx, onDay: (i) => setState(() => _dayIdx = i)),
        Expanded(
          child: _DayGrid(
            slots: _plages.map((p) => (p, dayGrid[p])).toList(),
            onAddSlot: (plage) => _showEditSheet(plage),
          ),
        ),
      ]),
    );
  }

  void _showEditSheet(String plage) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditSheet(plage: plage, day: _jours[_dayIdx]),
    );
  }
}

// ── Top bar ────────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final String selectedClass;
  final List<String> classes;
  final ValueChanged<String> onSelect;
  const _TopBar({required this.selectedClass, required this.classes, required this.onSelect});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: _white,
          border: Border(bottom: BorderSide(color: _border))),
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
      child: Row(children: [
        Container(width: 40, height: 40,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF1A0A00), Color(0xFF1A0A00)]),
            borderRadius: BorderRadius.circular(11)),
          child: const Center(child: Icon(Icons.table_chart_rounded, color: _white, size: 20))),
        const SizedBox(width: 12),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Emplois du Temps', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
          Text('Visualisation et modification par classe',
              style: TextStyle(fontSize: 12, color: _muted)),
        ])),
        DropdownButton<String>(
          value: selectedClass,
          underline: const SizedBox.shrink(),
          style: const TextStyle(fontSize: 13, color: _ink, fontWeight: FontWeight.w700),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _muted),
          items: classes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (v) => onSelect(v!),
        ),
      ]),
    );
  }
}

// ── Day tabs ───────────────────────────────────────────────────────────────────
class _DayTabs extends StatelessWidget {
  final int dayIdx;
  final ValueChanged<int> onDay;
  const _DayTabs({required this.dayIdx, required this.onDay});
  @override
  Widget build(BuildContext context) {
    return Container(
      color: _white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _jours.asMap().entries.map((e) {
            final sel = e.key == dayIdx;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onDay(e.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: sel ? _terra : _bg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sel ? _terra : _border),
                  ),
                  child: Text(e.value, style: TextStyle(
                      fontSize: 12.5, color: sel ? _white : _ink,
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

// ── Day grid ───────────────────────────────────────────────────────────────────
class _DayGrid extends StatelessWidget {
  final List<(String, _TimetableSlot?)> slots;
  final ValueChanged<String> onAddSlot;
  const _DayGrid({required this.slots, required this.onAddSlot});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: slots.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final (plage, slot) = slots[i];
        return _SlotCard(plage: plage, slot: slot, onAdd: () => onAddSlot(plage));
      },
    );
  }
}

// ── Slot card ──────────────────────────────────────────────────────────────────
class _SlotCard extends StatelessWidget {
  final String plage;
  final _TimetableSlot? slot;
  final VoidCallback onAdd;
  const _SlotCard({required this.plage, this.slot, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        width: 72,
        child: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(plage.split('–').first, style: const TextStyle(
              fontSize: 11, color: _muted, fontWeight: FontWeight.w600)),
        ),
      ),
      Expanded(child: GestureDetector(
        onTap: onAdd,
        child: slot == null
            ? Container(
                height: 52,
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border, style: BorderStyle.solid),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.add_rounded, size: 16, color: _border),
                  const SizedBox(width: 6),
                  Text('Ajouter un cours',
                      style: TextStyle(color: _muted.withOpacity(.5), fontSize: 12)),
                ]),
              )
            : Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: slot!.color.withOpacity(.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: slot!.color.withOpacity(.3)),
                ),
                child: Row(children: [
                  Container(
                    width: 4, height: 48,
                    decoration: BoxDecoration(
                      color: slot!.color, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(slot!.matiere, style: TextStyle(
                          color: slot!.color, fontSize: 13, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(slot!.enseignant, style: const TextStyle(
                          color: _muted, fontSize: 11.5)),
                      const SizedBox(height: 1),
                      Row(children: [
                        Icon(Icons.room_outlined, size: 11, color: _muted),
                        const SizedBox(width: 2),
                        Text(slot!.salle, style: const TextStyle(color: _muted, fontSize: 11)),
                      ]),
                    ],
                  )),
                  Icon(Icons.edit_outlined, size: 16, color: slot!.color.withOpacity(.5)),
                ]),
              ),
      )),
    ]);
  }
}

// ── Edit sheet ─────────────────────────────────────────────────────────────────
class _EditSheet extends StatefulWidget {
  final String plage;
  final String day;
  const _EditSheet({required this.plage, required this.day});
  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  String _matiere = 'Mathématiques';
  String _enseignant = 'M. Ngakosso Jean-Pierre';
  String _salle = 'B-204';

  static const _matieres = [
    'Mathématiques', 'Français', 'Sciences Physiques', 'SVT',
    'Histoire-Géo', 'Philosophie', 'Anglais', 'EPS', 'Informatique', 'Arts',
  ];

  static const _profs = [
    'M. Ngakosso Jean-Pierre', 'Mme Mavoungou Cécile', 'M. Massamba Boris',
    'Mme Nzaba Marie', 'M. Tsimba Gervais', 'Mme Banzouzi Pauline',
    'M. Mouyabi Rodrigue', 'Mme Kikhounga Odette', 'M. Ondamba Pierre',
    'M. Mabika Jean-Claude', 'M. Ngandzali Théophile',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      decoration: const BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(margin: const EdgeInsets.only(top: 10),
            width: 40, height: 4,
            decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2)))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
          child: Row(children: [
            Text('${widget.day} · ${widget.plage}', style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800, color: _ink)),
            const Spacer(),
            IconButton(icon: const Icon(Icons.close_rounded, color: _muted),
                onPressed: () => Navigator.pop(context)),
          ]),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            _DropRow('Matière', _matiere, _matieres, (v) => setState(() => _matiere = v!)),
            const SizedBox(height: 12),
            _DropRow('Enseignant', _enseignant, _profs, (v) => setState(() => _enseignant = v!)),
            const SizedBox(height: 12),
            Row(children: [
              const Expanded(flex: 2, child: Text('Salle', style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: _ink))),
              Expanded(flex: 3, child: TextFormField(
                initialValue: _salle,
                style: const TextStyle(fontSize: 13, color: _ink),
                onChanged: (v) => _salle = v,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _border)),
                ),
              )),
            ]),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _terra,
                  side: const BorderSide(color: _terra),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Supprimer', style: TextStyle(fontWeight: FontWeight.w700)),
              )),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _terra, foregroundColor: _white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.w700)),
              )),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _DropRow(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Row(children: [
      Expanded(flex: 2, child: Text(label, style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w700, color: _ink))),
      Expanded(flex: 3, child: DropdownButtonFormField<String>(
        value: value,
        isDense: true,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _border)),
        ),
        style: const TextStyle(fontSize: 12.5, color: _ink),
        items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, overflow: TextOverflow.ellipsis))).toList(),
        onChanged: onChanged,
      )),
    ]);
  }
}
