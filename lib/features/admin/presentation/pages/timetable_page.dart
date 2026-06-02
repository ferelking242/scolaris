import 'dart:math';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/data/timetable_data.dart';

const _bg     = Color(0xFFF5EEE6);
const _white  = Colors.white;
const _ink    = Color(0xFF1A0A00);
const _muted  = Color(0xFF7A5C44);
const _border = Color(0xFFDDCCBB);
const _terra  = ScolarisPalette.terracotta;

// ─── Page ─────────────────────────────────────────────────────────────────────
class TimetablePage extends StatefulWidget {
  const TimetablePage({super.key});
  @override
  State<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage> {
  late List<TSession> _sessions;
  late List<TConflict> _conflicts;
  String? _filterFiliere = kFilieres[0];
  bool _conflictPanelOpen = false;
  int _mobileDayIdx = 0;

  @override
  void initState() {
    super.initState();
    _sessions = buildMockSessions();
    _conflicts = detectConflicts(_sessions);
  }

  void _refresh() {
    _conflicts = detectConflicts(_sessions);
    setState(() {});
  }

  List<TSession> get _filtered => _filterFiliere == null
      ? _sessions
      : _sessions.where((s) => s.filieres.contains(_filterFiliere)).toList();

  TSession? _sessionAt(String jour, TSlot slot) {
    final list = _filtered.where((s) => s.jour == jour && s.slot == slot).toList();
    return list.isEmpty ? null : list.first;
  }

  List<TSession> _sessionsAt(String jour, TSlot slot) =>
      _filtered.where((s) => s.jour == jour && s.slot == slot).toList();

  void _openEdit({TSession? session, String? jour, TSlot? slot}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditSheet(
        session: session,
        defaultJour: jour,
        defaultSlot: slot,
        allSessions: _sessions,
        onSave: (s) {
          setState(() {
            _sessions.removeWhere((x) => x.id == s.id);
            _sessions.add(s);
            _refresh();
          });
        },
        onDelete: (s) {
          setState(() {
            _sessions.removeWhere((x) => x.id == s.id);
            _refresh();
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      child: Column(children: [
        _Header(
          filterFiliere: _filterFiliere,
          conflictCount: _conflicts.length,
          onFilter: (f) => setState(() => _filterFiliere = f),
          onConflictTap: () => setState(() => _conflictPanelOpen = !_conflictPanelOpen),
        ),
        if (_conflictPanelOpen && _conflicts.isNotEmpty)
          _ConflictPanel(conflicts: _conflicts, onClose: () => setState(() => _conflictPanelOpen = false)),
        Expanded(
          child: LayoutBuilder(builder: (ctx, box) {
            if (box.maxWidth >= 700) {
              return _WeekTable(
                sessions: _filtered,
                conflicts: _conflicts,
                onCellTap: (jour, slot, session) => _openEdit(session: session, jour: jour, slot: slot),
              );
            } else {
              return _MobileView(
                sessions: _filtered,
                dayIdx: _mobileDayIdx,
                onDayChanged: (i) => setState(() => _mobileDayIdx = i),
                onCellTap: (jour, slot, session) => _openEdit(session: session, jour: jour, slot: slot),
              );
            }
          }),
        ),
      ]),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final String? filterFiliere;
  final int conflictCount;
  final ValueChanged<String?> onFilter;
  final VoidCallback onConflictTap;
  const _Header({required this.filterFiliere, required this.conflictCount,
      required this.onFilter, required this.onConflictTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: _terra, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.table_chart_rounded, color: _white, size: 19),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Emplois du Temps', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _ink)),
            Text('Gestion des cours par filière', style: TextStyle(fontSize: 11.5, color: _muted)),
          ])),
          if (conflictCount > 0)
            GestureDetector(
              onTap: onConflictTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.warning_rounded, size: 13, color: Color(0xFFDC2626)),
                  const SizedBox(width: 4),
                  Text('$conflictCount conflit${conflictCount > 1 ? "s" : ""}',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700,
                          color: Color(0xFFDC2626))),
                  const SizedBox(width: 3),
                  const Icon(Icons.expand_more_rounded, size: 13, color: Color(0xFFDC2626)),
                ]),
              ),
            ),
        ]),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _FChip(label: 'Toutes', selected: filterFiliere == null,
                color: _terra, onTap: () => onFilter(null)),
            const SizedBox(width: 6),
            ...kFilieres.map((f) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _FChip(
                label: f,
                selected: filterFiliere == f,
                color: getSubjectMeta(f).color,
                onTap: () => onFilter(f),
              ),
            )),
          ]),
        ),
        const SizedBox(height: 10),
        const Divider(height: 1, color: _border),
      ]),
    );
  }
}

class _FChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _FChip({required this.label, required this.selected, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : _white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : _border),
        ),
        child: Text(label, style: TextStyle(
            fontSize: 11.5, fontWeight: FontWeight.w700,
            color: selected ? _white : _muted)),
      ),
    );
  }
}

// ─── Conflict panel ───────────────────────────────────────────────────────────
class _ConflictPanel extends StatelessWidget {
  final List<TConflict> conflicts;
  final VoidCallback onClose;
  const _ConflictPanel({required this.conflicts, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFF7ED),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFD97706)),
          const SizedBox(width: 6),
          Text('${conflicts.length} conflit${conflicts.length > 1 ? "s" : ""} détecté${conflicts.length > 1 ? "s" : ""}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF92400E))),
          const Spacer(),
          GestureDetector(onTap: onClose,
              child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF92400E))),
        ]),
        const SizedBox(height: 8),
        ...conflicts.take(5).map((c) => Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: c.color.withOpacity(.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: c.color.withOpacity(.25)),
          ),
          child: Row(children: [
            Icon(c.icon, size: 13, color: c.color),
            const SizedBox(width: 7),
            Expanded(child: Text(c.description,
                style: TextStyle(fontSize: 11, color: c.color, fontWeight: FontWeight.w600),
                maxLines: 2, overflow: TextOverflow.ellipsis)),
          ]),
        )),
        if (conflicts.length > 5)
          Text('+ ${conflicts.length - 5} autre(s) conflit(s)',
              style: const TextStyle(fontSize: 11, color: Color(0xFF92400E))),
      ]),
    );
  }
}

// ─── Week table (PC) ──────────────────────────────────────────────────────────
class _WeekTable extends StatelessWidget {
  final List<TSession> sessions;
  final List<TConflict> conflicts;
  final void Function(String jour, TSlot slot, TSession? session) onCellTap;
  const _WeekTable({required this.sessions, required this.conflicts, required this.onCellTap});

  List<TSession> _at(String jour, TSlot slot) =>
      sessions.where((s) => s.jour == jour && s.slot == slot).toList();

  bool _hasConflict(String jour, TSlot slot) =>
      conflicts.any((c) =>
          (c.a.jour == jour && c.a.slot == slot) ||
          (c.b.jour == jour && c.b.slot == slot));

  @override
  Widget build(BuildContext context) {
    const rowH = 90.0;
    const timeW = 62.0;

    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Day header row
        Container(
          color: _white,
          child: Row(children: [
            SizedBox(width: timeW,
                child: Padding(padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Center(child: Text('Plage', style: TextStyle(fontSize: 10,
                        fontWeight: FontWeight.w700, color: _muted.withOpacity(.7)))))),
            ...kJoursWeek.map((j) => Expanded(
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: const BoxDecoration(border: Border(left: BorderSide(color: _border))),
                child: Text(j, style: const TextStyle(fontSize: 12.5,
                    fontWeight: FontWeight.w800, color: _ink)),
              ),
            )),
          ]),
        ),
        const Divider(height: 1, color: _border),
        // Slot rows
        ...kStdSlots.map((slot) {
          return Column(children: [
            SizedBox(
              height: rowH,
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // Time label
                Container(
                  width: timeW,
                  color: _white,
                  alignment: Alignment.center,
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(slot.start, style: const TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w800, color: _ink)),
                    Text(slot.end, style: TextStyle(
                        fontSize: 10, color: _muted.withOpacity(.7))),
                  ]),
                ),
                // Day cells
                ...kJoursWeek.map((jour) {
                  final sessionsHere = _at(jour, slot);
                  final hasConf = _hasConflict(jour, slot);
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onCellTap(jour, slot, sessionsHere.isNotEmpty ? sessionsHere.first : null),
                      child: _AdminCell(
                        sessions: sessionsHere,
                        hasConflict: hasConf,
                      ),
                    ),
                  );
                }),
              ]),
            ),
            const Divider(height: 1, color: _border),
          ]);
        }),
        // Add FAB area
        Container(
          color: _white,
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            const SizedBox(width: 62),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_rounded, size: 15),
              label: const Text('Ajouter un cours', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _terra, foregroundColor: _white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              ),
              onPressed: () => onCellTap(kJoursWeek[0], kStdSlots[0], null),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ─── Admin cell ───────────────────────────────────────────────────────────────
class _AdminCell extends StatelessWidget {
  final List<TSession> sessions;
  final bool hasConflict;
  const _AdminCell({required this.sessions, required this.hasConflict});

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return Container(
        decoration: const BoxDecoration(
          color: _white,
          border: Border(left: BorderSide(color: _border)),
        ),
        child: Center(
          child: Icon(Icons.add_rounded, size: 16, color: _border.withOpacity(.5)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: _white,
        border: Border(left: BorderSide(color: _border)),
      ),
      padding: const EdgeInsets.all(4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: sessions.map((s) {
          final meta = getSubjectMeta(s.matiere);
          return Flexible(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(vertical: 1),
              padding: const EdgeInsets.fromLTRB(6, 4, 4, 4),
              decoration: BoxDecoration(
                color: meta.color.withOpacity(.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: hasConflict ? const Color(0xFFDC2626) : meta.color.withOpacity(.3),
                    width: hasConflict ? 1.5 : 1),
              ),
              child: Stack(children: [
                // Background symbols
                Positioned.fill(child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: CustomPaint(
                    painter: _SymbolsPainter(meta, s.id.hashCode),
                  ),
                )),
                // Content
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(s.matiere,
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800,
                            color: meta.color),
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                    if (hasConflict)
                      const Icon(Icons.warning_rounded, size: 10, color: Color(0xFFDC2626)),
                  ]),
                  Text(s.enseignant, style: TextStyle(fontSize: 9.5, color: _muted),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Row(children: [
                    Icon(Icons.room_outlined, size: 9, color: _muted.withOpacity(.7)),
                    const SizedBox(width: 2),
                    Text(s.salle, style: TextStyle(fontSize: 9, color: _muted.withOpacity(.8))),
                    if (s.filieres.length > 1) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                        decoration: BoxDecoration(
                          color: meta.color.withOpacity(.15),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text('${s.filieres.length}cl.', style: TextStyle(
                            fontSize: 8, color: meta.color, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ]),
                ]),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Mobile view ──────────────────────────────────────────────────────────────
class _MobileView extends StatelessWidget {
  final List<TSession> sessions;
  final int dayIdx;
  final ValueChanged<int> onDayChanged;
  final void Function(String jour, TSlot slot, TSession? session) onCellTap;
  const _MobileView({required this.sessions, required this.dayIdx,
      required this.onDayChanged, required this.onCellTap});

  @override
  Widget build(BuildContext context) {
    final jour = kJoursWeek[dayIdx];
    return Column(children: [
      Container(
        color: _white,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: kJoursWeek.asMap().entries.map((e) {
            final sel = e.key == dayIdx;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () => onDayChanged(e.key),
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
          }).toList()),
        ),
      ),
      const Divider(height: 1, color: _border),
      Expanded(
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: kStdSlots.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final slot = kStdSlots[i];
            final sessionList = sessions.where((s) => s.jour == jour && s.slot == slot).toList();
            final session = sessionList.isNotEmpty ? sessionList.first : null;
            return GestureDetector(
              onTap: () => onCellTap(jour, slot, session),
              child: _MobileSlotCard(slot: slot, session: session),
            );
          },
        ),
      ),
      Container(
        color: _white,
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Ajouter un cours', style: TextStyle(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _terra, foregroundColor: _white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () => onCellTap(jour, kStdSlots[0], null),
          ),
        ),
      ),
    ]);
  }
}

class _MobileSlotCard extends StatelessWidget {
  final TSlot slot;
  final TSession? session;
  const _MobileSlotCard({required this.slot, required this.session});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        width: 58,
        child: Column(children: [
          Text(slot.start, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _ink)),
          Text(slot.end, style: TextStyle(fontSize: 10.5, color: _muted.withOpacity(.7))),
        ]),
      ),
      Expanded(
        child: session == null
            ? Container(
                height: 56,
                decoration: BoxDecoration(
                  color: _white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border, style: BorderStyle.solid),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.add_rounded, size: 14, color: _border),
                  const SizedBox(width: 5),
                  Text('Ajouter un cours', style: TextStyle(
                      color: _muted.withOpacity(.4), fontSize: 12)),
                ]),
              )
            : _buildCard(session!),
      ),
    ]);
  }

  Widget _buildCard(TSession s) {
    final meta = getSubjectMeta(s.matiere);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: meta.color.withOpacity(.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: meta.color.withOpacity(.3)),
      ),
      child: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _SymbolsPainter(meta, s.id.hashCode))),
        Row(children: [
          Container(width: 3, height: 44,
              decoration: BoxDecoration(color: meta.color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.matiere, style: TextStyle(color: meta.color, fontSize: 13, fontWeight: FontWeight.w800)),
            Text(s.enseignant, style: const TextStyle(color: _muted, fontSize: 11)),
            Row(children: [
              Icon(Icons.room_outlined, size: 10, color: _muted),
              const SizedBox(width: 2),
              Text(s.salle, style: const TextStyle(color: _muted, fontSize: 10.5)),
              if (s.filieres.length > 1) ...[
                const SizedBox(width: 6),
                Text(s.filieres.join(' · '), style: TextStyle(
                    fontSize: 9.5, color: meta.color.withOpacity(.8), fontWeight: FontWeight.w600)),
              ],
            ]),
          ])),
          Icon(Icons.edit_outlined, size: 14, color: meta.color.withOpacity(.4)),
        ]),
      ]),
    );
  }
}

// ─── Subject background painter ───────────────────────────────────────────────
class _SymbolsPainter extends CustomPainter {
  final SubjectMeta meta;
  final int seed;
  const _SymbolsPainter(this.meta, this.seed);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(seed);
    final tp  = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i < 8; i++) {
      final sym = meta.symbols[rng.nextInt(meta.symbols.length)];
      final sz  = 9.0 + rng.nextDouble() * 8;
      final x   = rng.nextDouble() * (size.width - 14);
      final y   = rng.nextDouble() * (size.height - 14);
      final ang = (rng.nextDouble() - 0.5) * 0.6;
      final op  = 0.07 + rng.nextDouble() * 0.07;
      tp.text = TextSpan(text: sym, style: TextStyle(
          fontSize: sz, color: meta.color.withOpacity(op), fontWeight: FontWeight.w900));
      tp.layout();
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(ang);
      tp.paint(canvas, Offset.zero);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_SymbolsPainter o) => o.seed != seed;
}

// ─── Edit bottom sheet ────────────────────────────────────────────────────────
class _EditSheet extends StatefulWidget {
  final TSession? session;
  final String? defaultJour;
  final TSlot? defaultSlot;
  final List<TSession> allSessions;
  final ValueChanged<TSession> onSave;
  final ValueChanged<TSession> onDelete;
  const _EditSheet({this.session, this.defaultJour, this.defaultSlot,
      required this.allSessions, required this.onSave, required this.onDelete});
  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late String  _matiere, _enseignant, _salle, _jour;
  late TSlot   _slot;
  late List<String> _filieres;
  List<TConflict> _previewConflicts = [];

  @override
  void initState() {
    super.initState();
    final s = widget.session;
    _matiere    = s?.matiere    ?? kMatieres[0];
    _enseignant = s?.enseignant ?? kProfs[0];
    _salle      = s?.salle      ?? kSalles[0];
    _jour       = s?.jour       ?? widget.defaultJour ?? kJoursWeek[0];
    _slot       = s?.slot       ?? widget.defaultSlot ?? kStdSlots[0];
    _filieres   = List.from(s?.filieres ?? [kFilieres[0]]);
    _checkConflicts();
  }

  void _checkConflicts() {
    final draft = _makeDraft();
    final others = widget.allSessions.where((x) => x.id != draft.id).toList();
    _previewConflicts = detectConflicts([draft, ...others])
        .where((c) => c.a.id == draft.id || c.b.id == draft.id)
        .toList();
  }

  TSession _makeDraft() => TSession(
    id: widget.session?.id ?? 'new_${DateTime.now().millisecondsSinceEpoch}',
    matiere: _matiere, enseignant: _enseignant, salle: _salle,
    jour: _jour, slot: _slot, filieres: List.from(_filieres),
  );

  void _update(VoidCallback fn) {
    setState(() { fn(); _checkConflicts(); });
  }

  @override
  Widget build(BuildContext context) {
    final meta = getSubjectMeta(_matiere);
    final isNew = widget.session == null;
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      decoration: const BoxDecoration(
          color: _white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(margin: const EdgeInsets.only(top: 10),
              width: 36, height: 4,
              decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2)))),
          // Header with subject preview
          Container(
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: meta.color.withOpacity(.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: meta.color.withOpacity(.25)),
            ),
            child: Stack(children: [
              Positioned.fill(child: CustomPaint(painter: _SymbolsPainter(meta, _matiere.hashCode))),
              Row(children: [
                Icon(meta.icon, color: meta.color, size: 22),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_matiere, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: meta.color)),
                  Text('$_jour · $_slot.label', style: TextStyle(fontSize: 11.5, color: _muted)),
                ])),
                if (_filieres.isNotEmpty)
                  Wrap(spacing: 4, children: _filieres.take(3).map((f) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: meta.color.withOpacity(.2), borderRadius: BorderRadius.circular(10)),
                    child: Text(f, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: meta.color)),
                  )).toList()),
              ]),
            ]),
          ),
          // Conflict warnings
          if (_previewConflicts.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFCA5A5))),
              child: Column(children: _previewConflicts.map((c) => Row(children: [
                Icon(c.icon, size: 12, color: c.color),
                const SizedBox(width: 6),
                Expanded(child: Text(c.description, style: TextStyle(fontSize: 10.5, color: c.color, fontWeight: FontWeight.w600),
                    maxLines: 2, overflow: TextOverflow.ellipsis)),
              ])).toList()),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              // Matière
              _DropRow('Matière', _matiere, kMatieres,
                  (v) => _update(() => _matiere = v!)),
              const SizedBox(height: 10),
              // Enseignant
              _DropRow('Enseignant', _enseignant, kProfs,
                  (v) => _update(() => _enseignant = v!)),
              const SizedBox(height: 10),
              // Salle
              _DropRow('Salle', _salle, kSalles,
                  (v) => _update(() => _salle = v!)),
              const SizedBox(height: 10),
              // Jour
              _DropRow('Jour', _jour, kJoursWeek,
                  (v) => _update(() => _jour = v!)),
              const SizedBox(height: 10),
              // Plage
              _DropRow('Plage horaire', _slot.label,
                  kStdSlots.map((s) => s.label).toList(),
                  (v) => _update(() => _slot = kStdSlots.firstWhere((s) => s.label == v))),
              const SizedBox(height: 12),
              // Filières (multi-select)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(width: 110,
                    child: Padding(padding: EdgeInsets.only(top: 4),
                        child: Text('Filières', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _ink)))),
                Expanded(
                  child: Wrap(spacing: 6, runSpacing: 6,
                    children: kFilieres.map((f) {
                      final sel = _filieres.contains(f);
                      return GestureDetector(
                        onTap: () => _update(() {
                          if (sel) _filieres.remove(f); else _filieres.add(f);
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: sel ? meta.color : _white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: sel ? meta.color : _border),
                          ),
                          child: Text(f, style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700,
                              color: sel ? _white : _muted)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              Row(children: [
                if (!isNew) Expanded(child: OutlinedButton(
                  onPressed: () { Navigator.pop(context); widget.onDelete(widget.session!); },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFDC2626)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Supprimer', style: TextStyle(fontWeight: FontWeight.w700)),
                )),
                if (!isNew) const SizedBox(width: 10),
                Expanded(child: ElevatedButton(
                  onPressed: _filieres.isEmpty ? null : () {
                    Navigator.pop(context);
                    widget.onSave(_makeDraft());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _previewConflicts.isNotEmpty ? const Color(0xFFD97706) : _terra,
                    foregroundColor: _white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    _previewConflicts.isNotEmpty ? 'Enregistrer malgré conflits' : 'Enregistrer',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                )),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _DropRow(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Row(children: [
      SizedBox(width: 110, child: Text(label, style: const TextStyle(
          fontSize: 12.5, fontWeight: FontWeight.w700, color: _ink))),
      Expanded(child: DropdownButtonFormField<String>(
        value: items.contains(value) ? value : items.first,
        isDense: true,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(9),
              borderSide: const BorderSide(color: _border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9),
              borderSide: const BorderSide(color: _border)),
        ),
        style: const TextStyle(fontSize: 12, color: _ink),
        items: items.map((i) => DropdownMenuItem(value: i,
            child: Text(i, overflow: TextOverflow.ellipsis))).toList(),
        onChanged: onChanged,
      )),
    ]);
  }
}
