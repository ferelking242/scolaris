import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/permissions/my_grants.dart';
import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/auth_providers.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';

enum _Status { present, late, absent }

const _historyDays = 7;
const _moisAbbr = [
  'janv', 'févr', 'mars', 'avr', 'mai', 'juin',
  'juil', 'août', 'sept', 'oct', 'nov', 'déc'
];
const _joursAbbr = ['lun', 'mar', 'mer', 'jeu', 'ven', 'sam', 'dim'];

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _shortDate(DateTime d) =>
    '${_joursAbbr[d.weekday - 1]} ${d.day} ${_moisAbbr[d.month - 1]}';

class AttendanceTodayPage extends ConsumerStatefulWidget {
  const AttendanceTodayPage({super.key});
  @override
  ConsumerState<AttendanceTodayPage> createState() =>
      _AttendanceTodayPageState();
}

class _AttendanceTodayPageState extends ConsumerState<AttendanceTodayPage> {
  String? _selectedClassId;
  DateTime _selectedDate = DateTime.now();
  // Cours choisi quand le prof n'est pas titulaire (collège/lycée) : plusieurs
  // profs — et un même prof sur deux cours différents — peuvent pointer la
  // même classe le même jour sans se marcher dessus.
  String? _selectedSubjectId;
  Map<String, _Status> _statusMap = {};
  // (classId|date|subjectId) dont le pointage a déjà été chargé — évite de
  // re-seeder à chaque rebuild et d'écraser une modification en cours.
  String? _seededKey;
  bool _forceUnlock = false;

  DateTime get _dateOnly => DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(classesProvider);
    final assignAsync  = ref.watch(teacherAssignmentsProvider);

    return classesAsync.when(
      loading: () => const PageScaffold(
        title: 'Présences',
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => PageScaffold(
        title: 'Présences',
        child: Center(child: Text('Erreur : $e')),
      ),
      data: (allClasses) {
        // Scope : seulement les classes que ce prof enseigne.
        final assign = assignAsync.valueOrNull;
        if (assign == null) {
          return const PageScaffold(
            title: 'Présences',
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final classes =
            allClasses.where((c) => assign.teachesClass(c.id)).toList();
        if (classes.isNotEmpty &&
            (_selectedClassId == null ||
                !classes.any((c) => c.id == _selectedClassId))) {
          _selectedClassId = classes.first.id;
        }
        return _buildContent(classes, assign);
      },
    );
  }

  Widget _buildContent(List<SbClass> classes, TeacherAssignments assign) {
    final selectedClass = classes.isEmpty
        ? null
        : classes.firstWhere(
            (c) => c.id == _selectedClassId,
            orElse: () => classes.first,
          );

    if (selectedClass == null) {
      return const PageScaffold(
        title: 'Présences',
        child: Center(child: Text('Aucune classe ne vous est assignée.')),
      );
    }

    final teacherId = ref.watch(authSessionProvider)?.id;
    // Titulaire (primaire, en général) : un pointage « journée entière », pas
    // lié à un cours précis — comme avant ce chantier. Sinon (collège/lycée),
    // le pointage est lié au cours choisi : plusieurs profs prennent souvent
    // la même classe le même jour, mais jamais dans le même cours.
    final isTitulaire = assign.isTitulaire(selectedClass.id);

    if (!isTitulaire) {
      final coursesAsync = ref.watch(coursesForClassProvider(selectedClass.id));
      return coursesAsync.when(
        loading: () => const PageScaffold(
          title: 'Présences',
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => PageScaffold(
          title: 'Présences',
          child: Center(child: Text('Erreur : $e')),
        ),
        data: (courses) {
          final allowed = courses
              .where((c) => c.subjectId != null && c.isTaughtBy(teacherId ?? ''))
              .toList();
          if (allowed.isEmpty) {
            return const PageScaffold(
              title: 'Présences',
              child: DataPanel(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                      child: Text(
                          'Aucun cours ne vous est confié dans cette classe.',
                          style: TextStyle(color: muted))),
                ),
              ),
            );
          }
          if (_selectedSubjectId == null ||
              !allowed.any((c) => c.subjectId == _selectedSubjectId)) {
            _selectedSubjectId = allowed.first.subjectId;
          }
          return _buildRoster(classes, selectedClass, teacherId,
              subjectId: _selectedSubjectId, subjects: allowed);
        },
      );
    }

    return _buildRoster(classes, selectedClass, teacherId,
        subjectId: null, subjects: const []);
  }

  Widget _buildRoster(
    List<SbClass> classes,
    SbClass selectedClass,
    String? teacherId, {
    required String? subjectId,
    required List<SbCourse> subjects,
  }) {
    final studentsAsync =
        ref.watch(studentsByClassProvider(selectedClass.name));
    final providerKey =
        '${selectedClass.id}|${_isoDate(_dateOnly)}|${teacherId ?? ''}|${subjectId ?? ''}';
    final attendanceAsync = ref.watch(attendanceForClassProvider(providerKey));

    // Pré-remplir le pointage déjà saisi pour (classe, date, CE prof) — chaque
    // prof ne voit/ne modifie que son propre pointage, jamais celui d'un
    // collègue qui prend la même classe à une autre heure.
    final existingRecords = attendanceAsync.valueOrNull;
    final seedKey = providerKey;
    if (existingRecords != null && _seededKey != seedKey) {
      _seededKey = seedKey;
      _forceUnlock = false;
      _statusMap = {
        for (final r in existingRecords)
          r.studentId: r.status == 'late'
              ? _Status.late
              : r.status == 'absent'
                  ? _Status.absent
                  : _Status.present,
      };
    }

    final alreadySubmitted = (existingRecords?.isNotEmpty ?? false);
    final locked = alreadySubmitted && !_forceUnlock;

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
        final late =
            _statusMap.values.where((s) => s == _Status.late).length;
        final absent =
            _statusMap.values.where((s) => s == _Status.absent).length;

        // Le rôle « Enseignant » se configure comme les autres : un directeur
        // peut décider que l'appel revient au surveillant. Le prof garde alors
        // la consultation — mais plus le bouton, ni les boutons de statut.
        final canSaisir = ref.watch(canProvider('presences.saisir'));
        final canModifier = ref.watch(canProvider('presences.modifier'));
        final canEdit = canSaisir && !locked;

        return PageScaffold(
          title: 'Présences',
          subtitle: !canSaisir
              ? 'Consultation seule — l\'appel ne vous est pas confié'
              : locked
                  ? 'Appel déjà transmis pour ce jour'
                  : 'Marquez présent, retard ou absent',
          actions: [
            if (canEdit)
              ActionButton(
                  label: 'Enregistrer',
                  icon: Icons.check_rounded,
                  primary: true,
                  onTap: () => _save(
                      students, selectedClass.id, teacherId, subjectId)),
          ],
          child: Column(children: [
            _ClassPicker(
              classes: classes,
              selectedId: _selectedClassId,
              onChanged: (id) => setState(() {
                _selectedClassId = id;
                _selectedSubjectId = null;
                _statusMap = {};
                _seededKey = null;
              }),
            ),
            const SizedBox(height: 12),
            if (subjects.isNotEmpty) ...[
              _SubjectPicker(
                subjects: subjects,
                selectedId: subjectId,
                onChanged: (id) => setState(() {
                  _selectedSubjectId = id;
                  _statusMap = {};
                  _seededKey = null;
                }),
              ),
              const SizedBox(height: 12),
            ],
            _DatePicker(
              date: _dateOnly,
              onChanged: (d) => setState(() {
                _selectedDate = d;
                _statusMap = {};
                _seededKey = null;
              }),
            ),
            const SizedBox(height: 12),
            if (locked) ...[
              _LockBanner(
                canModifier: canModifier,
                onUnlock: canModifier
                    ? () => _confirmUnlock(context)
                    : null,
              ),
              const SizedBox(height: 12),
            ],
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
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                          child: Text('Aucun élève.',
                              style: TextStyle(color: muted))),
                    )
                  : LayoutBuilder(builder: (_, constraints) {
                      // 3 boutons de statut dans une colonne flex débordaient
                      // sous 640px : cartes empilées à la place.
                      if (constraints.maxWidth < 640) {
                        return Column(children: [
                          for (final s in students) ...[
                            _AttendanceCard(
                              student: s,
                              status: _statusMap[s.id] ?? _Status.present,
                              onChanged: canEdit
                                  ? (v) =>
                                      setState(() => _statusMap[s.id] = v)
                                  : null,
                            ),
                            const SizedBox(height: 8),
                          ],
                        ]);
                      }
                      return DataTablePanel(
                        columns: const [
                          'Élève',
                          'Classe',
                          'Statut'
                        ],
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
                                      style: const TextStyle(
                                          color: ink,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ]),
                              Text(s.classe ?? '—',
                                  style: const TextStyle(
                                      fontSize: 12, color: muted)),
                              _StatusToggle(
                                current:
                                    _statusMap[s.id] ?? _Status.present,
                                onChanged: canEdit
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

  Future<void> _confirmUnlock(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Modifier un appel déjà transmis ?'),
        content: const Text(
            'Cet appel a déjà été enregistré pour ce jour. Le corriger '
            'remplacera le pointage transmis.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF8B1A00)),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Modifier')),
        ],
      ),
    );
    if (ok == true) setState(() => _forceUnlock = true);
  }

  Future<void> _save(List<SbStudent> students, String classId,
      String? teacherId, String? subjectId) async {
    if (teacherId == null) return;
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
      await SupabaseDbSource.saveAttendance(records,
          schoolId: schoolId,
          teacherId: teacherId,
          subjectId: subjectId,
          date: _dateOnly);
      _seededKey = null; // force le re-seed → passe en verrouillé
      ref.invalidate(attendanceForClassProvider);
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

/// Sélecteur de cours (collège/lycée, prof non-titulaire) : le pointage est
/// lié au cours choisi, pas seulement au prof — un même prof peut donner deux
/// matières différentes à la même classe le même jour sans que l'une écrase
/// l'autre.
class _SubjectPicker extends StatelessWidget {
  final List<SbCourse> subjects;
  final String? selectedId;
  final ValueChanged<String> onChanged;
  const _SubjectPicker(
      {required this.subjects, required this.selectedId, required this.onChanged});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final c in subjects)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  avatar: const Icon(Icons.menu_book_outlined, size: 15),
                  label: Text(c.name),
                  selected: selectedId == c.subjectId,
                  onSelected: (_) => onChanged(c.subjectId!),
                  selectedColor:
                      const Color(0xFF8B1A00).withValues(alpha: .12),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: selectedId == c.subjectId ? const Color(0xFF8B1A00) : muted,
                    fontWeight: selectedId == c.subjectId
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      );
}

class _ClassPicker extends StatelessWidget {
  final List<SbClass> classes;
  final String? selectedId;
  final ValueChanged<String> onChanged;
  const _ClassPicker(
      {required this.classes, required this.selectedId, required this.onChanged});

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
                    color: selectedId == c.id ? const Color(0xFF8B1A00) : muted,
                    fontWeight: selectedId == c.id
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      );
}

/// Sélecteur de date : "Aujourd'hui"/"Hier" en un tap + un calendrier borné
/// aux 7 derniers jours (rattraper un appel oublié, jamais réécrire plus loin
/// ni saisir dans le futur).
class _DatePicker extends StatelessWidget {
  final DateTime date;
  final ValueChanged<DateTime> onChanged;
  const _DatePicker({required this.date, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final yesterday = todayOnly.subtract(const Duration(days: 1));
    final isToday = date == todayOnly;
    final isYesterday = date == yesterday;

    String label;
    if (isToday) {
      label = 'Aujourd\'hui';
    } else if (isYesterday) {
      label = 'Hier';
    } else {
      label = _shortDate(date);
    }

    return Row(children: [
      Expanded(
        child: Wrap(spacing: 6, runSpacing: 6, children: [
          ChoiceChip(
            label: const Text('Aujourd\'hui'),
            selected: isToday,
            onSelected: (_) => onChanged(todayOnly),
            labelStyle: TextStyle(fontSize: 12, color: isToday ? const Color(0xFF8B1A00) : muted,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500),
            selectedColor: const Color(0xFF8B1A00).withValues(alpha: .12),
          ),
          ChoiceChip(
            label: const Text('Hier'),
            selected: isYesterday,
            onSelected: (_) => onChanged(yesterday),
            labelStyle: TextStyle(fontSize: 12, color: isYesterday ? const Color(0xFF8B1A00) : muted,
                fontWeight: isYesterday ? FontWeight.w700 : FontWeight.w500),
            selectedColor: const Color(0xFF8B1A00).withValues(alpha: .12),
          ),
          if (!isToday && !isYesterday)
            Chip(
              label: Text(label),
              labelStyle: const TextStyle(
                  fontSize: 12, color: Color(0xFF8B1A00), fontWeight: FontWeight.w700),
              backgroundColor: const Color(0xFF8B1A00).withValues(alpha: .12),
            ),
        ]),
      ),
      IconButton(
        icon: const Icon(Icons.calendar_month_rounded, size: 20, color: muted),
        tooltip: 'Choisir une date',
        onPressed: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: date,
            firstDate: todayOnly.subtract(const Duration(days: _historyDays)),
            lastDate: todayOnly,
          );
          if (picked != null) onChanged(picked);
        },
      ),
    ]);
  }
}

/// Bandeau « appel déjà transmis » — verrouillage client-side (aucune
/// migration) : s'appuie sur `presences.modifier`, déjà défini et déjà
/// appliqué en RLS, mais jamais lu côté client avant ce chantier.
class _LockBanner extends StatelessWidget {
  final bool canModifier;
  final VoidCallback? onUnlock;
  const _LockBanner({required this.canModifier, required this.onUnlock});

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF8B1A00);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Row(children: [
        const Icon(Icons.lock_rounded, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            canModifier
                ? 'Appel déjà transmis pour ce jour.'
                : 'Appel déjà transmis pour ce jour. Contactez l\'administration pour corriger.',
            style: const TextStyle(fontSize: 12.5, color: color, height: 1.35),
          ),
        ),
        if (canModifier && onUnlock != null) ...[
          const SizedBox(width: 8),
          TextButton(
            onPressed: onUnlock,
            style: TextButton.styleFrom(foregroundColor: color),
            child: const Text('Modifier'),
          ),
        ],
      ]),
    );
  }
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
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
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
          Expanded(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13, color: ink, fontWeight: FontWeight.w600)),
          ),
        ]),
      );
}

class _AttendanceCard extends StatelessWidget {
  final SbStudent student;
  final _Status status;
  final ValueChanged<_Status>? onChanged;
  const _AttendanceCard(
      {required this.student, required this.status, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
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

class _StatusToggle extends StatelessWidget {
  final _Status current;

  /// `null` = le professeur n'a pas le droit de faire l'appel, ou l'appel du
  /// jour est déjà transmis et verrouillé : il voit le statut, il ne le
  /// change pas.
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

  /// `null` = bouton inerte : le professeur consulte l'appel sans le modifier.
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
