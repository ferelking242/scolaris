import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../presentation/providers/auth_providers.dart';
import '../../../shared/data/mock_data.dart';
import '../../../shared/pages/features_hub_page.dart';
import '../../../shared/pages/messaging_page.dart';
import '../../../shared/widgets/responsive_role_shell.dart';
import '../../../shared/widgets/surface.dart';
import 'pages/attendance_page.dart';
import 'pages/bulletin_page.dart';
import 'pages/courses_page.dart';
import 'pages/grades_page.dart';
import 'pages/homework_student_page.dart';
import 'pages/library/library_page.dart';
import 'pages/schedule_page.dart';

const _terra  = ScolarisPalette.terracotta;
const _orange = ScolarisPalette.orange;
const _gold   = ScolarisPalette.gold;
const _green  = ScolarisPalette.forestGreen;
const _dark   = ScolarisPalette.darkBrown;
const _cyan   = Color(0xFF0891B2);
const _purple = Color(0xFF7C3AED);
const _ink    = Color(0xFF1A0A00);
const _muted  = Color(0xFF7A5C44);
const _white  = Colors.white;
const _bg     = Color(0xFFEDD8BE);

// ══════════════════════════════════════════════════════════════════════════
// Shell (navigation)
// ══════════════════════════════════════════════════════════════════════════
class StudentHome extends StatelessWidget {
  const StudentHome({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveRoleShell(
      role: UserRole.student,
      title: 'Scolaris',
      groups: const [
        RoleNavGroup(labelKey: 'sections.setup', entries: [
          RoleNavEntry(icon: Icons.home_rounded,      activeIcon: Icons.home_rounded,
              labelKey: 'nav.dashboard', page: _StudentDashboard()),
          RoleNavEntry(icon: Icons.menu_book_outlined, activeIcon: Icons.menu_book_rounded,
              labelKey: 'nav.courses',   page: CoursesPage()),
        ]),
        RoleNavGroup(labelKey: 'sections.activity', entries: [
          RoleNavEntry(icon: Icons.grading_outlined,    activeIcon: Icons.grading_rounded,
              labelKey: 'nav.grades',    page: GradesPage()),
          RoleNavEntry(icon: Icons.calendar_month_outlined,
              activeIcon: Icons.calendar_month_rounded,
              labelKey: 'nav.schedule',  page: SchedulePage()),
          RoleNavEntry(icon: Icons.assignment_outlined,
              activeIcon: Icons.assignment_rounded,
              labelKey: 'nav.homework',  page: HomeworkStudentPage()),
          RoleNavEntry(icon: Icons.fact_check_outlined,
              activeIcon: Icons.fact_check_rounded,
              labelKey: 'nav.attendance', page: AttendancePage()),
          RoleNavEntry(icon: Icons.receipt_long_outlined,
              activeIcon: Icons.receipt_long_rounded,
              labelKey: 'nav.bulletin',  page: BulletinPage()),
          RoleNavEntry(icon: Icons.local_library_outlined,
              activeIcon: Icons.local_library_rounded,
              labelKey: 'nav.library',   page: LibraryPage()),
        ]),
        RoleNavGroup(labelKey: 'sections.account', entries: [
          RoleNavEntry(icon: Icons.chat_outlined,   activeIcon: Icons.chat_rounded,
              labelKey: 'nav.messages',  page: MessagingPage()),
          RoleNavEntry(icon: Icons.apps_outlined,   activeIcon: Icons.apps_rounded,
              labelKey: 'nav.features',  page: FeaturesHubPage()),
        ]),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Dashboard principal
// ══════════════════════════════════════════════════════════════════════════
class _StudentDashboard extends ConsumerStatefulWidget {
  const _StudentDashboard();
  @override
  ConsumerState<_StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends ConsumerState<_StudentDashboard> {
  bool _loading = true;

  static const _moyenneProgression = [12.5, 13.8, 14.2, 14.8, 15.4];
  static const _semLabels = ['S1', 'S2', 'S3', 'S4', 'S5'];
  static const _absences = [2.0, 1.0, 0.0, 1.0, 0.0];

  static const _recentNotes = [
    (sub: 'Mathématiques', n: 17.5, max: 20.0, c: _gold,  d: '28 Mai'),
    (sub: 'Physique',      n: 13.0, max: 20.0, c: _terra, d: '25 Mai'),
    (sub: 'Histoire',      n: 15.5, max: 20.0, c: _green, d: '22 Mai'),
  ];

  static const _devoirs = [
    (sub: 'Mathématiques', titre: 'Exercices page 124', echeance: 'Demain',    c: _gold),
    (sub: 'Physique',      titre: 'Résumé chapitre 8',  echeance: 'Dans 2j',   c: _cyan),
  ];

  static const _edt = [
    (h: '08:00', sub: 'Mathématiques', room: 'A12',  c: _terra),
    (h: '10:00', sub: 'Français',      room: 'B04',  c: _gold),
    (h: '14:00', sub: 'Sciences',      room: 'Labo', c: _green),
    (h: '16:00', sub: 'Histoire',      room: 'C01',  c: _cyan),
  ];

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 900),
        () { if (mounted) setState(() => _loading = false); });
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bonjour';
    if (h < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }

  void _push(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final user     = ref.watch(authSessionProvider);
    final name     = user?.fullName ?? 'Étudiant';
    final initials = _initials(name);

    return Container(
      color: _bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── 1. Hero profil ────────────────────────────────────────
          _HeroCard(
            greeting: _greeting, name: name, initials: initials,
            loading: _loading,
          ),
          const SizedBox(height: 14),

          // ── 2. Stats rapides ──────────────────────────────────────
          _QuickStats(loading: _loading),
          const SizedBox(height: 20),

          // ── 3. Accès rapide (cartes premium animées) ──────────────
          _SectionHeader(
            icon: Icons.flash_on_rounded,
            title: 'Accès rapide',
            iconGradient: [_gold, _orange],
          ),
          const SizedBox(height: 10),
          _PremiumShortcutsGrid(onTap: {
            'notes':         () => _push(const GradesPage()),
            'edt':           () => _push(const SchedulePage()),
            'devoirs':       () => _push(const HomeworkStudentPage()),
            'presences':     () => _push(const AttendancePage()),
            'cours':         () => _push(const CoursesPage()),
            'messages':      () => _push(const MessagingPage()),
            'bulletin':      () => _push(const BulletinPage()),
            'bibliotheque':  () => _push(const LibraryPage()),
            'features':      () => _push(const FeaturesHubPage()),
          }),
          const SizedBox(height: 22),

          // ── 4. Résumé présences ───────────────────────────────────
          _SectionHeader(
            icon: Icons.fact_check_rounded,
            title: 'Résumé des présences',
            iconGradient: [_green, const Color(0xFF2E7D32)],
            action: 'Voir tout',
            onAction: () => _push(const AttendancePage()),
          ),
          const SizedBox(height: 10),
          _AttendanceSummaryCard(onTap: () => _push(const AttendancePage())),
          const SizedBox(height: 22),

          // ── 5. EDT du jour ────────────────────────────────────────
          _SectionHeader(
            icon: Icons.calendar_today_rounded,
            title: 'Emploi du temps du jour',
            iconGradient: [_terra, _orange],
            action: 'Tout voir',
            onAction: () => _push(const SchedulePage()),
          ),
          const SizedBox(height: 10),
          Skeletonizer(
            enabled: _loading,
            effect: const ShimmerEffect(baseColor: Color(0xFFDDD6CE), highlightColor: Color(0xFFEFEAE3)),
            child: _EdtTimeline(slots: _edt),
          ),
          const SizedBox(height: 22),

          // ── 6. Progression des notes ──────────────────────────────
          _SectionHeader(
            icon: Icons.show_chart_rounded,
            title: 'Progression des notes',
            iconGradient: [_gold, _orange],
            trailing: _SmallBadge('5 semaines', _green),
          ),
          const SizedBox(height: 10),
          Skeletonizer(
            enabled: _loading,
            effect: const ShimmerEffect(baseColor: Color(0xFFDDD6CE), highlightColor: Color(0xFFEFEAE3)),
            child: _NoteProgressionChart(
              values: _moyenneProgression,
              labels: _semLabels,
            ),
          ),
          const SizedBox(height: 22),

          // ── 7. Absences graphique ─────────────────────────────────
          _SectionHeader(
            icon: Icons.bar_chart_rounded,
            title: 'Présences · Absences',
            iconGradient: [_terra, _orange],
            trailing: _SmallBadge('T2', _terra),
          ),
          const SizedBox(height: 10),
          Skeletonizer(
            enabled: _loading,
            effect: const ShimmerEffect(baseColor: Color(0xFFDDD6CE), highlightColor: Color(0xFFEFEAE3)),
            child: _AbsenceChart(absences: _absences, labels: _semLabels),
          ),
          const SizedBox(height: 22),

          // ── 8. Devoirs urgents ────────────────────────────────────
          _SectionHeader(
            icon: Icons.assignment_late_rounded,
            title: 'Devoirs à rendre',
            iconGradient: [_orange, const Color(0xFFBF360C)],
            action: 'Voir tout',
            onAction: () => _push(const HomeworkStudentPage()),
          ),
          const SizedBox(height: 10),
          Skeletonizer(
            enabled: _loading,
            effect: const ShimmerEffect(baseColor: Color(0xFFDDD6CE), highlightColor: Color(0xFFEFEAE3)),
            child: Column(children: [
              for (final d in _devoirs) ...[
                _DevoirCard(sub: d.sub, titre: d.titre,
                    echeance: d.echeance, color: d.c,
                    onTap: () => _push(const HomeworkStudentPage())),
                const SizedBox(height: 8),
              ],
            ]),
          ),
          const SizedBox(height: 22),

          // ── 9. Dernières notes ────────────────────────────────────
          _SectionHeader(
            icon: Icons.grading_rounded,
            title: 'Dernières notes',
            iconGradient: [_gold, const Color(0xFFF57F17)],
            action: 'Toutes les notes',
            onAction: () => _push(const GradesPage()),
          ),
          const SizedBox(height: 10),
          Skeletonizer(
            enabled: _loading,
            effect: const ShimmerEffect(baseColor: Color(0xFFDDD6CE), highlightColor: Color(0xFFEFEAE3)),
            child: Column(children: [
              for (final n in _recentNotes) ...[
                _NoteRow(sub: n.sub, note: n.n, max: n.max,
                    date: n.d, color: n.c,
                    onTap: () => _push(const GradesPage())),
                const SizedBox(height: 8),
              ],
            ]),
          ),
          const SizedBox(height: 22),

          // ── 10. Annonces ──────────────────────────────────────────
          _SectionHeader(
            icon: Icons.campaign_rounded,
            title: 'Dernières annonces',
            iconGradient: [_purple, const Color(0xFF5B21B6)],
          ),
          const SizedBox(height: 10),
          Skeletonizer(
            enabled: _loading,
            effect: const ShimmerEffect(baseColor: Color(0xFFDDD6CE), highlightColor: Color(0xFFEFEAE3)),
            child: const _AnnouncementsCard(),
          ),
          const SizedBox(height: 22),

          // ── 11. Calendrier événements ─────────────────────────────
          _SectionHeader(
            icon: Icons.event_rounded,
            title: 'Événements à venir',
            iconGradient: [_cyan, const Color(0xFF006064)],
          ),
          const SizedBox(height: 10),
          Skeletonizer(
            enabled: _loading,
            effect: const ShimmerEffect(baseColor: Color(0xFFDDD6CE), highlightColor: Color(0xFFEFEAE3)),
            child: const _EventsCard(),
          ),
          const SizedBox(height: 22),

          // ── 12. Bulletin résumé ───────────────────────────────────
          _BulletinSummaryCard(onTap: () => _push(const BulletinPage())),
          const SizedBox(height: 22),

          // ── 13. Statistiques hebdo ────────────────────────────────
          _SectionHeader(
            icon: Icons.analytics_rounded,
            title: 'Statistiques hebdomadaires',
            iconGradient: [_green, _cyan],
          ),
          const SizedBox(height: 10),
          const _WeeklyStatsCard(),
          const SizedBox(height: 22),

          // ── 14. Citation africaine ────────────────────────────────
          const _AfricanQuote(),
        ]),
      ),
    );
  }

  String _initials(String name) {
    final p = name.trim().split(' ').where((s) => s.isNotEmpty).toList();
    if (p.isEmpty) return 'E';
    if (p.length == 1) return p[0][0].toUpperCase();
    return (p[0][0] + p[1][0]).toUpperCase();
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Hero profil — design premium social
// ══════════════════════════════════════════════════════════════════════════
class _HeroCard extends StatelessWidget {
  final String greeting, name, initials;
  final bool loading;
  const _HeroCard({
    required this.greeting, required this.name,
    required this.initials, required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A0500), _dark, _terra],
          stops: [0.0, 0.40, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: _terra.withOpacity(0.45),
              blurRadius: 32, offset: const Offset(0, 14), spreadRadius: -6),
          BoxShadow(color: _dark.withOpacity(0.25),
              blurRadius: 6, offset: const Offset(0, 3)),
        ],
      ),
      child: Stack(children: [
        // Cercle décoratif en arrière-plan
        Positioned(right: -30, top: -30,
          child: Container(
            width: 130, height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _white.withOpacity(0.04),
            ),
          ),
        ),
        Positioned(right: 40, bottom: -20,
          child: Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _gold.withOpacity(0.08),
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Avatar
              _AvatarCircle(initials: initials),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(greeting, style: TextStyle(
                    color: _white.withOpacity(0.60), fontSize: 12)),
                const SizedBox(height: 2),
                Text(name, style: const TextStyle(color: _white,
                    fontSize: 20, fontWeight: FontWeight.w900, height: 1.1)),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  _Badge(label: 'Terminale A',
                      bg: _gold.withOpacity(0.22), border: _gold.withOpacity(0.50), fg: _gold),
                  _Badge(label: '• Trimestre 2',
                      bg: _white.withOpacity(0.12), border: _white.withOpacity(0.25),
                      fg: _white.withOpacity(0.85)),
                ]),
              ])),
            ]),

            const SizedBox(height: 16),

            // Infos profil row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _white.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _white.withOpacity(0.15)),
              ),
              child: Row(children: [
                _ProfileInfo(icon: Icons.badge_outlined, label: 'ID', value: 'ETU-2026-0042'),
                _ProfileDivider(),
                _ProfileInfo(icon: Icons.leaderboard_outlined, label: 'Rang', value: '4e / 32'),
                _ProfileDivider(),
                _ProfileInfo(icon: Icons.radio_button_checked_rounded, label: 'Statut', value: 'Actif',
                    valueColor: _green),
              ]),
            ),
            const SizedBox(height: 12),

            // Barre examen
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _white.withOpacity(0.12)),
              ),
              child: Row(children: [
                Icon(Icons.timer_outlined, color: _gold, size: 15),
                const SizedBox(width: 6),
                if (loading)
                  Container(width: 140, height: 14, decoration: BoxDecoration(
                    color: _white.withOpacity(0.2), borderRadius: BorderRadius.circular(6)))
                else
                  RichText(text: TextSpan(
                    style: TextStyle(color: _white.withOpacity(0.75), fontSize: 12),
                    children: const [
                      TextSpan(text: 'Examens dans '),
                      TextSpan(text: '47 jours',
                          style: TextStyle(color: _gold,
                              fontWeight: FontWeight.w800, fontSize: 14)),
                    ],
                  )),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [_gold, Color(0xFFE8A83A)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [BoxShadow(color: _gold.withOpacity(0.40),
                        blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: const Text('Réviser',
                      style: TextStyle(color: _dark, fontSize: 11,
                          fontWeight: FontWeight.w800)),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _ProfileInfo extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color? valueColor;
  const _ProfileInfo({required this.icon, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Icon(icon, size: 12, color: _white.withOpacity(0.50)),
    const SizedBox(height: 3),
    Text(label, style: TextStyle(color: _white.withOpacity(0.50), fontSize: 9, fontWeight: FontWeight.w600)),
    const SizedBox(height: 2),
    Text(value, style: TextStyle(
        color: valueColor ?? _white,
        fontSize: 10, fontWeight: FontWeight.w800),
        maxLines: 1, overflow: TextOverflow.ellipsis),
  ]));
}

class _ProfileDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1, height: 30, color: _white.withOpacity(0.15),
    margin: const EdgeInsets.symmetric(horizontal: 8),
  );
}

class _AvatarCircle extends StatelessWidget {
  final String initials;
  const _AvatarCircle({required this.initials});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64, height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFFE8A83A), _gold],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        border: Border.all(color: _white, width: 3),
        boxShadow: [BoxShadow(color: _gold.withOpacity(0.50),
            blurRadius: 14, offset: const Offset(0, 5))],
      ),
      child: Center(child: Text(initials,
          style: const TextStyle(color: _dark, fontSize: 22,
              fontWeight: FontWeight.w900))),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color bg, border, fg;
  const _Badge({required this.label, required this.bg,
      required this.border, required this.fg});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border)),
    child: Text(label, style: TextStyle(
        color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
  );
}

// ══════════════════════════════════════════════════════════════════════════
// Stats rapides
// ══════════════════════════════════════════════════════════════════════════
class _QuickStats extends StatelessWidget {
  final bool loading;
  const _QuickStats({required this.loading});

  static const _data = [
    (icon: Icons.star_rounded,         label: 'Moyenne',  val: '15.4', sub: '/20',      c: _gold),
    (icon: Icons.check_circle_rounded, label: 'Présence', val: '96',   sub: ' %',       c: _green),
    (icon: Icons.assignment_rounded,   label: 'Devoirs',  val: '3',    sub: ' en cours', c: _terra),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      for (int i = 0; i < _data.length; i++) ...[
        Expanded(child: Skeletonizer(
          enabled: loading,
          effect: const ShimmerEffect(baseColor: Color(0xFFDDD6CE), highlightColor: Color(0xFFEFEAE3)),
          child: _QuickStatPill(d: _data[i]),
        )),
        if (i < _data.length - 1) const SizedBox(width: 10),
      ],
    ]);
  }
}

class _QuickStatPill extends StatelessWidget {
  final ({IconData icon, String label, String val, String sub, Color c}) d;
  const _QuickStatPill({required this.d});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: ScolarisSurface.accent(color: d.c, radius: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
              color: d.c.withOpacity(0.18), borderRadius: BorderRadius.circular(8)),
          child: Icon(d.icon, color: d.c, size: 14),
        ),
        const SizedBox(height: 7),
        Text(d.label, style: TextStyle(
            color: d.c.withOpacity(0.75), fontSize: 10, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        RichText(text: TextSpan(children: [
          TextSpan(text: d.val,
              style: TextStyle(color: d.c, fontSize: 18, fontWeight: FontWeight.w900)),
          TextSpan(text: d.sub,
              style: TextStyle(color: d.c.withOpacity(0.65), fontSize: 10)),
        ])),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Section header avec icône
// ══════════════════════════════════════════════════════════════════════════
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Color> iconGradient;
  final String? action;
  final VoidCallback? onAction;
  final Widget? trailing;
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.iconGradient,
    this.action,
    this.onAction,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: iconGradient,
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(9),
          boxShadow: [BoxShadow(color: iconGradient.first.withOpacity(0.35),
              blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Icon(icon, color: _white, size: 15),
      ),
      const SizedBox(width: 8),
      Expanded(child: Text(title, style: const TextStyle(
          fontSize: 14.5, color: _ink, fontWeight: FontWeight.w800,
          letterSpacing: -0.2))),
      if (trailing != null) trailing!,
      if (action != null) ...[
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onAction,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _terra.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(action!, style: const TextStyle(
                color: _terra, fontSize: 11.5, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    ]);
  }
}

class _SmallBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _SmallBadge(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
        color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.30))),
    child: Text(label, style: TextStyle(
        color: color, fontSize: 10, fontWeight: FontWeight.w700)),
  );
}

// ══════════════════════════════════════════════════════════════════════════
// Raccourcis premium animés
// ══════════════════════════════════════════════════════════════════════════
class _PremiumShortcutsGrid extends StatelessWidget {
  final Map<String, VoidCallback> onTap;
  const _PremiumShortcutsGrid({required this.onTap});

  static const _items = [
    (key: 'notes',       icon: Icons.grading_rounded,          label: 'Notes',        sub: 'Résultats',   grad: [Color(0xFFC17F24), Color(0xFFE8A83A)]),
    (key: 'edt',         icon: Icons.calendar_month_rounded,    label: 'Emploi',       sub: 'du temps',    grad: [Color(0xFF8B1A00), Color(0xFFD4540A)]),
    (key: 'devoirs',     icon: Icons.assignment_rounded,         label: 'Devoirs',      sub: '2 urgents',   grad: [Color(0xFFD4540A), Color(0xFFEF6C00)]),
    (key: 'presences',   icon: Icons.fact_check_rounded,         label: 'Présences',    sub: '96% T2',      grad: [Color(0xFF1B5E20), Color(0xFF388E3C)]),
    (key: 'cours',       icon: Icons.menu_book_rounded,          label: 'Cours',        sub: 'Catalogue',   grad: [Color(0xFF6D28D9), Color(0xFF8B5CF6)]),
    (key: 'bibliotheque',icon: Icons.local_library_rounded,      label: 'Biblio.',      sub: 'Ressources',  grad: [Color(0xFF7B341E), Color(0xFFB44000)]),
    (key: 'messages',    icon: Icons.chat_rounded,               label: 'Messages',     sub: '1 nouveau',   grad: [Color(0xFF7C3AED), Color(0xFFA855F7)]),
    (key: 'bulletin',    icon: Icons.receipt_long_rounded,        label: 'Bulletin',     sub: 'Trimestriel', grad: [Color(0xFF0891B2), Color(0xFF06B6D4)]),
    (key: 'features',    icon: Icons.apps_rounded,               label: 'Tout',         sub: 'Explorer',    grad: [Color(0xFF374151), Color(0xFF6B7280)]),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10, mainAxisSpacing: 10,
      childAspectRatio: 0.88,
      children: _items.map((item) =>
          _PremiumCard(item: item, onTap: onTap[item.key])).toList(),
    );
  }
}

class _PremiumCard extends StatefulWidget {
  final ({String key, IconData icon, String label, String sub, List<Color> grad}) item;
  final VoidCallback? onTap;
  const _PremiumCard({required this.item, this.onTap});

  @override
  State<_PremiumCard> createState() => _PremiumCardState();
}

class _PremiumCardState extends State<_PremiumCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: 0.92).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final grad = widget.item.grad;
    return GestureDetector(
      onTapDown: (_) { _ctrl.forward(); setState(() => _pressed = true); },
      onTapUp: (_) { _ctrl.reverse(); setState(() => _pressed = false); widget.onTap?.call(); },
      onTapCancel: () { _ctrl.reverse(); setState(() => _pressed = false); },
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: grad,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: grad.first.withOpacity(_pressed ? 0.55 : 0.40),
                blurRadius: _pressed ? 18 : 12,
                offset: Offset(0, _pressed ? 7 : 5),
                spreadRadius: -2,
              ),
              BoxShadow(
                color: _white.withOpacity(0.12),
                blurRadius: 1,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          padding: const EdgeInsets.all(11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Icon avec effet lumière
              Stack(children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: _white.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _white.withOpacity(0.30)),
                  ),
                  child: Icon(widget.item.icon, color: _white, size: 18),
                ),
                // Effet brillance
                Positioned(top: 0, right: 0,
                  child: Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _white.withOpacity(0.30),
                    ),
                  ),
                ),
              ]),
              // Labels
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.item.label, style: const TextStyle(
                    color: _white, fontSize: 11.5, fontWeight: FontWeight.w800,
                    shadows: [Shadow(color: Color(0x44000000), blurRadius: 4)]),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(widget.item.sub, style: TextStyle(
                    color: _white.withOpacity(0.72), fontSize: 9,
                    fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Résumé présences
// ══════════════════════════════════════════════════════════════════════════
class _AttendanceSummaryCard extends StatelessWidget {
  final VoidCallback onTap;
  const _AttendanceSummaryCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    const summary = MockData.attendanceSummary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: ScolarisSurface.card(radius: 16),
        child: Column(children: [
          Row(children: [
            _AttPresCell(icon: Icons.check_circle_rounded, label: 'Présents',
                val: '${summary.presents}', color: _green),
            _AttDivider(),
            _AttPresCell(icon: Icons.cancel_rounded, label: 'Absents',
                val: '${summary.absents}', color: _terra),
            _AttDivider(),
            _AttPresCell(icon: Icons.access_time_rounded, label: 'Retards',
                val: '${summary.retards}', color: _gold),
            _AttDivider(),
            _AttPresCell(icon: Icons.percent_rounded, label: 'Taux',
                val: '${summary.tauxPresence.toStringAsFixed(0)}%', color: _cyan),
          ]),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: summary.tauxPresence / 100,
              minHeight: 8,
              backgroundColor: _terra.withOpacity(0.12),
              valueColor: const AlwaysStoppedAnimation<Color>(_green),
            ),
          ),
          const SizedBox(height: 6),
          Row(children: [
            Text('${summary.tauxPresence.toStringAsFixed(1)}% de présence sur ${summary.joursTotal} jours',
                style: const TextStyle(color: _muted, fontSize: 11)),
            const Spacer(),
            Text('Voir le détail →',
                style: const TextStyle(color: _terra, fontSize: 11, fontWeight: FontWeight.w700)),
          ]),
        ]),
      ),
    );
  }
}

class _AttPresCell extends StatelessWidget {
  final IconData icon;
  final String label, val;
  final Color color;
  const _AttPresCell({required this.icon, required this.label, required this.val, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Icon(icon, size: 18, color: color),
    const SizedBox(height: 4),
    Text(val, style: TextStyle(fontSize: 16, color: color, fontWeight: FontWeight.w900)),
    Text(label, style: const TextStyle(fontSize: 9.5, color: _muted, fontWeight: FontWeight.w600)),
  ]));
}

class _AttDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1, height: 40, color: const Color(0xFFDDCCBB),
  );
}

// ══════════════════════════════════════════════════════════════════════════
// Courbe progression des notes
// ══════════════════════════════════════════════════════════════════════════
class _NoteProgressionChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  const _NoteProgressionChart({required this.values, required this.labels});

  @override
  Widget build(BuildContext context) {
    final spots = values.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();
    final trend = values.last - values.first;
    final trendUp = trend >= 0;

    return Container(
      decoration: ScolarisSurface.card(radius: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Progression des notes', style: TextStyle(
              color: _ink, fontSize: 13, fontWeight: FontWeight.w800)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: (trendUp ? _green : _terra).withOpacity(0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: (trendUp ? _green : _terra).withOpacity(0.30))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(trendUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  color: trendUp ? _green : _terra, size: 13),
              const SizedBox(width: 4),
              Text('${trendUp ? '+' : ''}${trend.toStringAsFixed(1)} pts',
                  style: TextStyle(color: trendUp ? _green : _terra,
                      fontSize: 10, fontWeight: FontWeight.w800)),
            ]),
          ),
        ]),
        const SizedBox(height: 4),
        Text('Moyenne générale sur ${values.length} semaines',
            style: const TextStyle(color: _muted, fontSize: 10)),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: LineChart(LineChartData(
            minY: 8.0, maxY: 20.0,
            gridData: FlGridData(show: true, drawVerticalLine: false,
              horizontalInterval: 4.0,
              getDrawingHorizontalLine: (_) => FlLine(
                  color: _ink.withOpacity(0.06), strokeWidth: 1.0)),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true, reservedSize: 28.0,
                getTitlesWidget: (v, _) => Text('${v.toInt()}',
                    style: const TextStyle(color: _muted, fontSize: 9, fontWeight: FontWeight.w600)),
              )),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true, reservedSize: 22.0,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= labels.length) return const SizedBox();
                  return Text(labels[i], style: const TextStyle(
                      color: _muted, fontSize: 9, fontWeight: FontWeight.w600));
                },
              )),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots, isCurved: true, curveSmoothness: 0.35,
                color: _gold, barWidth: 2.5,
                dotData: FlDotData(show: true, getDotPainter: (s, _, __, ___) =>
                    FlDotCirclePainter(radius: 4.0, color: _gold, strokeWidth: 2.0, strokeColor: _white)),
                belowBarData: BarAreaData(show: true, gradient: LinearGradient(
                  colors: [_gold.withOpacity(0.22), _gold.withOpacity(0.0)],
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                )),
              ),
            ],
            lineTouchData: LineTouchData(touchTooltipData: LineTouchTooltipData(
              tooltipRoundedRadius: 8.0,
              getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                '${s.y}/20', const TextStyle(color: _white, fontSize: 11, fontWeight: FontWeight.w700),
              )).toList(),
            )),
          )),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Bar chart absences
// ══════════════════════════════════════════════════════════════════════════
class _AbsenceChart extends StatelessWidget {
  final List<double> absences;
  final List<String> labels;
  const _AbsenceChart({required this.absences, required this.labels});

  @override
  Widget build(BuildContext context) {
    final totalAbs     = absences.reduce((a, b) => a + b);
    final totalHours   = absences.length * 5.0;
    final presencePct  = ((totalHours - totalAbs) / totalHours * 100).round();

    return Container(
      decoration: ScolarisSurface.card(radius: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text('Absences par semaine', style: TextStyle(
              color: _ink, fontSize: 13, fontWeight: FontWeight.w800))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: _green.withOpacity(0.10), borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _green.withOpacity(0.30))),
            child: Text('$presencePct% présent',
                style: const TextStyle(color: _green, fontSize: 10, fontWeight: FontWeight.w800)),
          ),
        ]),
        const SizedBox(height: 4),
        Text('Total absences · ${totalAbs.toInt()} heure(s) ce trimestre',
            style: const TextStyle(color: _muted, fontSize: 10)),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 3, child: SizedBox(
            height: 110,
            child: BarChart(BarChartData(
              maxY: 4.0, minY: 0.0,
              gridData: FlGridData(show: true, drawVerticalLine: false,
                horizontalInterval: 2.0,
                getDrawingHorizontalLine: (_) => FlLine(
                    color: _ink.withOpacity(0.06), strokeWidth: 1.0)),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true, reservedSize: 20.0,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= labels.length) return const SizedBox();
                    return Text(labels[i], style: const TextStyle(
                        color: _muted, fontSize: 9, fontWeight: FontWeight.w600));
                  },
                )),
              ),
              barGroups: absences.asMap().entries.map((e) =>
                  BarChartGroupData(x: e.key, barRods: [
                    BarChartRodData(
                      toY: e.value, width: 20.0,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      gradient: LinearGradient(
                        colors: e.value > 0
                            ? [_terra, _orange] : [_green.withOpacity(0.5), _green],
                        begin: Alignment.bottomCenter, end: Alignment.topCenter,
                      ),
                    ),
                  ])).toList(),
              barTouchData: BarTouchData(touchTooltipData: BarTouchTooltipData(
                tooltipRoundedRadius: 8.0,
                getTooltipItem: (g, _, r, __) => BarTooltipItem(
                  r.toY == 0 ? 'Présent ✓' : '${r.toY.toInt()} abs',
                  const TextStyle(color: _white, fontSize: 10, fontWeight: FontWeight.w700),
                ),
              )),
            )),
          )),
          const SizedBox(width: 14),
          SizedBox(width: 90, height: 110,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              SizedBox(width: 70, height: 70,
                child: Stack(alignment: Alignment.center, children: [
                  PieChart(PieChartData(
                    startDegreeOffset: -90, sectionsSpace: 0, centerSpaceRadius: 24,
                    sections: [
                      PieChartSectionData(value: presencePct.toDouble(),
                          color: _green, radius: 12.0, showTitle: false),
                      PieChartSectionData(value: (100 - presencePct).toDouble(),
                          color: _terra.withOpacity(0.20), radius: 12.0, showTitle: false),
                    ],
                  )),
                  Text('$presencePct%', style: const TextStyle(
                      color: _green, fontSize: 12, fontWeight: FontWeight.w900)),
                ]),
              ),
              const SizedBox(height: 6),
              const Text('Présence', style: TextStyle(
                  color: _muted, fontSize: 10, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// EDT du jour
// ══════════════════════════════════════════════════════════════════════════
class _EdtTimeline extends StatelessWidget {
  final List<({String h, String sub, String room, Color c})> slots;
  const _EdtTimeline({required this.slots});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 106,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: slots.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final s = slots[i];
          final first = i == 0;
          return Container(
            width: 92,
            decoration: first
                ? BoxDecoration(
                    gradient: LinearGradient(
                        colors: [s.c, s.c.withOpacity(0.72)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: s.c.withOpacity(0.40),
                        blurRadius: 12, offset: const Offset(0, 5))],
                  )
                : ScolarisSurface.accent(color: s.c, radius: 16),
            padding: const EdgeInsets.all(11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                        color: first ? _white.withOpacity(0.25) : s.c.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.school_rounded, size: 14, color: first ? _white : s.c),
                  ),
                  if (first)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                          color: _white.withOpacity(0.22),
                          borderRadius: BorderRadius.circular(4)),
                      child: const Text('Actif', style: TextStyle(
                          color: _white, fontSize: 7, fontWeight: FontWeight.w800)),
                    ),
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.sub, style: TextStyle(
                      color: first ? _white : _ink, fontSize: 11, fontWeight: FontWeight.w800),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(s.h, style: TextStyle(
                      color: first ? _white.withOpacity(0.80) : s.c,
                      fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Devoir card
// ══════════════════════════════════════════════════════════════════════════
class _DevoirCard extends StatelessWidget {
  final String sub, titre, echeance;
  final Color color;
  final VoidCallback onTap;
  const _DevoirCard({required this.sub, required this.titre,
      required this.echeance, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: ScolarisSurface.card(radius: 13),
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [color.withOpacity(0.12), color.withOpacity(0.24)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.25)),
            ),
            child: Icon(Icons.assignment_outlined, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(sub, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(titre, style: const TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Row(children: [
              Icon(Icons.schedule_rounded, size: 10, color: _muted),
              const SizedBox(width: 4),
              Text(echeance, style: const TextStyle(color: _muted, fontSize: 11)),
            ]),
          ])),
          Icon(Icons.chevron_right_rounded, color: _muted.withOpacity(0.50), size: 20),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Note row
// ══════════════════════════════════════════════════════════════════════════
class _NoteRow extends StatelessWidget {
  final String sub, date;
  final double note, max;
  final Color color;
  final VoidCallback onTap;
  const _NoteRow({required this.sub, required this.note, required this.max,
      required this.date, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pct = note / max;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: ScolarisSurface.card(radius: 13),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          SizedBox(width: 46, height: 46,
            child: Stack(alignment: Alignment.center, children: [
              SizedBox(width: 46, height: 46,
                child: CircularProgressIndicator(
                  value: pct, strokeWidth: 4,
                  backgroundColor: color.withOpacity(0.12),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
              Text(note.toStringAsFixed(1),
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900)),
            ]),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(sub, style: const TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct, minHeight: 5,
                backgroundColor: color.withOpacity(0.10),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ])),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                  color: (pct >= 0.7 ? _green : _terra).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(6)),
              child: Text(pct >= 0.7 ? '✓ Bien' : '→ Effort',
                  style: TextStyle(
                      color: pct >= 0.7 ? _green : _terra,
                      fontSize: 9, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 4),
            Text(date, style: const TextStyle(color: _muted, fontSize: 10)),
          ]),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Annonces
// ══════════════════════════════════════════════════════════════════════════
class _AnnouncementsCard extends StatelessWidget {
  const _AnnouncementsCard();

  static const _items = [
    (icon: Icons.event_note_rounded, color: Color(0xFF8B1A00),
     title: 'Examens de fin de trimestre',
     body: 'Les examens T2 auront lieu du 23 au 27 juin.',
     author: 'Direction', time: 'Il y a 2h'),
    (icon: Icons.calculate_rounded, color: Color(0xFF6D28D9),
     title: 'Nouveau programme de maths',
     body: 'Le chapitre 9 sur les probabilités est disponible.',
     author: 'M. Dupont', time: 'Il y a 5h'),
    (icon: Icons.park_rounded, color: Color(0xFF0891B2),
     title: 'Sortie botanique SVT',
     body: 'Autorisations parentales avant le 15 juin.',
     author: 'Dr. Yao', time: 'Hier'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _items.map((a) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: a.color.withOpacity(0.20)),
          boxShadow: [BoxShadow(color: a.color.withOpacity(0.08),
              blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [a.color, a.color.withOpacity(0.70)]),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(a.icon, color: _white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.title, style: const TextStyle(fontSize: 13, color: _ink, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(a.body, style: const TextStyle(fontSize: 11.5, color: _muted, height: 1.4)),
            const SizedBox(height: 6),
            Row(children: [
              Text(a.author, style: TextStyle(fontSize: 10.5, color: a.color, fontWeight: FontWeight.w700)),
              const SizedBox(width: 6),
              const Text('·', style: TextStyle(color: _muted, fontSize: 10)),
              const SizedBox(width: 6),
              Text(a.time, style: const TextStyle(fontSize: 10.5, color: _muted)),
            ]),
          ])),
        ]),
      )).toList(),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Événements
// ══════════════════════════════════════════════════════════════════════════
class _EventsCard extends StatelessWidget {
  const _EventsCard();

  static const _events = [
    (title: 'Conseil de classe T2',    date: '12 Juin', type: 'Académique', color: Color(0xFF6D28D9)),
    (title: 'Sortie botanique SVT',    date: '18 Juin', type: 'Sortie',     color: Color(0xFF0891B2)),
    (title: 'Examens fin T2',          date: '25 Juin', type: 'Examen',     color: Color(0xFF8B1A00)),
    (title: 'Journée portes ouvertes', date: '5 Juil',  type: 'École',      color: Color(0xFFC17F24)),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ScolarisSurface.card(radius: 16),
      child: Column(
        children: _events.asMap().entries.map((e) {
          final ev = e.value;
          final last = e.key == _events.length - 1;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              border: last ? null : Border(
                  bottom: BorderSide(color: const Color(0xFFDDCCBB).withOpacity(0.50))),
            ),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: ev.color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ev.color.withOpacity(0.25)),
                ),
                child: Center(child: Text(ev.date.split(' ')[0],
                    style: TextStyle(color: ev.color, fontSize: 10, fontWeight: FontWeight.w900))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ev.title, style: const TextStyle(fontSize: 13, color: _ink, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: ev.color.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(ev.type, style: TextStyle(
                        color: ev.color, fontSize: 9.5, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 6),
                  Text(ev.date, style: const TextStyle(fontSize: 11, color: _muted)),
                ]),
              ])),
              Icon(Icons.arrow_forward_ios_rounded, size: 12, color: _muted.withOpacity(0.50)),
            ]),
          );
        }).toList(),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Bulletin résumé card
// ══════════════════════════════════════════════════════════════════════════
class _BulletinSummaryCard extends StatelessWidget {
  final VoidCallback onTap;
  const _BulletinSummaryCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF0D3B1E), _green],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: _green.withOpacity(0.35),
              blurRadius: 20, offset: const Offset(0, 8), spreadRadius: -4)],
        ),
        padding: const EdgeInsets.all(18),
        child: Row(children: [
          const Icon(Icons.receipt_long_rounded, color: _gold, size: 24),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Bulletin Trimestriel',
                style: TextStyle(color: _white, fontSize: 14, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Row(children: [
              _TrimBadge('T1 · 13.2', active: false),
              const SizedBox(width: 8),
              _TrimBadge('T2 · 15.4', active: true),
              const SizedBox(width: 8),
              _TrimBadge('T3 · —', active: false),
            ]),
          ])),
          const Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 22),
        ]),
      ),
    );
  }
}

class _TrimBadge extends StatelessWidget {
  final String label;
  final bool active;
  const _TrimBadge(this.label, {required this.active});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: active ? _gold.withOpacity(0.25) : _white.withOpacity(0.12),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: active ? _gold.withOpacity(0.60) : _white.withOpacity(0.20)),
    ),
    child: Text(label, style: TextStyle(
        color: active ? _gold : _white.withOpacity(0.70),
        fontSize: 10, fontWeight: active ? FontWeight.w800 : FontWeight.w500)),
  );
}

// ══════════════════════════════════════════════════════════════════════════
// Statistiques hebdomadaires
// ══════════════════════════════════════════════════════════════════════════
class _WeeklyStatsCard extends StatelessWidget {
  const _WeeklyStatsCard();

  static const _stats = [
    (icon: Icons.access_time_rounded,  label: 'Heures de cours', val: '28h',    color: _cyan),
    (icon: Icons.check_rounded,         label: 'Devoirs rendus',  val: '5/6',    color: _green),
    (icon: Icons.star_rounded,          label: 'Notes obtenues',  val: '3',      color: _gold),
    (icon: Icons.trending_up_rounded,   label: 'Progression',     val: '+0.6',   color: _terra),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: ScolarisSurface.card(radius: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Cette semaine', style: TextStyle(
              fontSize: 13, color: _ink, fontWeight: FontWeight.w800)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _green.withOpacity(0.10), borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Semaine 24', style: TextStyle(
                color: _green, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10, mainAxisSpacing: 10,
          childAspectRatio: 2.6,
          children: _stats.map((s) => Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: s.color.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: s.color.withOpacity(0.20)),
            ),
            child: Row(children: [
              Icon(s.icon, size: 16, color: s.color),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(s.val, style: TextStyle(
                    fontSize: 14, color: s.color, fontWeight: FontWeight.w900)),
                Text(s.label, style: const TextStyle(
                    fontSize: 9.5, color: _muted, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
            ]),
          )).toList(),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Citation africaine
// ══════════════════════════════════════════════════════════════════════════
class _AfricanQuote extends StatelessWidget {
  const _AfricanQuote();

  static const _quotes = [
    (q: 'L\'éducation est l\'arme la plus puissante pour changer le monde.', a: 'Nelson Mandela'),
    (q: 'Chaque enfant qui apprend, chaque homme qui sait, enrichit toute la communauté.', a: 'Ubuntu'),
    (q: 'La connaissance est comme un jardin : si elle n\'est pas cultivée, elle ne peut pas être récoltée.', a: 'Proverbe Guinéen'),
  ];

  @override
  Widget build(BuildContext context) {
    final quote = _quotes[DateTime.now().weekday % _quotes.length];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_dark.withOpacity(0.92), _terra.withOpacity(0.85)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: _terra.withOpacity(0.25),
            blurRadius: 16, offset: const Offset(0, 6), spreadRadius: -3)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('"', style: TextStyle(
            color: _gold, fontSize: 36, fontWeight: FontWeight.w900, height: 0.8)),
        const SizedBox(height: 8),
        Text(quote.q, style: TextStyle(
            color: _white.withOpacity(0.90), fontSize: 13, height: 1.6,
            fontStyle: FontStyle.italic)),
        const SizedBox(height: 10),
        Row(children: [
          const Spacer(),
          Container(
            width: 24, height: 2,
            decoration: BoxDecoration(color: _gold, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 8),
          Text(quote.a, style: TextStyle(
              color: _gold, fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }
}

