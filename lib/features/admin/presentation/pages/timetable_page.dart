import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';

const _terra = Color(0xFF8B1A00);

const _days = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];

class TimetablePage extends ConsumerStatefulWidget {
  const TimetablePage({super.key});
  @override
  ConsumerState<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends ConsumerState<TimetablePage> {
  String? _classId;

  void _openAdd(String schoolId, int dayOfWeek) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _SessionSheet(
        schoolId: schoolId,
        classId: _classId!,
        dayOfWeek: dayOfWeek,
        onSaved: () => ref.invalidate(schedulesForClassProvider(_classId!)),
      ),
    );
  }

  void _openEdit(String schoolId, SbSchedule s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _SessionSheet(
        schoolId: schoolId,
        classId: _classId!,
        dayOfWeek: s.dayOfWeek,
        existing: s,
        onSaved: () => ref.invalidate(schedulesForClassProvider(_classId!)),
      ),
    );
  }

  Future<void> _delete(SbSchedule s) async {
    try {
      await SupabaseDbSource.deleteSchedule(s.id);
      ref.invalidate(schedulesForClassProvider(_classId!));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Suppression impossible : $e'),
            backgroundColor: _terra));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = ref.watch(currentSchoolIdProvider);
    final classesAsync = ref.watch(classesProvider);

    return PageScaffold(
      title: 'Emploi du temps',
      subtitle: 'Cours hebdomadaires par classe',
      child: classesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (classes) {
          if (classes.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                  child: Text('Créez d\'abord une classe.',
                      style: TextStyle(color: muted))),
            );
          }
          _classId ??= classes.first.id;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sélecteur de classe
              DataPanel(
                title: 'Classe',
                child: DropdownButtonFormField<String>(
                  initialValue: _classId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.class_outlined),
                      border: OutlineInputBorder()),
                  items: [
                    for (final c in classes)
                      DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ],
                  onChanged: (v) => setState(() => _classId = v),
                ),
              ),
              const SizedBox(height: 14),
              if (schoolId != null && _classId != null)
                _WeekView(
                  classId: _classId!,
                  onAdd: (day) => _openAdd(schoolId, day),
                  onDelete: _delete,
                  onEdit: (s) => _openEdit(schoolId, s),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _WeekView extends ConsumerWidget {
  final String classId;
  final ValueChanged<int> onAdd;
  final ValueChanged<SbSchedule> onDelete;
  final ValueChanged<SbSchedule> onEdit;
  const _WeekView(
      {required this.classId, required this.onAdd, required this.onDelete, required this.onEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedulesAsync = ref.watch(schedulesForClassProvider(classId));
    return schedulesAsync.when(
      loading: () => const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator())),
      error: (e, _) => Text('Erreur : $e'),
      data: (sessions) {
        return Column(
          children: [
            for (var day = 1; day <= 6; day++) ...[
              _DaySection(
                day: day,
                sessions: sessions.where((s) => s.dayOfWeek == day).toList(),
                onAdd: () => onAdd(day),
                onDelete: onDelete,
                onEdit: onEdit,
              ),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

class _DaySection extends StatelessWidget {
  final int day;
  final List<SbSchedule> sessions;
  final VoidCallback onAdd;
  final ValueChanged<SbSchedule> onDelete;
  final ValueChanged<SbSchedule> onEdit;
  const _DaySection(
      {required this.day,
      required this.sessions,
      required this.onAdd,
      required this.onDelete,
      required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return DataPanel(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(children: [
            Text(_days[day - 1],
                style: const TextStyle(
                    color: ink, fontSize: 13.5, fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            Text('${sessions.length} cours',
                style: const TextStyle(fontSize: 11, color: muted)),
            const Spacer(),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 16, color: _terra),
              label: const Text('Ajouter',
                  style: TextStyle(
                      color: _terra,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        if (sessions.isNotEmpty) const Divider(height: 1, color: border),
        for (final s in sessions)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: Color(0xFFF0E8DC)))),
            child: Row(children: [
              Container(
                width: 4,
                height: 38,
                decoration: BoxDecoration(
                    color: _terra.withValues(alpha: .6),
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 88,
                child: Text('${s.startTime} – ${s.endTime}',
                    style: const TextStyle(
                        fontSize: 12,
                        color: ink,
                        fontWeight: FontWeight.w700)),
              ),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.subjectName ?? 'Matière',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 1),
                      Text([
                        if (s.teacherName != null) s.teacherName,
                        if (s.room != null && s.room!.isNotEmpty)
                          'Salle ${s.room}',
                      ].join(' · '),
                          style: const TextStyle(fontSize: 11, color: muted)),
                    ]),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 17, color: muted),
                tooltip: 'Modifier',
                onPressed: () => onEdit(s),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 17, color: muted),
                tooltip: 'Supprimer',
                onPressed: () => onDelete(s),
              ),
            ]),
          ),
      ]),
    );
  }
}

// ── Sheet : ajouter ou modifier un cours ─────────────────────────────────────
class _SessionSheet extends ConsumerStatefulWidget {
  final String schoolId;
  final String classId;
  final int dayOfWeek;
  final SbSchedule? existing;
  final VoidCallback onSaved;
  const _SessionSheet({
    required this.schoolId,
    required this.classId,
    required this.dayOfWeek,
    this.existing,
    required this.onSaved,
  });
  @override
  ConsumerState<_SessionSheet> createState() => _SessionSheetState();
}

class _SessionSheetState extends ConsumerState<_SessionSheet> {
  late String? _subjectId = widget.existing?.subjectId;
  late String? _teacherId = widget.existing?.teacherId;
  late final _room = TextEditingController(text: widget.existing?.room ?? '');
  late TimeOfDay _start = _parseTime(widget.existing?.startTime) ?? const TimeOfDay(hour: 8, minute: 0);
  late TimeOfDay _end   = _parseTime(widget.existing?.endTime)   ?? const TimeOfDay(hour: 9, minute: 0);
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  TimeOfDay? _parseTime(String? hhmm) {
    if (hhmm == null) return null;
    final parts = hhmm.split(':');
    if (parts.length < 2) return null;
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  @override
  void dispose() {
    _room.dispose();
    super.dispose();
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pick(bool start) async {
    final picked = await showTimePicker(
        context: context, initialTime: start ? _start : _end);
    if (picked != null) {
      setState(() => start ? _start = picked : _end = picked);
    }
  }

  Future<void> _submit() async {
    if (_subjectId == null) {
      setState(() => _error = 'Choisissez une matière.');
      return;
    }
    final startM = _start.hour * 60 + _start.minute;
    final endM = _end.hour * 60 + _end.minute;
    if (endM <= startM) {
      setState(() => _error = 'L\'heure de fin doit être après le début.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    try {
      if (_isEdit) {
        await SupabaseDbSource.updateSchedule(
          id: widget.existing!.id,
          subjectId: _subjectId,
          teacherId: _teacherId,
          startTime: _fmt(_start),
          endTime: _fmt(_end),
          room: _room.text.trim(),
        );
      } else {
        await SupabaseDbSource.createSchedule(
          schoolId: widget.schoolId,
          classId: widget.classId,
          subjectId: _subjectId,
          teacherId: _teacherId,
          dayOfWeek: widget.dayOfWeek,
          startTime: _fmt(_start),
          endTime: _fmt(_end),
          room: _room.text.trim(),
        );
      }
      widget.onSaved();
      if (mounted) navigator.pop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subjectsAsync = ref.watch(subjectsProvider);
    final teachersAsync = ref.watch(teachersProvider);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
              color: const Color(0xFFE0D5C8),
              borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: Text('${_isEdit ? "Modifier" : "Nouveau cours"} — ${_days[widget.dayOfWeek - 1]}',
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800, color: ink)),
        ),
        const SizedBox(height: 16),
        // Matière
        subjectsAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Matières indisponibles : $e',
              style: const TextStyle(color: _terra, fontSize: 12)),
          data: (subjects) => DropdownButtonFormField<String>(
            initialValue: _subjectId,
            isExpanded: true,
            decoration: const InputDecoration(
                labelText: 'Matière',
                prefixIcon: Icon(Icons.menu_book_outlined)),
            items: [
              for (final s in subjects)
                DropdownMenuItem(value: s.id, child: Text(s.name)),
            ],
            onChanged: (v) => setState(() => _subjectId = v),
          ),
        ),
        const SizedBox(height: 12),
        // Enseignant (optionnel)
        teachersAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (teachers) => DropdownButtonFormField<String>(
            initialValue: _teacherId,
            isExpanded: true,
            decoration: const InputDecoration(
                labelText: 'Enseignant (optionnel)',
                prefixIcon: Icon(Icons.co_present_outlined)),
            items: [
              const DropdownMenuItem(value: null, child: Text('—')),
              for (final t in teachers)
                DropdownMenuItem(value: t.id, child: Text(t.fullName)),
            ],
            onChanged: (v) => setState(() => _teacherId = v),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _TimeField(label: 'Début', value: _fmt(_start), onTap: () => _pick(true))),
          const SizedBox(width: 12),
          Expanded(child: _TimeField(label: 'Fin', value: _fmt(_end), onTap: () => _pick(false))),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: _room,
          decoration: const InputDecoration(
              labelText: 'Salle (optionnel)',
              prefixIcon: Icon(Icons.meeting_room_outlined)),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(_error!,
                style: const TextStyle(color: _terra, fontSize: 12.5)),
          ),
        ],
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _saving ? null : _submit,
            style: FilledButton.styleFrom(
                backgroundColor: _terra,
                padding: const EdgeInsets.symmetric(vertical: 14)),
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(_isEdit ? 'Enregistrer' : 'Ajouter le cours'),
          ),
        ),
      ]),
    );
  }
}

class _TimeField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  const _TimeField(
      {required this.label, required this.value, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.schedule_rounded),
            border: const OutlineInputBorder()),
        child: Text(value, style: const TextStyle(fontSize: 14, color: ink)),
      ),
    );
  }
}
