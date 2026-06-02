import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../presentation/providers/auth_providers.dart';
import '../../../shared/pages/messaging_page.dart';
import '../../../shared/widgets/responsive_role_shell.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/surface.dart';

const _terra  = ScolarisPalette.terracotta;
const _orange = ScolarisPalette.orange;
const _gold   = ScolarisPalette.gold;
const _green  = ScolarisPalette.forestGreen;
const _ink    = Color(0xFF1A0A00);
const _muted  = Color(0xFF7A5C44);
const _white  = Colors.white;
const _bg     = Color(0xFFF5EEE6);

// ── Matières CP→CM2 ───────────────────────────────────────────────────────
class _Subject {
  final String name;
  final IconData icon;
  final Color color;
  const _Subject(this.name, this.icon, this.color);
}

const _subjects = [
  _Subject('Lecture',        Icons.menu_book_rounded,          _terra),
  _Subject('Calcul',         Icons.calculate_rounded,          _gold),
  _Subject('Écriture',       Icons.edit_rounded,               _green),
  _Subject('Sciences',       Icons.science_rounded,            Color(0xFF0891B2)),
  _Subject('Éd. Civique',    Icons.account_balance_rounded,    _orange),
  _Subject('Religion',       Icons.church_rounded,             Color(0xFF6D28D9)),
  _Subject('Dessin',         Icons.palette_rounded,            Color(0xFFDB2777)),
  _Subject('Sport',          Icons.sports_soccer_rounded,      Color(0xFF059669)),
];

// ── Classes primaire CP→CM2 ───────────────────────────────────────────────
const _primaryClasses = ['CP', 'CE1', 'CE2', 'CM1', 'CM2'];

// ── Shell ─────────────────────────────────────────────────────────────────
class PrimaryStudentHome extends StatelessWidget {
  const PrimaryStudentHome({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveRoleShell(
      role: UserRole.student,
      title: 'Scolaris · Primaire',
      groups: const [
        RoleNavGroup(labelKey: 'sections.setup', entries: [
          RoleNavEntry(
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
            labelKey: 'nav.dashboard',
            page: _PrimaryDashboard(),
          ),
          RoleNavEntry(
            icon: Icons.grading_outlined,
            activeIcon: Icons.grading_rounded,
            labelKey: 'nav.grades',
            page: _PrimaryNotesPage(),
          ),
        ]),
        RoleNavGroup(labelKey: 'sections.activity', entries: [
          RoleNavEntry(
            icon: Icons.calendar_month_outlined,
            activeIcon: Icons.calendar_month_rounded,
            labelKey: 'nav.schedule',
            page: _PrimarySchedulePage(),
          ),
          RoleNavEntry(
            icon: Icons.assignment_outlined,
            activeIcon: Icons.assignment_rounded,
            labelKey: 'nav.homework',
            page: _PrimaryDevoirsPage(),
          ),
          RoleNavEntry(
            icon: Icons.receipt_long_outlined,
            activeIcon: Icons.receipt_long_rounded,
            labelKey: 'nav.bulletin',
            page: _PrimaryBulletinPage(),
          ),
        ]),
        RoleNavGroup(labelKey: 'sections.account', entries: [
          RoleNavEntry(
            icon: Icons.chat_outlined,
            activeIcon: Icons.chat_rounded,
            labelKey: 'nav.messages',
            page: MessagingPage(),
          ),
        ]),
      ],
    );
  }
}

// ── Dashboard ─────────────────────────────────────────────────────────────
class _PrimaryDashboard extends ConsumerStatefulWidget {
  const _PrimaryDashboard();
  @override
  ConsumerState<_PrimaryDashboard> createState() => _PrimaryDashboardState();
}

class _PrimaryDashboardState extends ConsumerState<_PrimaryDashboard> {
  bool _loading = true;
  double? _avg;
  int? _presence;
  int? _devoirs;
  int? _trimestre;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() {
        _loading   = false;
        _avg       = 8.4;
        _presence  = 97;
        _devoirs   = 2;
        _trimestre = 2;
      });
    });
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bonjour';
    if (h < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }

  @override
  Widget build(BuildContext context) {
    final user  = ref.watch(authSessionProvider);
    final prenom = user?.fullName.split(' ').first ?? 'Élève';

    return Container(
      color: _bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Hero ─────────────────────────────────────────────────────
            _HeroBanner(greeting: _greeting, prenom: prenom,
                trimestre: _trimestre, loading: _loading),
            const SizedBox(height: 16),

            // ── Stats ────────────────────────────────────────────────────
            _StatsRow(avg: _avg, presence: _presence, devoirs: _devoirs,
                loading: _loading),
            const SizedBox(height: 24),

            // ── Matières aujourd'hui ─────────────────────────────────────
            _SectionHeader(title: "Mes matières aujourd'hui",
                action: 'Emploi du temps', onAction: () {}),
            const SizedBox(height: 12),
            if (_loading)
              const _TodaySubjectsSkeleton()
            else
              const _TodaySubjectsRow(),
            const SizedBox(height: 24),

            // ── Dernières notes ──────────────────────────────────────────
            _SectionHeader(title: 'Mes dernières notes',
                action: 'Tout voir', onAction: () {}),
            const SizedBox(height: 10),
            if (_loading) ...[
              const SkeletonListRow(), const SizedBox(height: 8),
              const SkeletonListRow(), const SizedBox(height: 8),
              const SkeletonListRow(),
            ] else ...[
              _NoteRow(matiere: 'Calcul',    note: 9.5, max: 10, date: '28 Mai', color: _gold),
              const SizedBox(height: 8),
              _NoteRow(matiere: 'Lecture',   note: 8.0, max: 10, date: '26 Mai', color: _terra),
              const SizedBox(height: 8),
              _NoteRow(matiere: 'Écriture',  note: 8.5, max: 10, date: '23 Mai', color: _green),
            ],
            const SizedBox(height: 24),

            // ── Prochain devoir ───────────────────────────────────────────
            _SectionHeader(title: 'Mon prochain devoir',
                action: 'Voir tout', onAction: () {}),
            const SizedBox(height: 10),
            if (_loading)
              const SkeletonListRow()
            else
              const _NextHomeworkCard(),
            const SizedBox(height: 24),

            // ── Citation africaine ────────────────────────────────────────
            const _AfricanQuote(),
          ],
        ),
      ),
    );
  }
}

// ── Hero Banner ────────────────────────────────────────────────────────────
class _HeroBanner extends StatelessWidget {
  final String greeting, prenom;
  final int? trimestre;
  final bool loading;
  const _HeroBanner({required this.greeting, required this.prenom,
      required this.trimestre, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3E1A00), _terra, _orange],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: _terra.withOpacity(0.35),
              blurRadius: 24, offset: const Offset(0, 10), spreadRadius: -4),
        ],
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$greeting, $prenom ! 🌟',
              style: const TextStyle(color: _white, fontSize: 20,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          if (loading)
            const SkeletonBox(width: 160, height: 14, radius: 6)
          else ...[
            Text('Trimestre $trimestre en cours',
                style: TextStyle(color: _white.withOpacity(0.85),
                    fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _white.withOpacity(0.25)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.star_rounded, color: _gold, size: 14),
                const SizedBox(width: 5),
                const Text('Bon travail, continue !',
                    style: TextStyle(color: _white, fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ],
        ])),
        const SizedBox(width: 12),
        SizedBox(
          width: 80, height: 80,
          child: Lottie.asset('assets/lottie/student.json',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                  Icons.child_care_rounded, color: _white.withOpacity(0.6), size: 48)),
        ),
      ]),
    );
  }
}

// ── Stats Row ──────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final double? avg;
  final int? presence, devoirs;
  final bool loading;
  const _StatsRow({required this.avg, required this.presence,
      required this.devoirs, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: _StatPill(
        icon: Icons.star_rounded,
        label: 'Moyenne',
        value: loading ? null : '${avg!.toStringAsFixed(1)}/10',
        color: _gold,
      )),
      const SizedBox(width: 10),
      Expanded(child: _StatPill(
        icon: Icons.check_circle_rounded,
        label: 'Présence',
        value: loading ? null : '$presence%',
        color: _green,
      )),
      const SizedBox(width: 10),
      Expanded(child: _StatPill(
        icon: Icons.assignment_rounded,
        label: 'Devoirs',
        value: loading ? null : '$devoirs',
        color: _terra,
      )),
    ]);
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Color color;
  const _StatPill({required this.icon, required this.label,
      required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: ScolarisSurface.accent(color: color, radius: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.18),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 15),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: color.withOpacity(0.7),
            fontSize: 10, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        if (value == null)
          const SkeletonBox(width: 38, height: 16, radius: 4)
        else
          Text(value!, style: TextStyle(color: color, fontSize: 15,
              fontWeight: FontWeight.w900)),
      ]),
    );
  }
}

// ── Today subjects row ────────────────────────────────────────────────────
class _TodaySubjectsRow extends StatelessWidget {
  const _TodaySubjectsRow();

  static const _today = [
    _SubjectSlot('Lecture',    '08:00',  _terra),
    _SubjectSlot('Calcul',     '09:30',  _gold),
    _SubjectSlot('Sport',      '11:00',  Color(0xFF059669)),
    _SubjectSlot('Écriture',   '14:00',  _green),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _today.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => _SubjectSlotCard(slot: _today[i], isFirst: i == 0),
      ),
    );
  }
}

class _SubjectSlot {
  final String name, time;
  final Color color;
  const _SubjectSlot(this.name, this.time, this.color);
}

class _SubjectSlotCard extends StatelessWidget {
  final _SubjectSlot slot;
  final bool isFirst;
  const _SubjectSlotCard({required this.slot, required this.isFirst});

  static final _icons = <String, IconData>{
    'Lecture':  Icons.menu_book_rounded,
    'Calcul':   Icons.calculate_rounded,
    'Sport':    Icons.sports_soccer_rounded,
    'Écriture': Icons.edit_rounded,
    'Sciences': Icons.science_rounded,
    'Dessin':   Icons.palette_rounded,
    'Religion': Icons.church_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final icon = _icons[slot.name] ?? Icons.school_rounded;
    return Container(
      width: 100,
      padding: const EdgeInsets.all(14),
      decoration: isFirst
          ? BoxDecoration(
              gradient: LinearGradient(
                colors: [slot.color, slot.color.withOpacity(0.75)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: slot.color.withOpacity(0.35),
                    blurRadius: 14, offset: const Offset(0, 6)),
              ],
            )
          : ScolarisSurface.accent(color: slot.color, radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: isFirst ? _white.withOpacity(0.25) : slot.color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon,
                size: 17,
                color: isFirst ? _white : slot.color),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(slot.name,
                style: TextStyle(
                    color: isFirst ? _white : _ink,
                    fontSize: 12, fontWeight: FontWeight.w800),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(slot.time,
                style: TextStyle(
                    color: isFirst ? _white.withOpacity(0.8) : slot.color,
                    fontSize: 11, fontWeight: FontWeight.w600)),
          ]),
        ],
      ),
    );
  }
}

class _TodaySubjectsSkeleton extends StatelessWidget {
  const _TodaySubjectsSkeleton();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: Row(children: [
        for (int i = 0; i < 4; i++) ...[
          const SkeletonBox(width: 100, height: 110, radius: 16),
          if (i < 3) const SizedBox(width: 10),
        ],
      ]),
    );
  }
}

// ── Note Row ───────────────────────────────────────────────────────────────
class _NoteRow extends StatelessWidget {
  final String matiere, date;
  final double note, max;
  final Color color;
  const _NoteRow({required this.matiere, required this.note,
      required this.max, required this.date, required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = note / max;
    final isGood = pct >= 0.7;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: ScolarisSurface.subtle(radius: 13),
      child: Row(children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.12), color.withOpacity(0.22)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('${note.toStringAsFixed(1)}',
                style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w900)),
            Text('/10', style: TextStyle(color: color.withOpacity(0.6),
                fontSize: 9, fontWeight: FontWeight.w600)),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(matiere, style: const TextStyle(color: _ink, fontSize: 13,
              fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct, minHeight: 5,
              backgroundColor: color.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ])),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: isGood ? _green.withOpacity(0.12) : _terra.withOpacity(0.10),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(isGood ? '✓ Bien' : '→ Peut mieux',
                style: TextStyle(
                    color: isGood ? _green : _terra,
                    fontSize: 9, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 4),
          Text(date, style: const TextStyle(color: _muted, fontSize: 10)),
        ]),
      ]),
    );
  }
}

// ── Next Homework Card ─────────────────────────────────────────────────────
class _NextHomeworkCard extends StatelessWidget {
  const _NextHomeworkCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: ScolarisSurface.card(radius: 14),
      child: Row(children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            color: _gold.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.assignment_rounded, color: _gold, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Calcul — Additions et soustractions',
              style: TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('À remettre demain · M. Mbuyi',
              style: TextStyle(color: _muted, fontSize: 11)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_terra, _orange],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(color: _terra.withOpacity(0.30),
                blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: const Text('Demain', style: TextStyle(color: _white,
              fontSize: 10, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

// ── African Quote ─────────────────────────────────────────────────────────
class _AfricanQuote extends StatelessWidget {
  const _AfricanQuote();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D3B1E), _green],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: _green.withOpacity(0.30),
              blurRadius: 20, offset: const Offset(0, 8), spreadRadius: -2),
        ],
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('"L\'enfant qui n\'est pas embrassé\npar son village brûlera\nle monde pour se réchauffer."',
              style: TextStyle(color: _white.withOpacity(0.95), fontSize: 12,
                  height: 1.55, fontStyle: FontStyle.italic)),
          const SizedBox(height: 10),
          Text('— Proverbe africain',
              style: TextStyle(color: _gold.withOpacity(0.9),
                  fontSize: 11, fontWeight: FontWeight.w700)),
        ])),
        const SizedBox(width: 14),
        Icon(Icons.format_quote_rounded,
            color: _white.withOpacity(0.25), size: 48),
      ]),
    );
  }
}

// ── Section Header ─────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title, action;
  final VoidCallback onAction;
  const _SectionHeader({required this.title, required this.action,
      required this.onAction});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(title, style: const TextStyle(color: _ink, fontSize: 15,
          fontWeight: FontWeight.w700)),
      const Spacer(),
      GestureDetector(
        onTap: onAction,
        child: Text(action, style: const TextStyle(color: _terra,
            fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Pages secondaires (Notes, EDT, Devoirs, Bulletin)
// ══════════════════════════════════════════════════════════════════════════

// ── Notes page ────────────────────────────────────────────────────────────
class _PrimaryNotesPage extends StatelessWidget {
  const _PrimaryNotesPage();

  static const _notes = [
    (subject: 'Calcul',     note: 9.5, max: 10.0, color: _gold,   date: '28 Mai'),
    (subject: 'Lecture',    note: 8.0, max: 10.0, color: _terra,  date: '26 Mai'),
    (subject: 'Écriture',   note: 8.5, max: 10.0, color: _green,  date: '23 Mai'),
    (subject: 'Sciences',   note: 7.5, max: 10.0, color: Color(0xFF0891B2), date: '21 Mai'),
    (subject: 'Éd. Civique',note: 9.0, max: 10.0, color: _orange, date: '19 Mai'),
    (subject: 'Dessin',     note: 10.0,max: 10.0, color: Color(0xFFDB2777), date: '15 Mai'),
    (subject: 'Sport',      note: 8.0, max: 10.0, color: Color(0xFF059669), date: '14 Mai'),
  ];

  @override
  Widget build(BuildContext context) {
    final avg = _notes.map((e) => e.note).reduce((a, b) => a + b) / _notes.length;
    return Container(
      color: _bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Average banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: ScolarisSurface.accent(color: _gold, radius: 18),
            child: Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Moyenne générale', style: TextStyle(
                    color: _muted, fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                RichText(text: TextSpan(children: [
                  TextSpan(text: avg.toStringAsFixed(1),
                      style: const TextStyle(color: _gold, fontSize: 36,
                          fontWeight: FontWeight.w900)),
                  const TextSpan(text: '/10',
                      style: TextStyle(color: _muted, fontSize: 18,
                          fontWeight: FontWeight.w500)),
                ])),
              ]),
              const Spacer(),
              SizedBox(
                width: 60, height: 60,
                child: CircularProgressIndicator(
                  value: avg / 10,
                  strokeWidth: 6,
                  backgroundColor: _gold.withOpacity(0.15),
                  valueColor: const AlwaysStoppedAnimation(_gold),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          const Text('Notes du Trimestre 2', style: TextStyle(
              color: _ink, fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          for (final n in _notes) ...[
            _NoteRow(matiere: n.subject, note: n.note, max: n.max,
                date: n.date, color: n.color),
            const SizedBox(height: 8),
          ],
        ]),
      ),
    );
  }
}

// ── Emploi du temps ────────────────────────────────────────────────────────
class _PrimarySchedulePage extends StatelessWidget {
  const _PrimarySchedulePage();

  static const _days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven'];
  static const _schedule = {
    'Lun': [
      ('08:00', 'Lecture',    _terra),
      ('09:30', 'Calcul',     _gold),
      ('11:00', 'Écriture',   _green),
      ('14:00', 'Sciences',   Color(0xFF0891B2)),
    ],
    'Mar': [
      ('08:00', 'Calcul',     _gold),
      ('09:30', 'Lecture',    _terra),
      ('11:00', 'Dessin',     Color(0xFFDB2777)),
      ('14:00', 'Éd. Civique',_orange),
    ],
    'Mer': [
      ('08:00', 'Écriture',   _green),
      ('09:30', 'Calcul',     _gold),
      ('11:00', 'Religion',   Color(0xFF6D28D9)),
    ],
    'Jeu': [
      ('08:00', 'Lecture',    _terra),
      ('09:30', 'Sciences',   Color(0xFF0891B2)),
      ('11:00', 'Écriture',   _green),
      ('14:00', 'Calcul',     _gold),
    ],
    'Ven': [
      ('08:00', 'Calcul',     _gold),
      ('09:30', 'Lecture',    _terra),
      ('11:00', 'Sport',      Color(0xFF059669)),
      ('14:00', 'Éd. Civique',_orange),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final today = _days[DateTime.now().weekday.clamp(1, 5) - 1];
    return DefaultTabController(
      length: _days.length,
      initialIndex: _days.indexOf(today).clamp(0, 4),
      child: Container(
        color: _bg,
        child: Column(children: [
          Container(
            color: _bg,
            child: TabBar(
              isScrollable: true,
              labelColor: _terra,
              unselectedLabelColor: _muted,
              indicator: BoxDecoration(
                color: _white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(color: _terra.withOpacity(0.15),
                    blurRadius: 8, offset: const Offset(0, 3))],
              ),
              indicatorPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              tabs: _days.map((d) => Tab(
                child: Text(d == today ? '$d (Auj.)' : d,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              )).toList(),
            ),
          ),
          Expanded(child: TabBarView(
            children: _days.map((d) {
              final slots = _schedule[d] ?? [];
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const SizedBox(height: 4),
                  for (final s in slots) ...[
                    _ScheduleSlot(time: s.$1, matiere: s.$2, color: s.$3,
                        isNow: d == today && slots.indexOf(s) == 0),
                    const SizedBox(height: 10),
                  ],
                ],
              );
            }).toList(),
          )),
        ]),
      ),
    );
  }
}

class _ScheduleSlot extends StatelessWidget {
  final String time, matiere;
  final Color color;
  final bool isNow;
  const _ScheduleSlot({required this.time, required this.matiere,
      required this.color, required this.isNow});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: isNow
          ? ScolarisSurface.accent(color: color, radius: 14)
          : ScolarisSurface.subtle(radius: 14),
      child: Row(children: [
        Container(
          width: 4, height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color, color.withOpacity(0.5)],
                begin: Alignment.topCenter, end: Alignment.bottomCenter),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 14),
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(_subjectIcon(matiere), color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(matiere, style: TextStyle(
              color: isNow ? _ink : _ink,
              fontSize: 14, fontWeight: FontWeight.w700)),
          Text('M. Mbuyi · Salle 3',
              style: const TextStyle(color: _muted, fontSize: 11)),
        ])),
        if (isNow)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(color: color.withOpacity(0.35),
                  blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: Text(time, style: const TextStyle(
                color: _white, fontSize: 11, fontWeight: FontWeight.w800)),
          )
        else
          Text(time, style: TextStyle(color: color, fontSize: 12,
              fontWeight: FontWeight.w700)),
      ]),
    );
  }

  IconData _subjectIcon(String m) {
    switch (m) {
      case 'Calcul':     return Icons.calculate_rounded;
      case 'Lecture':    return Icons.menu_book_rounded;
      case 'Écriture':   return Icons.edit_rounded;
      case 'Sciences':   return Icons.science_rounded;
      case 'Dessin':     return Icons.palette_rounded;
      case 'Religion':   return Icons.church_rounded;
      case 'Éd. Civique':return Icons.account_balance_rounded;
      case 'Sport':      return Icons.sports_soccer_rounded;
      default:           return Icons.school_rounded;
    }
  }
}

// ── Devoirs page ───────────────────────────────────────────────────────────
class _PrimaryDevoirsPage extends StatelessWidget {
  const _PrimaryDevoirsPage();

  static const _devoirs = [
    (
      matiere: 'Calcul',
      titre: 'Additions et soustractions',
      echeance: 'Demain',
      urgent: true,
      color: _gold,
    ),
    (
      matiere: 'Lecture',
      titre: 'Lire pages 34–40 du livre',
      echeance: 'Dans 3 jours',
      urgent: false,
      color: _terra,
    ),
    (
      matiere: 'Écriture',
      titre: 'Recopier le texte "La savane"',
      echeance: 'Dans 4 jours',
      urgent: false,
      color: _green,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: ScolarisSurface.accent(color: _terra, radius: 16),
            child: Row(children: [
              Icon(Icons.assignment_rounded, color: _terra, size: 24),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Mes devoirs', style: TextStyle(
                    color: _ink, fontSize: 15, fontWeight: FontWeight.w800)),
                Text('${_devoirs.length} devoirs à faire',
                    style: TextStyle(color: _muted, fontSize: 12)),
              ]),
            ]),
          ),
          const SizedBox(height: 16),
          for (final d in _devoirs) ...[
            _DevoirCard(
              matiere: d.matiere,
              titre: d.titre,
              echeance: d.echeance,
              urgent: d.urgent,
              color: d.color,
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _DevoirCard extends StatelessWidget {
  final String matiere, titre, echeance;
  final bool urgent;
  final Color color;
  const _DevoirCard({required this.matiere, required this.titre,
      required this.echeance, required this.urgent, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: urgent
          ? ScolarisSurface.accent(color: color, radius: 14)
          : ScolarisSurface.card(radius: 14),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.15), color.withOpacity(0.25)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.assignment_outlined, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(matiere, style: TextStyle(color: color, fontSize: 11,
                fontWeight: FontWeight.w700)),
            if (urgent) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _terra.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Urgent', style: TextStyle(
                    color: _terra, fontSize: 9, fontWeight: FontWeight.w800)),
              ),
            ],
          ]),
          const SizedBox(height: 3),
          Text(titre, style: const TextStyle(color: _ink, fontSize: 13,
              fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.schedule_rounded, size: 11, color: _muted),
            const SizedBox(width: 4),
            Text(echeance, style: const TextStyle(color: _muted, fontSize: 11)),
          ]),
        ])),
        Icon(Icons.check_circle_outline_rounded, color: _muted, size: 22),
      ]),
    );
  }
}

// ── Bulletin page ──────────────────────────────────────────────────────────
class _PrimaryBulletinPage extends StatelessWidget {
  const _PrimaryBulletinPage();

  static const _bNotes = [
    (matiere: 'Calcul',       t1: 8.5, t2: 9.5, t3: 0.0, color: _gold),
    (matiere: 'Lecture',      t1: 7.5, t2: 8.0, t3: 0.0, color: _terra),
    (matiere: 'Écriture',     t1: 8.0, t2: 8.5, t3: 0.0, color: _green),
    (matiere: 'Sciences',     t1: 6.5, t2: 7.5, t3: 0.0, color: Color(0xFF0891B2)),
    (matiere: 'Éd. Civique',  t1: 9.0, t2: 9.0, t3: 0.0, color: _orange),
    (matiere: 'Religion',     t1: 9.5, t2: 9.5, t3: 0.0, color: Color(0xFF6D28D9)),
    (matiere: 'Dessin',       t1: 9.0, t2: 10.0,t3: 0.0, color: Color(0xFFDB2777)),
    (matiere: 'Sport',        t1: 8.5, t2: 8.0, t3: 0.0, color: Color(0xFF059669)),
  ];

  @override
  Widget build(BuildContext context) {
    final avgT1 = _bNotes.map((e) => e.t1).reduce((a, b) => a + b) / _bNotes.length;
    final avgT2 = _bNotes.map((e) => e.t2).reduce((a, b) => a + b) / _bNotes.length;
    return Container(
      color: _bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Bulletin header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3E1A00), _terra],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: _terra.withOpacity(0.30),
                  blurRadius: 20, offset: const Offset(0, 8), spreadRadius: -3)],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Bulletin Trimestriel', style: TextStyle(
                  color: _white, fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text('Année 2025–2026 · CE1',
                  style: TextStyle(color: _white.withOpacity(0.75), fontSize: 12)),
              const SizedBox(height: 16),
              Row(children: [
                _BulletinAvgBadge(label: 'Trim. 1', avg: avgT1),
                const SizedBox(width: 12),
                _BulletinAvgBadge(label: 'Trim. 2', avg: avgT2, current: true),
                const SizedBox(width: 12),
                _BulletinAvgBadge(label: 'Trim. 3', avg: null),
              ]),
            ]),
          ),
          const SizedBox(height: 20),
          const Text('Détail par matière', style: TextStyle(
              color: _ink, fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Container(
            decoration: ScolarisSurface.card(radius: 16),
            child: Column(children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFFF5EEE6),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(children: [
                  const Expanded(flex: 3,
                      child: Text('Matière', style: TextStyle(
                          color: _muted, fontSize: 11, fontWeight: FontWeight.w700))),
                  for (final t in ['T1', 'T2', 'T3'])
                    SizedBox(width: 48, child: Text(t, textAlign: TextAlign.center,
                        style: const TextStyle(color: _muted, fontSize: 11,
                            fontWeight: FontWeight.w700))),
                ]),
              ),
              const Divider(height: 1, color: Color(0xFFEDE0CE)),
              for (int i = 0; i < _bNotes.length; i++) ...[
                _BulletinRow(note: _bNotes[i], isLast: i == _bNotes.length - 1),
                if (i < _bNotes.length - 1)
                  const Divider(height: 1, color: Color(0xFFF0E8DC), indent: 16),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

class _BulletinAvgBadge extends StatelessWidget {
  final String label;
  final double? avg;
  final bool current;
  const _BulletinAvgBadge({required this.label, required this.avg,
      this.current = false});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: current
            ? _white.withOpacity(0.25)
            : _white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
        border: current ? Border.all(color: _white.withOpacity(0.5)) : null,
      ),
      child: Column(children: [
        Text(label, style: TextStyle(
            color: _white.withOpacity(current ? 1.0 : 0.6),
            fontSize: 10, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(avg != null ? avg!.toStringAsFixed(1) : '—',
            style: TextStyle(
                color: current ? _gold : _white.withOpacity(0.5),
                fontSize: 16, fontWeight: FontWeight.w900)),
      ]),
    );
  }
}

class _BulletinRow extends StatelessWidget {
  final ({String matiere, double t1, double t2, double t3, Color color}) note;
  final bool isLast;
  const _BulletinRow({required this.note, required this.isLast});

  Widget _cell(double v) {
    if (v == 0.0) return const SizedBox(width: 48,
        child: Text('—', textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 13)));
    final good = v >= 7.0;
    return SizedBox(width: 48,
      child: Text(v.toStringAsFixed(1),
          textAlign: TextAlign.center,
          style: TextStyle(
              color: good ? _green : _terra,
              fontSize: 13, fontWeight: FontWeight.w700)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: isLast
            ? const BorderRadius.vertical(bottom: Radius.circular(16))
            : BorderRadius.zero,
      ),
      child: Row(children: [
        Expanded(flex: 3, child: Row(children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
                color: note.color, shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: note.color.withOpacity(0.4),
                    blurRadius: 4)]),
          ),
          const SizedBox(width: 8),
          Text(note.matiere, style: const TextStyle(
              color: _ink, fontSize: 13, fontWeight: FontWeight.w600)),
        ])),
        _cell(note.t1),
        _cell(note.t2),
        _cell(note.t3),
      ]),
    );
  }
}
