import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/data/timetable_data.dart' show SubjectMeta, getSubjectMeta;
import '../../../../shared/widgets/scol_shimmer.dart';

// Schedule page uses scaffoldBackgroundColor for bg so it follows dark/light theme
const _white  = Colors.white;
const _ink    = Color(0xFF1A0A00);
const _muted  = Color(0xFF7A5C44);
const _border = Color(0xFFDDCCBB);
const _terra  = ScolarisPalette.terracotta;
const _gold   = ScolarisPalette.gold;

const _joursAll = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];

/// Créneau horaire (dérivé dynamiquement des cours réels de la classe).
class _Slot {
  final String start, end;
  const _Slot(this.start, this.end);
}

// ─── Page ─────────────────────────────────────────────────────────────────────
class SchedulePage extends ConsumerStatefulWidget {
  const SchedulePage({super.key});

  @override
  ConsumerState<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends ConsumerState<SchedulePage> {
  @override
  void dispose() {
    // Restore portrait when leaving the page
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myStudentProfileProvider);
    final bg = Theme.of(context).scaffoldBackgroundColor;

    return Container(
      color: bg,
      child: profileAsync.when(
        loading: () => const ScolSkeletonList(count: 8, itemHeight: 68),
        error: (e, _) => _ErrorState(message: '$e'),
        data: (profile) {
          final classId = profile?.classId;
          if (classId == null || classId.isEmpty) {
            return const _NoClassState();
          }
          final schedulesAsync = ref.watch(schedulesForClassProvider(classId));
          return schedulesAsync.when(
            loading: () => const ScolSkeletonList(count: 8, itemHeight: 68),
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
  bool _landscapeSuggested = false;

  @override
  void initState() {
    super.initState();
    final wd = DateTime.now().weekday; // 1=Lun … 7=Dim
    _mobileDayIdx = (wd >= 1 && wd <= 7) ? wd - 1 : 0;
  }

  /// Toujours 7 jours (Lun → Dim). Samedi et dimanche sont toujours visibles.
  int get _dayCount => 7;

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

  void _suggestLandscape(BuildContext context) {
    if (_landscapeSuggested) return;
    _landscapeSuggested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.screen_rotation_rounded, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('Tournez l\'écran pour voir la semaine complète'),
          ]),
          action: SnackBarAction(
            label: 'Activer',
            textColor: _gold,
            onPressed: () {
              SystemChrome.setPreferredOrientations([
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ]);
            },
          ),
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    });
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
          child: OrientationBuilder(builder: (ctx, orientation) {
            return LayoutBuilder(builder: (ctx2, box) {
              final isWide = box.maxWidth >= 680 ||
                  orientation == Orientation.landscape;

              if (!isWide) {
                _suggestLandscape(context);
              }

              return isWide
                  ? _WeekTableView(
                      schedules: widget.schedules, jours: _jours, slots: slots,
                      onExitLandscape: orientation == Orientation.landscape
                          ? () {
                              // Lock back to portrait only
                              SystemChrome.setPreferredOrientations([
                                DeviceOrientation.portraitUp,
                                DeviceOrientation.portraitDown,
                              ]);
                            }
                          : null,
                    )
                  : _MobileDayView(
                      schedules: widget.schedules,
                      jours: _jours,
                      slots: slots,
                      dayIdx: _mobileDayIdx.clamp(0, _dayCount - 1),
                      onDayChanged: (i) => setState(() => _mobileDayIdx = i),
                    );
            });
          }),
        ),
    ]);
  }
}

int _todayDay() {
  final wd = DateTime.now().weekday;
  return (wd >= 1 && wd <= 7) ? wd : 1; // 1=Lun … 7=Dim
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
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surface,
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
          Text('Emploi du Temps',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: cs.onSurface)),
          Text('$courseCount cours cette semaine',
              style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant)),
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

// ─── Full week table (PC + tablet + landscape) ────────────────────────────────
class _WeekTableView extends StatelessWidget {
  final List<SbSchedule> schedules;
  final List<String> jours;
  final List<_Slot> slots;
  final VoidCallback? onExitLandscape;
  const _WeekTableView(
      {required this.schedules, required this.jours, required this.slots, this.onExitLandscape});

  @override
  Widget build(BuildContext context) {
    const timeW = 58.0;
    const rowH  = 96.0;
    final today = _todayDay();
    final cs    = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      child: Column(children: [
        // Exit landscape button
        if (onExitLandscape != null)
          Container(
            color: cs.surface,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton.icon(
                onPressed: onExitLandscape,
                icon: const Icon(Icons.screen_lock_portrait_rounded, size: 14),
                label: const Text('Portrait', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: _muted),
              ),
            ]),
          ),

        const Divider(height: 1, color: _border),
        // ── Day header row ──
        Container(
          color: cs.surface,
          child: Row(children: [
            SizedBox(width: timeW,
                child: Padding(padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Center(child: Text('Heure',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700,
                            color: _muted.withValues(alpha: .6)))))),
            ...List.generate(jours.length, (idx) {
              final day = idx + 1;
              final isTod = day == today;
              final isWeekend = day >= 6;
              final dayHasCourses = schedules.any((s) => s.dayOfWeek == day);
              final isHoliday = isWeekend && !dayHasCourses;
              return Expanded(
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isHoliday
                        ? cs.surfaceContainerHighest.withValues(alpha: .35)
                        : (isTod ? _terra.withValues(alpha: .06) : null),
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
                            color: isTod ? _terra
                                : isHoliday ? cs.onSurfaceVariant
                                : cs.onSurface)),
                    if (isHoliday) ...[
                      const SizedBox(height: 2),
                      Text(day == 7 ? 'Dimanche' : 'Fermé',
                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600,
                              color: cs.outlineVariant, letterSpacing: 0.3)),
                    ],
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
                width: timeW, color: cs.surface,
                alignment: Alignment.center,
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(slot.start, style: TextStyle(
                      fontSize: 11.5, fontWeight: FontWeight.w800, color: cs.onSurface)),
                  Text(slot.end, style: TextStyle(
                      fontSize: 10, color: _muted.withValues(alpha: .65))),
                ]),
              ),
              ...List.generate(jours.length, (idx) {
                final day = idx + 1;
                final session = _at(schedules, day, slot);
                final dayHasCourses = schedules.any((s) => s.dayOfWeek == day);
                final isWeekend = day >= 6;
                return Expanded(child: _TableCell(
                  session: session,
                  isToday: day == today,
                  isHoliday: isWeekend && !dayHasCourses,
                  holidayLabel: day == 7 ? 'DIMANCHE' : 'SAMEDI',
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
  final bool isHoliday;
  final String holidayLabel;
  const _TableCell({
    this.session,
    required this.isToday,
    this.isHoliday = false,
    this.holidayLabel = '',
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (session == null) {
      return Container(
        decoration: BoxDecoration(
          color: isHoliday
              ? cs.surfaceContainerHighest.withValues(alpha: .45)
              : (isToday ? _terra.withValues(alpha: .025) : cs.surface),
          border: const Border(left: BorderSide(color: _border)),
        ),
        child: isHoliday
            ? ClipRect(
                child: CustomPaint(
                  painter: _DiagonalTextPainter(
                    holidayLabel,
                    cs.onSurface.withValues(alpha: .08),
                  ),
                  child: const SizedBox.expand(),
                ),
              )
            : null,
      );
    }

    final s    = session!;
    final name = s.subjectName ?? 'Cours';
    final meta = getSubjectMeta(name);
    final seed = s.id.hashCode;

    return Container(
      decoration: BoxDecoration(
        color: isToday ? _terra.withValues(alpha: .025) : cs.surface,
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

// ─── Holiday diagonal painter ─────────────────────────────────────────────────
/// Peint un grand texte en diagonale du bas-gauche vers le haut-droit.
class _DiagonalTextPainter extends CustomPainter {
  final String text;
  final Color color;
  const _DiagonalTextPainter(this.text, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: 4,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout(maxWidth: size.width * 1.5);
    final angle = -atan2(size.height, size.width);
    canvas.save();
    canvas.translate(4, size.height - 6);
    canvas.rotate(angle);
    tp.paint(canvas, Offset.zero);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DiagonalTextPainter o) => o.text != text;
}

/// Overlay plein-écran avec un texte diagonal + fond légèrement teinté.
class _HolidayOverlay extends StatelessWidget {
  final String label;   // ex. 'DIMANCHE', 'SAMEDI'
  const _HolidayOverlay(this.label);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textColor = cs.onSurface.withValues(alpha: .14);
    return Stack(children: [
      // Fond légèrement teinté
      Positioned.fill(
        child: Container(color: cs.surfaceContainerHighest.withValues(alpha: .3)),
      ),
      // Grand texte diagonal
      Positioned.fill(
        child: CustomPaint(painter: _DiagonalTextPainter(label, textColor)),
      ),
      // Icône centrée
      Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            label == 'DIMANCHE'
                ? Icons.self_improvement_rounded
                : Icons.weekend_rounded,
            size: 28, color: cs.outlineVariant,
          ),
          const SizedBox(height: 4),
          Text(
            label == 'DIMANCHE' ? 'Pas de cours' : 'Cours selon l\'établissement',
            style: TextStyle(fontSize: 10, color: cs.outlineVariant, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ]),
      ),
    ]);
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
    final cs = Theme.of(context).colorScheme;
    final subjects = schedules
        .map((s) => s.subjectName)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();
    if (subjects.isEmpty) return const SizedBox.shrink();
    return Container(
      color: cs.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Matières', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800,
            color: cs.onSurfaceVariant, letterSpacing: 0.3)),
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
    final cs    = Theme.of(context).colorScheme;
    final day   = dayIdx + 1;
    final daySessions = schedules.where((s) => s.dayOfWeek == day).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    return Column(children: [
      // Day tabs
      Container(
        color: cs.surface,
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
                color: sel ? _terra : (isTod ? _terra.withValues(alpha: .08) : cs.surfaceContainerHighest),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: sel ? _terra : (isTod ? _terra.withValues(alpha: .3) : cs.outlineVariant)),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(jours[i].substring(0, 3).toUpperCase(),
                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800,
                        color: sel ? _white : (isTod ? _terra : _muted), letterSpacing: 0.3)),
                const SizedBox(height: 2),
                Text('$count', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900,
                    color: sel ? _white : (isTod ? _terra : cs.onSurface))),
              ]),
            ),
          ));
        })),
      ),
      const Divider(height: 1, color: _border),

      // Day sessions
      Expanded(
        child: daySessions.isEmpty
            ? (day >= 6
                ? _HolidayOverlay(day == 7 ? 'DIMANCHE' : 'SAMEDI')
                : Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.event_available_rounded, size: 40, color: cs.outlineVariant),
                      const SizedBox(height: 10),
                      Text('Aucun cours ce jour', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
                    ]),
                  ))
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
    final cs = Theme.of(context).colorScheme;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        width: 52,
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          const SizedBox(height: 10),
          Text(s.startTime, style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w800, color: cs.onSurface)),
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
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.calendar_month_rounded, size: 48, color: cs.outlineVariant),
        const SizedBox(height: 12),
        Text('Emploi du temps non publié',
            style: TextStyle(color: cs.onSurface, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Il apparaîtra ici dès que l\'école l\'aura mis en ligne.',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
      ]),
    );
  }
}

class _NoClassState extends StatelessWidget {
  const _NoClassState();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.class_outlined, size: 48, color: cs.outlineVariant),
          const SizedBox(height: 12),
          Text('Aucune classe assignée',
              style: TextStyle(color: cs.onSurface, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Contacte l\'administration pour être affecté à une classe.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
        ]),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline_rounded, size: 44, color: _terra),
          const SizedBox(height: 12),
          Text('Erreur de chargement',
              style: TextStyle(color: cs.onSurface, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(message,
              textAlign: TextAlign.center,
              maxLines: 3, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
        ]),
      ),
    );
  }
}
