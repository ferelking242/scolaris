import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/data/timetable_data.dart' show SubjectMeta, getSubjectMeta;

const _bg     = Color(0xFFF5EEE6);
const _white  = Colors.white;
const _ink    = Color(0xFF1A0A00);
const _muted  = Color(0xFF7A5C44);
const _border = Color(0xFFDDCCBB);
const _terra  = ScolarisPalette.terracotta;
const _gold   = ScolarisPalette.gold;

const _joursAll = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];

/// Créneau horaire (dérivé dynamiquement des cours réels de la classe).
class _Slot {
  final String start, end;
  const _Slot(this.start, this.end);
}

// ─── Page ─────────────────────────────────────────────────────────────────────
class SchedulePage extends ConsumerWidget {
  const SchedulePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(myStudentProfileProvider);

    return Container(
      color: _bg,
      child: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(message: '$e'),
        data: (profile) {
          final classId = profile?.classId;
          if (classId == null || classId.isEmpty) {
            return const _NoClassState();
          }
          final schedulesAsync = ref.watch(schedulesForClassProvider(classId));
          return schedulesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _ErrorState(message: '$e'),
            data: (schedules) => _ScheduleView(
              schedules: schedules,
              className: profile?.classe ?? 'Ma classe',
            ),
          );
        },
      ),
    );
  }
}

// ─── Vue emploi du temps ───────────────────────────────────────────────────────
class _ScheduleView extends StatefulWidget {
  final List<SbSchedule> schedules;
  final String className;
  const _ScheduleView({required this.schedules, required this.className});

  @override
  State<_ScheduleView> createState() => _ScheduleViewState();
}

class _ScheduleViewState extends State<_ScheduleView> {
  int _mobileDayIdx = 0;

  @override
  void initState() {
    super.initState();
    final wd = DateTime.now().weekday; // 1=Lun … 7=Dim
    _mobileDayIdx = (wd >= 1 && wd <= 6) ? wd - 1 : 0;
  }

  /// Nombre de jours affichés : 5 (Lun-Ven) ou 6 si des cours le samedi.
  int get _dayCount {
    final maxDay = widget.schedules.fold<int>(
        5, (m, s) => s.dayOfWeek > m ? s.dayOfWeek : m);
    return maxDay.clamp(5, 6);
  }

  List<String> get _jours => _joursAll.take(_dayCount).toList();

  /// Créneaux distincts, triés par heure de début.
  List<_Slot> get _slots {
    final map = <String, _Slot>{};
    for (final s in widget.schedules) {
      map[s.startTime] = _Slot(s.startTime, s.endTime);
    }
    final list = map.values.toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final slots = _slots;
    return Column(children: [
      _Header(
        className: widget.className,
        courseCount: widget.schedules.length,
      ),
      if (slots.isEmpty)
        const Expanded(child: _EmptySchedule())
      else
        Expanded(
          child: LayoutBuilder(builder: (ctx, box) {
            return box.maxWidth >= 680
                ? _WeekTableView(
                    schedules: widget.schedules, jours: _jours, slots: slots)
                : _MobileDayView(
                    schedules: widget.schedules,
                    jours: _jours,
                    slots: slots,
                    dayIdx: _mobileDayIdx.clamp(0, _dayCount - 1),
                    onDayChanged: (i) => setState(() => _mobileDayIdx = i),
                  );
          }),
        ),
    ]);
  }
}

int _todayDay() {
  final wd = DateTime.now().weekday;
  return (wd >= 1 && wd <= 6) ? wd : 0; // 1-based, 0 = week-end
}

SbSchedule? _at(List<SbSchedule> schedules, int day, _Slot slot) =>
    schedules
        .where((s) => s.dayOfWeek == day && s.startTime == slot.start)
        .firstOrNull;

// ─── Header ───────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final String className;
  final int courseCount;
  const _Header({required this.className, required this.courseCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF8B1A00), Color(0xFFD4540A)]),
            borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.calendar_today_rounded, color: _white, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Emploi du Temps',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _ink)),
          Text('$courseCount cours cette semaine',
              style: const TextStyle(fontSize: 11.5, color: _muted)),
        ])),
        // Classe réelle de l'élève (lecture seule).
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _terra.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _terra.withValues(alpha: .25)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.class_rounded, size: 14, color: _terra),
            const SizedBox(width: 5),
            Text(className,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _terra)),
          ]),
        ),
      ]),
    );
  }
}

// ─── Full week table (PC + tablet) ───────────────────────────────────────────
class _WeekTableView extends StatelessWidget {
  final List<SbSchedule> schedules;
  final List<String> jours;
  final List<_Slot> slots;
  const _WeekTableView(
      {required this.schedules, required this.jours, required this.slots});

  @override
  Widget build(BuildContext context) {
    const timeW = 58.0;
    const rowH  = 96.0;
    final today = _todayDay();

    return SingleChildScrollView(
      child: Column(children: [
        const Divider(height: 1, color: _border),
        // ── Day header row ──
        Container(
          color: _white,
          child: Row(children: [
            SizedBox(width: timeW,
                child: Padding(padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Center(child: Text('Heure',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700,
                            color: _muted.withValues(alpha: .6)))))),
            ...List.generate(jours.length, (idx) {
              final isTod = (idx + 1) == today;
              return Expanded(
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isTod ? _terra.withValues(alpha: .06) : null,
                    border: const Border(left: BorderSide(color: _border)),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    if (isTod)
                      Container(
                        width: 6, height: 6, margin: const EdgeInsets.only(bottom: 3),
                        decoration: const BoxDecoration(color: _terra, shape: BoxShape.circle),
                      ),
                    Text(jours[idx],
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
        ...slots.map((slot) => Column(children: [
          SizedBox(
            height: rowH,
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(
                width: timeW, color: _white,
                alignment: Alignment.center,
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(slot.start, style: const TextStyle(
                      fontSize: 11.5, fontWeight: FontWeight.w800, color: _ink)),
                  Text(slot.end, style: TextStyle(
                      fontSize: 10, color: _muted.withValues(alpha: .65))),
                ]),
              ),
              ...List.generate(jours.length, (idx) {
                final day = idx + 1;
                final session = _at(schedules, day, slot);
                return Expanded(child: _TableCell(
                  session: session,
                  isToday: day == today,
                ));
              }),
            ]),
          ),
          const Divider(height: 1, color: _border),
        ])),

        _Legend(schedules: schedules),
        const SizedBox(height: 16),
      ]),
    );
  }
}

// ─── Table cell ───────────────────────────────────────────────────────────────
class _TableCell extends StatelessWidget {
  final SbSchedule? session;
  final bool isToday;
  const _TableCell({this.session, required this.isToday});

  @override
  Widget build(BuildContext context) {
    if (session == null) {
      return Container(
        decoration: BoxDecoration(
          color: isToday ? _terra.withValues(alpha: .025) : _white,
          border: const Border(left: BorderSide(color: _border)),
        ),
      );
    }

    final s    = session!;
    final name = s.subjectName ?? 'Cours';
    final meta = getSubjectMeta(name);
    final seed = s.id.hashCode;

    return Container(
      decoration: BoxDecoration(
        color: isToday ? _terra.withValues(alpha: .025) : _white,
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
              colors: [meta.color, meta.color.withValues(alpha: .82)],
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(color: meta.color.withValues(alpha: .2), blurRadius: 4, offset: const Offset(0, 1)),
            ],
          ),
          child: Stack(children: [
            Positioned.fill(child: CustomPaint(
              painter: _StudentSymbolsPainter(meta, seed),
            )),
            if (isToday)
              Positioned(top: 0, left: 0, right: 0,
                child: Container(
                  height: 3,
                  decoration: const BoxDecoration(
                    color: _gold,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                  ),
                )),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w900,
                          color: _white, height: 1.2),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  if (s.teacherName != null)
                    Row(children: [
                      const Icon(Icons.person_outline_rounded, size: 9, color: Color(0xCCFFFFFF)),
                      const SizedBox(width: 2),
                      Expanded(child: Text(s.teacherName!,
                          style: const TextStyle(fontSize: 9, color: Color(0xCCFFFFFF)),
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ]),
                  const SizedBox(height: 2),
                  if (s.room != null)
                    Row(children: [
                      const Icon(Icons.room_outlined, size: 9, color: Color(0xBBFFFFFF)),
                      const SizedBox(width: 2),
                      Text(s.room!, style: const TextStyle(fontSize: 9, color: Color(0xBBFFFFFF))),
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

// ─── Student symbols painter ──────────────────────────────────────────────────
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
          fontSize: sz, color: Colors.white.withValues(alpha: op),
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
  final List<SbSchedule> schedules;
  const _Legend({required this.schedules});

  @override
  Widget build(BuildContext context) {
    final subjects = schedules
        .map((s) => s.subjectName)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();
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
                color: meta.color.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: meta.color.withValues(alpha: .25)),
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
  final List<SbSchedule> schedules;
  final List<String> jours;
  final List<_Slot> slots;
  final int dayIdx;
  final ValueChanged<int> onDayChanged;
  const _MobileDayView({
    required this.schedules,
    required this.jours,
    required this.slots,
    required this.dayIdx,
    required this.onDayChanged,
  });

  @override
  Widget build(BuildContext context) {
    final today = _todayDay();
    final day   = dayIdx + 1;
    final daySessions = schedules.where((s) => s.dayOfWeek == day).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    return Column(children: [
      // Day tabs
      Container(
        color: _white,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(children: List.generate(jours.length, (i) {
          final sel   = i == dayIdx;
          final isTod = (i + 1) == today;
          final count = schedules.where((s) => s.dayOfWeek == i + 1).length;
          return Expanded(child: GestureDetector(
            onTap: () => onDayChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                color: sel ? _terra : (isTod ? _terra.withValues(alpha: .08) : _bg),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: sel ? _terra : (isTod ? _terra.withValues(alpha: .3) : _border)),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(jours[i].substring(0, 3).toUpperCase(),
                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800,
                        color: sel ? _white : (isTod ? _terra : _muted), letterSpacing: 0.3)),
                const SizedBox(height: 2),
                Text('$count', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900,
                    color: sel ? _white : (isTod ? _terra : _ink))),
              ]),
            ),
          ));
        })),
      ),
      const Divider(height: 1, color: _border),

      // Day sessions
      Expanded(
        child: daySessions.isEmpty
            ? Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.event_available_rounded, size: 40, color: _border),
                  const SizedBox(height: 10),
                  const Text('Aucun cours ce jour', style: TextStyle(color: _muted, fontSize: 14)),
                ]),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(14),
                itemCount: daySessions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _MobileCard(session: daySessions[i]),
              ),
      ),
    ]);
  }
}

// ─── Mobile session card ──────────────────────────────────────────────────────
class _MobileCard extends StatelessWidget {
  final SbSchedule session;
  const _MobileCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final s = session;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        width: 52,
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          const SizedBox(height: 10),
          Text(s.startTime, style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w800, color: _ink)),
          Text(s.endTime, style: TextStyle(
              fontSize: 10, color: _muted.withValues(alpha: .65))),
        ]),
      ),
      const SizedBox(width: 10),
      Expanded(child: _buildSessionCard(s)),
    ]);
  }

  Widget _buildSessionCard(SbSchedule s) {
    final name = s.subjectName ?? 'Cours';
    final meta = getSubjectMeta(name);
    final seed = s.id.hashCode;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minHeight: 80),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [meta.color, meta.color.withValues(alpha: .8)],
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
                  Text(name, style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w900, color: _white)),
                  const SizedBox(height: 3),
                  if (s.teacherName != null)
                    Row(children: [
                      const Icon(Icons.person_outline_rounded, size: 11, color: Color(0xCCFFFFFF)),
                      const SizedBox(width: 3),
                      Expanded(child: Text(s.teacherName!,
                          style: const TextStyle(fontSize: 11, color: Color(0xCCFFFFFF)),
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ]),
                  const SizedBox(height: 2),
                  if (s.room != null)
                    Row(children: [
                      const Icon(Icons.room_outlined, size: 11, color: Color(0xBBFFFFFF)),
                      const SizedBox(width: 3),
                      Text(s.room!, style: const TextStyle(fontSize: 11, color: Color(0xBBFFFFFF))),
                    ]),
                ],
              )),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(children: [
                  Text(s.startTime, style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w900, color: _white)),
                  Container(width: 14, height: 1, color: Colors.white.withValues(alpha: .5)),
                  Text(s.endTime, style: const TextStyle(
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

// ─── États (vide / pas de classe / erreur) ─────────────────────────────────────
class _EmptySchedule extends StatelessWidget {
  const _EmptySchedule();
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.calendar_month_rounded, size: 48, color: _border),
          const SizedBox(height: 12),
          const Text('Emploi du temps non publié',
              style: TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Il apparaîtra ici dès que l\'école l\'aura mis en ligne.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 12.5)),
        ]),
      );
}

class _NoClassState extends StatelessWidget {
  const _NoClassState();
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.class_outlined, size: 48, color: _border),
            const SizedBox(height: 12),
            const Text('Aucune classe assignée',
                style: TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Contacte l\'administration pour être affecté à une classe.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, fontSize: 12.5)),
          ]),
        ),
      );
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.error_outline_rounded, size: 44, color: _terra),
            const SizedBox(height: 12),
            Text('Erreur de chargement',
                style: const TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(message,
                textAlign: TextAlign.center,
                maxLines: 3, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _muted, fontSize: 12)),
          ]),
        ),
      );
}
