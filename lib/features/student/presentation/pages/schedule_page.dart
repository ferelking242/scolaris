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
const _gold   = ScolarisPalette.gold;

// ─── Page ─────────────────────────────────────────────────────────────────────
class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});
  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  // Ferel Ondongo — filière EMI (index 0 dans kFilieres)
  String _filiere = kFilieres[0]; // 'EMI'
  late final List<TSession> _allSessions;
  int _mobileDayIdx = 0;

  @override
  void initState() {
    super.initState();
    _allSessions = buildMockSessions();
    // Start on current weekday (Mon=0 … Fri=4), clamp to 0-4
    final wd = DateTime.now().weekday; // 1=Mon … 7=Sun
    _mobileDayIdx = (wd >= 1 && wd <= 5) ? wd - 1 : 0;
  }

  List<TSession> get _sessions =>
      _allSessions.where((s) => s.filieres.contains(_filiere)).toList();

  TSession? _at(String jour, TSlot slot) =>
      _sessions.where((s) => s.jour == jour && s.slot == slot).firstOrNull;

  int _courseCount() => _sessions.length;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      child: Column(children: [
        _Header(
          filiere: _filiere,
          courseCount: _courseCount(),
          onFiliereChanged: (f) => setState(() => _filiere = f),
        ),
        Expanded(
          child: LayoutBuilder(builder: (ctx, box) {
            return box.maxWidth >= 680
                ? _WeekTableView(sessions: _sessions, filiere: _filiere)
                : _MobileDayView(
                    sessions: _sessions,
                    dayIdx: _mobileDayIdx,
                    onDayChanged: (i) => setState(() => _mobileDayIdx = i),
                  );
          }),
        ),
      ]),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final String filiere;
  final int courseCount;
  final ValueChanged<String> onFiliereChanged;
  const _Header({required this.filiere, required this.courseCount, required this.onFiliereChanged});

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
              gradient: const LinearGradient(colors: [Color(0xFF8B1A00), Color(0xFFD4540A)]),
              borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.calendar_today_rounded, color: _white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Emploi du Temps', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _ink)),
            Text('$courseCount cours cette semaine · $filiere',
                style: const TextStyle(fontSize: 11.5, color: _muted)),
          ])),
          // Filière picker
          GestureDetector(
            onTap: () => _showFilierePicker(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _terra.withOpacity(.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _terra.withOpacity(.25)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(filiere, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _terra)),
                const SizedBox(width: 4),
                const Icon(Icons.unfold_more_rounded, size: 14, color: _terra),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        // Weekday quick stats
        _WeekStats(filiere: filiere),
        const SizedBox(height: 10),
        const Divider(height: 1, color: _border),
      ]),
    );
  }

  void _showFilierePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
            color: _white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(margin: const EdgeInsets.only(top: 10),
              width: 36, height: 4,
              decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2)))),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 14, 20, 4),
            child: Text('Changer de filière', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _ink)),
          ),
          const Divider(height: 1),
          ...kFilieres.map((f) {
            final meta = getSubjectMeta(f);
            final sel  = f == filiere;
            return ListTile(
              leading: Container(width: 10, height: 10,
                  decoration: BoxDecoration(color: meta.color, shape: BoxShape.circle)),
              title: Text(f, style: TextStyle(fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                  color: sel ? _terra : _ink, fontSize: 14)),
              trailing: sel ? const Icon(Icons.check_rounded, color: _terra, size: 18) : null,
              onTap: () { Navigator.pop(context); onFiliereChanged(f); },
            );
          }),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }
}

class _WeekStats extends StatelessWidget {
  final String filiere;
  const _WeekStats({required this.filiere});
  @override
  Widget build(BuildContext context) {
    final sessions = buildMockSessions().where((s) => s.filieres.contains(filiere)).toList();
    final byDay = <String, int>{};
    for (final j in kJoursWeek) byDay[j] = sessions.where((s) => s.jour == j).length;
    return Row(children: kJoursWeek.map((j) {
      final count = byDay[j] ?? 0;
      final today = j == _todayJour();
      return Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 4),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: today ? _terra.withOpacity(.1) : _bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: today ? _terra : _border.withOpacity(.5)),
          ),
          child: Column(children: [
            Text(j.substring(0, 3).toUpperCase(),
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
                    color: today ? _terra : _muted, letterSpacing: 0.4)),
            const SizedBox(height: 2),
            Text('$count', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900,
                color: today ? _terra : _ink)),
          ]),
        ),
      );
    }).toList());
  }

  String _todayJour() {
    final wd = DateTime.now().weekday; // 1=Mon
    if (wd >= 1 && wd <= 5) return kJoursWeek[wd - 1];
    return '';
  }
}

// ─── Full week table (PC + tablet) ───────────────────────────────────────────
class _WeekTableView extends StatelessWidget {
  final List<TSession> sessions;
  final String filiere;
  const _WeekTableView({required this.sessions, required this.filiere});

  TSession? _at(String jour, TSlot slot) =>
      sessions.where((s) => s.jour == jour && s.slot == slot).firstOrNull;

  bool _isToday(String jour) {
    final wd = DateTime.now().weekday;
    if (wd < 1 || wd > 5) return false;
    return kJoursWeek[wd - 1] == jour;
  }

  @override
  Widget build(BuildContext context) {
    const timeW = 58.0;
    const rowH  = 96.0;
    final today = _todayJour();

    return SingleChildScrollView(
      child: Column(children: [
        // ── Day header row ──
        Container(
          color: _white,
          child: Row(children: [
            SizedBox(width: timeW,
                child: Padding(padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Center(child: Text('Heure',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700,
                            color: _muted.withOpacity(.6)))))),
            ...kJoursWeek.map((j) {
              final isTod = j == today;
              return Expanded(
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isTod ? _terra.withOpacity(.06) : null,
                    border: const Border(left: BorderSide(color: _border)),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    if (isTod)
                      Container(
                        width: 6, height: 6, margin: const EdgeInsets.only(bottom: 3),
                        decoration: const BoxDecoration(color: _terra, shape: BoxShape.circle),
                      ),
                    Text(j,
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800,
                            color: isTod ? _terra : _ink)),
                  ]),
                ),
              );
            }),
          ]),
        ),
        const Divider(height: 1, color: _border),

        // ── Slot rows ──
        ...kStdSlots.map((slot) => Column(children: [
          SizedBox(
            height: rowH,
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // Time
              Container(
                width: timeW, color: _white,
                alignment: Alignment.center,
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(slot.start, style: const TextStyle(
                      fontSize: 11.5, fontWeight: FontWeight.w800, color: _ink)),
                  Text(slot.end, style: TextStyle(
                      fontSize: 10, color: _muted.withOpacity(.65))),
                ]),
              ),
              // Day cells
              ...kJoursWeek.map((jour) {
                final session = _at(jour, slot);
                final isTod   = jour == today;
                return Expanded(child: _TableCell(
                  session: session,
                  isToday: isTod,
                ));
              }),
            ]),
          ),
          const Divider(height: 1, color: _border),
        ])),

        // Legend
        _Legend(sessions: sessions),
        const SizedBox(height: 16),
      ]),
    );
  }

  String _todayJour() {
    final wd = DateTime.now().weekday;
    if (wd >= 1 && wd <= 5) return kJoursWeek[wd - 1];
    return '';
  }
}

// ─── Table cell ───────────────────────────────────────────────────────────────
class _TableCell extends StatelessWidget {
  final TSession? session;
  final bool isToday;
  const _TableCell({this.session, required this.isToday});

  @override
  Widget build(BuildContext context) {
    if (session == null) {
      return Container(
        decoration: BoxDecoration(
          color: isToday ? _terra.withOpacity(.025) : _white,
          border: const Border(left: BorderSide(color: _border)),
        ),
      );
    }

    final s    = session!;
    final meta = getSubjectMeta(s.matiere);
    final seed = s.id.hashCode;

    return Container(
      decoration: BoxDecoration(
        color: isToday ? _terra.withOpacity(.025) : _white,
        border: const Border(left: BorderSide(color: _border)),
      ),
      padding: const EdgeInsets.all(4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                meta.color,
                meta.color.withOpacity(.82),
              ],
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(color: meta.color.withOpacity(.2), blurRadius: 4, offset: const Offset(0, 1)),
            ],
          ),
          child: Stack(children: [
            // Subject pattern background
            Positioned.fill(child: CustomPaint(
              painter: _StudentSymbolsPainter(meta, seed),
            )),
            // Today highlight glow
            if (isToday)
              Positioned(top: 0, left: 0, right: 0,
                child: Container(
                  height: 3,
                  decoration: const BoxDecoration(
                    color: _gold,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                  ),
                )),
            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Subject name
                  Text(s.matiere,
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w900,
                          color: _white, height: 1.2),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  // Teacher
                  Row(children: [
                    const Icon(Icons.person_outline_rounded, size: 9, color: Color(0xCCFFFFFF)),
                    const SizedBox(width: 2),
                    Expanded(child: Text(s.enseignant,
                        style: const TextStyle(fontSize: 9, color: Color(0xCCFFFFFF)),
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
                  const SizedBox(height: 2),
                  // Room
                  Row(children: [
                    const Icon(Icons.room_outlined, size: 9, color: Color(0xBBFFFFFF)),
                    const SizedBox(width: 2),
                    Text(s.salle, style: const TextStyle(fontSize: 9, color: Color(0xBBFFFFFF))),
                    if (s.filieres.length > 1) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('${s.filieres.length} fil.', style: const TextStyle(
                            fontSize: 8, color: _white, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ]),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─── Student symbols painter (vibrant, larger symbols) ────────────────────────
class _StudentSymbolsPainter extends CustomPainter {
  final SubjectMeta meta;
  final int seed;
  const _StudentSymbolsPainter(this.meta, this.seed);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(seed);
    final tp  = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i < 9; i++) {
      final sym = meta.symbols[rng.nextInt(meta.symbols.length)];
      final sz  = 11.0 + rng.nextDouble() * 10;
      final x   = rng.nextDouble() * (size.width - 6);
      final y   = rng.nextDouble() * (size.height - 6);
      final ang = (rng.nextDouble() - 0.5) * 0.8;
      final op  = 0.12 + rng.nextDouble() * 0.1;
      tp.text = TextSpan(text: sym, style: TextStyle(
          fontSize: sz, color: Colors.white.withOpacity(op),
          fontWeight: FontWeight.w900));
      tp.layout();
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(ang);
      tp.paint(canvas, Offset.zero);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_StudentSymbolsPainter o) => o.seed != seed;
}

// ─── Legend ───────────────────────────────────────────────────────────────────
class _Legend extends StatelessWidget {
  final List<TSession> sessions;
  const _Legend({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final subjects = sessions.map((s) => s.matiere).toSet().toList()..sort();
    if (subjects.isEmpty) return const SizedBox.shrink();
    return Container(
      color: _white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Matières', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800,
            color: _muted, letterSpacing: 0.3)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 6,
          children: subjects.map((sub) {
            final meta = getSubjectMeta(sub);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: meta.color.withOpacity(.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: meta.color.withOpacity(.25)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(meta.icon, size: 11, color: meta.color),
                const SizedBox(width: 4),
                Text(sub, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700,
                    color: meta.color)),
              ]),
            );
          }).toList(),
        ),
      ]),
    );
  }
}

// ─── Mobile day view ─────────────────────────────────────────────────────────
class _MobileDayView extends StatelessWidget {
  final List<TSession> sessions;
  final int dayIdx;
  final ValueChanged<int> onDayChanged;
  const _MobileDayView({required this.sessions, required this.dayIdx, required this.onDayChanged});

  @override
  Widget build(BuildContext context) {
    final today  = _todayJour();
    final jour   = kJoursWeek[dayIdx];
    final daySlots = sessions.where((s) => s.jour == jour).toList()
      ..sort((a, b) => a.slot.startMin.compareTo(b.slot.startMin));

    return Column(children: [
      // Day tabs
      Container(
        color: _white,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(children: kJoursWeek.asMap().entries.map((e) {
          final j      = e.value;
          final sel    = e.key == dayIdx;
          final isTod  = j == today;
          final count  = sessions.where((s) => s.jour == j).length;
          return Expanded(child: GestureDetector(
            onTap: () => onDayChanged(e.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                color: sel ? _terra : (isTod ? _terra.withOpacity(.08) : _bg),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: sel ? _terra : (isTod ? _terra.withOpacity(.3) : _border)),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(j.substring(0, 3).toUpperCase(),
                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800,
                        color: sel ? _white : (isTod ? _terra : _muted), letterSpacing: 0.3)),
                const SizedBox(height: 2),
                Text('$count', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900,
                    color: sel ? _white : (isTod ? _terra : _ink))),
              ]),
            ),
          ));
        }).toList()),
      ),
      const Divider(height: 1, color: _border),

      // Day sessions
      Expanded(
        child: daySlots.isEmpty
            ? Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.event_available_rounded, size: 40, color: _border),
                  const SizedBox(height: 10),
                  const Text('Aucun cours ce jour', style: TextStyle(color: _muted, fontSize: 14)),
                ]),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(14),
                itemCount: kStdSlots.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final slot   = kStdSlots[i];
                  final session = sessions.where((s) => s.jour == jour && s.slot == slot).firstOrNull;
                  return _MobileCard(slot: slot, session: session);
                },
              ),
      ),
    ]);
  }

  String _todayJour() {
    final wd = DateTime.now().weekday;
    if (wd >= 1 && wd <= 5) return kJoursWeek[wd - 1];
    return '';
  }
}

// ─── Mobile session card ──────────────────────────────────────────────────────
class _MobileCard extends StatelessWidget {
  final TSlot slot;
  final TSession? session;
  const _MobileCard({required this.slot, this.session});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Time column
      SizedBox(
        width: 52,
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          const SizedBox(height: 10),
          Text(slot.start, style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w800, color: _ink)),
          Text(slot.end, style: TextStyle(
              fontSize: 10, color: _muted.withOpacity(.65))),
        ]),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: session == null
            ? Container(
                height: 62,
                decoration: BoxDecoration(
                  color: _white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border),
                ),
                child: Center(child: Text('Libre', style: TextStyle(
                    color: _muted.withOpacity(.4), fontSize: 12,
                    fontStyle: FontStyle.italic))),
              )
            : _buildSessionCard(session!),
      ),
    ]);
  }

  Widget _buildSessionCard(TSession s) {
    final meta = getSubjectMeta(s.matiere);
    final seed = s.id.hashCode;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [meta.color, meta.color.withOpacity(.8)],
          ),
        ),
        child: Stack(children: [
          Positioned.fill(child: CustomPaint(
              painter: _StudentSymbolsPainter(meta, seed))),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 10),
            child: Row(children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(s.matiere, style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w900, color: _white)),
                  const SizedBox(height: 3),
                  Row(children: [
                    const Icon(Icons.person_outline_rounded, size: 11, color: Color(0xCCFFFFFF)),
                    const SizedBox(width: 3),
                    Expanded(child: Text(s.enseignant,
                        style: const TextStyle(fontSize: 11, color: Color(0xCCFFFFFF)),
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.room_outlined, size: 11, color: Color(0xBBFFFFFF)),
                    const SizedBox(width: 3),
                    Text(s.salle, style: const TextStyle(fontSize: 11, color: Color(0xBBFFFFFF))),
                    if (s.filieres.length > 1) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(s.filieres.join(' · '), style: const TextStyle(
                            fontSize: 9, color: _white, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ]),
                ],
              )),
              // Time badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(children: [
                  Text(s.slot.start, style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w900, color: _white)),
                  Container(width: 14, height: 1, color: Colors.white.withOpacity(.5)),
                  Text(s.slot.end, style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xCCFFFFFF))),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
