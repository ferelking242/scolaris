import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/permissions/my_grants.dart';
import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';

/// Présences côté staff : contrairement à `AttendanceTodayPage` (prof, limité
/// à ses classes assignées), ici toutes les classes de l'école sont visibles —
/// c'est l'écran du surveillant/secrétariat qui fait ou supervise l'appel.
/// Même mécanique d'écriture (`SupabaseDbSource.saveAttendance`), même garde
/// fine `presences.saisir` : un membre avec seulement `presences.voir`
/// consulte sans pouvoir modifier.
enum _Status { present, late, absent }

class AdminAttendancePage extends ConsumerStatefulWidget {
  const AdminAttendancePage({super.key});
  @override
  ConsumerState<AdminAttendancePage> createState() =>
      _AdminAttendancePageState();
}

class _AdminAttendancePageState extends ConsumerState<AdminAttendancePage> {
  String? _selectedClassId;
  Map<String, _Status> _statusMap = {};
  String? _seededClassId;

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(classesProvider);

    return classesAsync.when(
      loading: () => const PageScaffold(
        title: 'Présences',
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => PageScaffold(
        title: 'Présences',
        child: Center(child: Text('Erreur : $e')),
      ),
      data: (classes) {
        if (classes.isNotEmpty &&
            (_selectedClassId == null ||
                !classes.any((c) => c.id == _selectedClassId))) {
          _selectedClassId = classes.first.id;
        }
        return _buildContent(classes);
      },
    );
  }

  Widget _buildContent(List<SbClass> classes) {
    final selectedClass = classes.isEmpty
        ? null
        : classes.firstWhere(
            (c) => c.id == _selectedClassId,
            orElse: () => classes.first,
          );

    if (selectedClass == null) {
      return const PageScaffold(
        title: 'Présences',
        child: Center(child: Text('Aucune classe dans cette école.')),
      );
    }

    final studentsAsync =
        ref.watch(studentsByClassProvider(selectedClass.name));
    final attendanceAsync =
        ref.watch(attendanceForClassProvider(selectedClass.id));

    // Pré-remplir le pointage déjà saisi aujourd'hui (une fois par classe) —
    // reflète ce qui est en base au lieu du défaut « présent implicite ».
    final todayRecords = attendanceAsync.valueOrNull;
    if (todayRecords != null && _seededClassId != selectedClass.id) {
      _seededClassId = selectedClass.id;
      _statusMap = {
        for (final r in todayRecords)
          r.studentId: r.status == 'late'
              ? _Status.late
              : r.status == 'absent'
                  ? _Status.absent
                  : _Status.present,
      };
    }

    return studentsAsync.when(
      loading: () => const PageScaffold(
        title: 'Présences',
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => PageScaffold(
        title: 'Présences',
        child: Center(child: Text('Erreur : $e')),
      ),
      data: (students) {
        final present =
            _statusMap.values.where((s) => s == _Status.present).length;
        final late = _statusMap.values.where((s) => s == _Status.late).length;
        final absent =
            _statusMap.values.where((s) => s == _Status.absent).length;

        final canSaisir = ref.watch(canProvider('presences.saisir'));

        return PageScaffold(
          title: 'Présences',
          subtitle: canSaisir
              ? 'Marquez présent, retard ou absent — par classe'
              : 'Consultation seule — la saisie ne vous est pas confiée',
          actions: [
            if (canSaisir)
              ActionButton(
                  label: 'Enregistrer',
                  icon: Icons.check_rounded,
                  primary: true,
                  onTap: () => _save(students, selectedClass.id)),
          ],
          child: Column(children: [
            _ClassPicker(
              classes: classes,
              selectedId: _selectedClassId,
              onChanged: (id) => setState(() {
                _selectedClassId = id;
                _statusMap = {};
              }),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: _SummaryCard(
                      label: 'Présents',
                      value: present,
                      color: const Color(0xFF16A34A))),
              const SizedBox(width: 12),
              Expanded(
                  child: _SummaryCard(
                      label: 'Retards',
                      value: late,
                      color: const Color(0xFFEA580C))),
              const SizedBox(width: 12),
              Expanded(
                  child: _SummaryCard(
                      label: 'Absents',
                      value: absent,
                      color: const Color(0xFFDC2626))),
            ]),
            const SizedBox(height: 12),
            DataPanel(
              title: 'Liste de classe',
              headerActions: const [SearchInput(hint: 'Rechercher élève…')],
              child: students.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                          child: Text('Aucun élève.',
                              style: TextStyle(color: context.cMuted))),
                    )
                  : LayoutBuilder(builder: (_, constraints) {
                      // 3 boutons de statut dans une colonne flex débordaient
                      // sous 640px : cartes empilées à la place, comme Classes.
                      if (constraints.maxWidth < 640) {
                        return Column(children: [
                          for (final s in students)
                            _AttendanceCard(
                              student: s,
                              status: _statusMap[s.id] ?? _Status.present,
                              onChanged: canSaisir
                                  ? (v) =>
                                      setState(() => _statusMap[s.id] = v)
                                  : null,
                            ),
                        ]);
                      }
                      return DataTablePanel(
                        columns: const ['Élève', 'Classe', 'Statut'],
                        flex: const [3, 2, 4],
                        rows: [
                          for (final s in students)
                            [
                              Row(children: [
                                Avatar(name: s.fullName, size: 24),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(s.fullName,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: context.cInk,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ]),
                              Text(s.classe ?? '—',
                                  style: TextStyle(
                                      fontSize: 12, color: context.cMuted)),
                              _StatusToggle(
                                current: _statusMap[s.id] ?? _Status.present,
                                onChanged: canSaisir
                                    ? (v) =>
                                        setState(() => _statusMap[s.id] = v)
                                    : null,
                              ),
                            ],
                        ],
                      );
                    }),
            ),
          ]),
        );
      },
    );
  }

  Future<void> _save(List<SbStudent> students, String classId) async {
    final records = students.map((s) {
      final st = _statusMap[s.id] ?? _Status.present;
      return SbAttendance(
        id: '',
        studentId: s.id,
        classId: classId,
        status: st == _Status.present
            ? 'present'
            : st == _Status.late
                ? 'late'
                : 'absent',
      );
    }).toList();
    try {
      final schoolId = ref.read(currentSchoolIdProvider);
      if (schoolId == null) return;
      await SupabaseDbSource.saveAttendance(records, schoolId: schoolId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Présences enregistrées !')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
  }
}

class _AttendanceCard extends StatelessWidget {
  final SbStudent student;
  final _Status status;
  final ValueChanged<_Status>? onChanged;
  const _AttendanceCard(
      {required this.student, required this.status, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.cCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.cBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Avatar(name: student.fullName, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(student.fullName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: context.cInk,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                Text(student.classe ?? '—',
                    style: TextStyle(fontSize: 11.5, color: context.cMuted)),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            _Btn(
              label: 'Présent',
              color: const Color(0xFF16A34A),
              active: status == _Status.present,
              onTap: onChanged == null ? null : () => onChanged!(_Status.present),
            ),
            _Btn(
              label: 'Retard',
              color: const Color(0xFFEA580C),
              active: status == _Status.late,
              onTap: onChanged == null ? null : () => onChanged!(_Status.late),
            ),
            _Btn(
              label: 'Absent',
              color: const Color(0xFFDC2626),
              active: status == _Status.absent,
              onTap: onChanged == null ? null : () => onChanged!(_Status.absent),
            ),
          ]),
        ]),
      );
}

class _ClassPicker extends StatelessWidget {
  final List<SbClass> classes;
  final String? selectedId;
  final ValueChanged<String> onChanged;
  const _ClassPicker(
      {required this.classes,
      required this.selectedId,
      required this.onChanged});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final c in classes)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(c.name),
                  selected: selectedId == c.id,
                  onSelected: (_) => onChanged(c.id),
                  selectedColor:
                      const Color(0xFF8B1A00).withValues(alpha: .12),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: selectedId == c.id
                        ? const Color(0xFF8B1A00)
                        : context.cMuted,
                    fontWeight:
                        selectedId == c.id ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      );
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _SummaryCard(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.cCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.cBorder),
        ),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .15),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text('$value',
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w700, fontSize: 14)),
          ),
          const SizedBox(width: 12),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: context.cInk,
                  fontWeight: FontWeight.w600)),
        ]),
      );
}

class _StatusToggle extends StatelessWidget {
  final _Status current;
  final ValueChanged<_Status>? onChanged;
  const _StatusToggle({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Btn(
            label: 'Présent',
            color: const Color(0xFF16A34A),
            active: current == _Status.present,
            onTap: onChanged == null ? null : () => onChanged!(_Status.present),
          ),
          const SizedBox(width: 4),
          _Btn(
            label: 'Retard',
            color: const Color(0xFFEA580C),
            active: current == _Status.late,
            onTap: onChanged == null ? null : () => onChanged!(_Status.late),
          ),
          const SizedBox(width: 4),
          _Btn(
            label: 'Absent',
            color: const Color(0xFFDC2626),
            active: current == _Status.absent,
            onTap: onChanged == null ? null : () => onChanged!(_Status.absent),
          ),
        ],
      );
}

class _Btn extends StatelessWidget {
  final String label;
  final Color color;
  final bool active;
  final VoidCallback? onTap;
  const _Btn(
      {required this.label,
      required this.color,
      required this.active,
      required this.onTap});

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: active ? color : color.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: active ? color : color.withValues(alpha: .3)),
            ),
            child: Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: active ? Colors.white : color,
                    fontWeight: FontWeight.w700)),
          ),
        ),
      );
}
