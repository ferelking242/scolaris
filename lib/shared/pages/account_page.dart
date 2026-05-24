import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/user_entity.dart';
import '../../presentation/providers/auth_providers.dart';

// ── Tokens ─────────────────────────────────────────────────────────────────
const _terra  = ScolarisPalette.terracotta;
const _orange = ScolarisPalette.orange;
const _gold   = ScolarisPalette.gold;
const _green  = ScolarisPalette.forestGreen;
const _ink    = Color(0xFF1A0A00);
const _muted  = Color(0xFF7A5C44);
const _border = Color(0xFFDDCCBB);
const _white  = Colors.white;
const _bg     = Color(0xFFF5EEE6);

// ── Mock data (Supabase école test — Lycée Cheikh Anta Diop, Dakar) ────────
const _mockPhone    = '+221 77 123 45 67';
const _mockClass    = 'Terminale S3';
const _mockSchool   = 'Lycée Cheikh Anta Diop — Dakar';
const _mockId       = 'SCO-2024-STU-0047';
const _mockSince    = 'Septembre 2023';
const _mockAvg      = 15.4;
const _mockPresence = 96;
const _mockRank     = 4;
const _mockTotal    = 32;

const _mockCourses = [
  {'name': 'Mathématiques',    'teacher': 'Prof. Ndiaye', 'grade': 17.5, 'coef': 7},
  {'name': 'Sciences Physiq.', 'teacher': 'Prof. Sow',    'grade': 16.0, 'coef': 6},
  {'name': 'SVT',              'teacher': 'Prof. Diallo', 'grade': 14.5, 'coef': 5},
  {'name': 'Français',         'teacher': 'Prof. Touré',  'grade': 13.0, 'coef': 4},
  {'name': 'Philosophie',      'teacher': 'Prof. Ba',     'grade': 15.0, 'coef': 3},
  {'name': 'Histoire-Géo',     'teacher': 'Prof. Gaye',   'grade': 16.5, 'coef': 3},
  {'name': 'Anglais',          'teacher': 'Prof. Fall',   'grade': 14.0, 'coef': 3},
  {'name': 'EPS',              'teacher': 'Prof. Diop',   'grade': 16.0, 'coef': 2},
];

// ── Page ───────────────────────────────────────────────────────────────────
class AccountPage extends ConsumerStatefulWidget {
  const AccountPage({super.key});
  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(() => setState(() => _tabIndex = _tab.index));
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final user     = ref.watch(authSessionProvider);
    final name     = user?.fullName ?? 'Amadou Diallo';
    final email    = user?.email ?? 'amadou.diallo@scolaris.app';
    final role     = user?.role.name ?? 'student';
    final initials = name.split(' ')
        .map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase();
    final isPrivileged = role == 'admin' || role == 'teacher';

    return Scaffold(
      backgroundColor: _bg,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          // ── Cover + Avatar ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: _CoverSection(
              name: name, role: role,
              initials: initials, isPrivileged: isPrivileged,
            ),
          ),

          // ── Stats row ───────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: _StatsRow(),
            ),
          ),

          // ── Bio + action buttons ─────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _BioSection(school: _mockSchool, classe: _mockClass),
            ),
          ),

          // ── Tab bar (pinned) ─────────────────────────────────────────
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(_tab, _tabIndex),
          ),
        ],

        body: TabBarView(
          controller: _tab,
          children: [
            _TabTout(email: email, role: role),
            _TabContact(email: email),
            _TabAcademique(role: role),
          ],
        ),
      ),
    );
  }
}

// ── Cover section ─────────────────────────────────────────────────────────
class _CoverSection extends StatelessWidget {
  final String name;
  final String role;
  final String initials;
  final bool isPrivileged;
  const _CoverSection({
    required this.name, required this.role,
    required this.initials, required this.isPrivileged,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(clipBehavior: Clip.none, children: [
      // Cover gradient
      Container(
        height: 190,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A0A00), _terra],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(children: [
          CustomPaint(painter: _AfricanPatternPainter(), child: const SizedBox.expand()),
          // Back button
          Positioned(
            top: 0, left: 0,
            child: SafeArea(
              child: GestureDetector(
                onTap: () => Navigator.maybePop(context),
                child: Container(
                  margin: const EdgeInsets.all(12),
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: _white.withOpacity(.15), shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_back_rounded, color: _white, size: 20),
                ),
              ),
            ),
          ),
        ]),
      ),

      // Avatar (bottom left of cover — FB style, moitié dans la bannière)
      Positioned(
        bottom: -52, left: 20,
        child: Container(
          width: 104, height: 104,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A0A00), _terra, _orange],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            border: Border.all(color: _white, width: 4),
            boxShadow: [
              BoxShadow(color: _terra.withOpacity(.35),
                  blurRadius: 20, offset: const Offset(0, 6)),
              BoxShadow(color: Colors.black.withOpacity(.12),
                  blurRadius: 6, offset: const Offset(0, 2)),
            ],
          ),
          child: Center(child: Text(initials, style: const TextStyle(
              color: _white, fontSize: 32, fontWeight: FontWeight.w900))),
        ),
      ),

      // Name + badge (right of avatar, anchored to cover bottom)
      Positioned(
        bottom: -48, left: 140,
        right: 16,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(child: Text(name, style: const TextStyle(
                color: _ink, fontSize: 18, fontWeight: FontWeight.w900,
                letterSpacing: -.2),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
            if (isPrivileged) ...[
              const SizedBox(width: 5),
              const Icon(Icons.verified_rounded, color: _gold, size: 18),
            ],
          ]),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _terra.withOpacity(.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _terra.withOpacity(.25)),
            ),
            child: Text(role.toUpperCase(), style: const TextStyle(
                color: _terra, fontSize: 9.5,
                fontWeight: FontWeight.w800, letterSpacing: 1.2)),
          ),
        ]),
      ),

      // Spacer — taille totale du Stack (cover + avatar overflow)
      const SizedBox(height: 290),
    ]);
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 72),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: const [BoxShadow(
            color: Color(0x0C000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: IntrinsicHeight(
        child: Row(children: [
          _Stat('$_mockAvg /20', 'Moyenne',  _terra),
          _Div(), _Stat('$_mockPresence%',  'Présence', _green),
          _Div(), _Stat('$_mockRank/$_mockTotal', 'Classement', _gold),
          _Div(), _Stat('${_mockCourses.length}', 'Cours', _orange),
        ]),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _Stat(this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(children: [
      Text(value, style: TextStyle(
          color: color, fontSize: 16, fontWeight: FontWeight.w900)),
      const SizedBox(height: 3),
      Text(label, textAlign: TextAlign.center,
          style: const TextStyle(color: _muted, fontSize: 10, height: 1.2)),
    ]),
  );
}

class _Div extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, color: _border, margin: const EdgeInsets.symmetric(vertical: 6));
}

// ── Bio section ───────────────────────────────────────────────────────────
class _BioSection extends StatelessWidget {
  final String school;
  final String classe;
  const _BioSection({required this.school, required this.classe});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Bio text
      RichText(text: TextSpan(children: [
        const TextSpan(text: 'Élève en ',
            style: TextStyle(color: _muted, fontSize: 13)),
        TextSpan(text: classe,
            style: const TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w700)),
        const TextSpan(text: ' · ',
            style: TextStyle(color: _muted, fontSize: 13)),
        TextSpan(text: school,
            style: const TextStyle(color: _muted, fontSize: 13)),
      ])),
      const SizedBox(height: 4),
      Row(children: [
        const Icon(Icons.calendar_today_outlined, size: 12, color: _muted),
        const SizedBox(width: 4),
        Text('Inscrit depuis $_mockSince',
            style: const TextStyle(color: _muted, fontSize: 12)),
      ]),
      const SizedBox(height: 14),
      // Action buttons
      Row(children: [
        Expanded(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.edit_outlined, size: 15, color: _ink),
                SizedBox(width: 6),
                Text('Modifier profil', style: TextStyle(
                    color: _ink, fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {},
          child: Container(
            height: 38, width: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: const Icon(Icons.share_outlined, size: 18, color: _ink),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {},
          child: Container(
            height: 38, width: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: const Icon(Icons.qr_code_rounded, size: 18, color: _ink),
          ),
        ),
      ]),
    ]);
  }
}

// ── Tab bar delegate ──────────────────────────────────────────────────────
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabController controller;
  final int index;
  const _TabBarDelegate(this.controller, this.index);

  @override
  double get minExtent => 48;
  @override
  double get maxExtent => 48;

  @override
  Widget build(BuildContext ctx, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: _bg,
      child: Column(children: [
        Container(height: 1, color: _border.withOpacity(.5)),
        Expanded(
          child: TabBar(
            controller: controller,
            labelColor: _terra,
            unselectedLabelColor: _muted,
            indicatorColor: _terra,
            indicatorWeight: 2.5,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            tabs: const [
              Tab(text: 'Tout'),
              Tab(text: 'Contact'),
              Tab(text: 'Académique'),
            ],
          ),
        ),
      ]),
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate old) => old.index != index;
}

// ══════════════════════════════════════════════════════════════════════════
// TAB — Tout
// ══════════════════════════════════════════════════════════════════════════
class _TabTout extends StatelessWidget {
  final String email;
  final String role;
  const _TabTout({required this.email, required this.role});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // Contact info summary
        _SectionTitle('Contact', Icons.contact_mail_outlined, _terra),
        const SizedBox(height: 8),
        _InfoTile(
          icon: Icons.mail_outline_rounded, color: _terra,
          label: 'Email', value: email, locked: false,
          onEdit: () => _showEditSheet(context, 'email', email),
        ),
        const SizedBox(height: 6),
        _InfoTile(
          icon: Icons.phone_outlined, color: _orange,
          label: 'Téléphone', value: _mockPhone, locked: false,
          onEdit: () => _showEditSheet(context, 'téléphone', _mockPhone),
        ),
        const SizedBox(height: 18),

        // School info
        _SectionTitle('Établissement', Icons.school_outlined, _gold),
        const SizedBox(height: 8),
        _InfoTile(icon: Icons.badge_outlined,       color: _gold,
            label: 'ID étudiant',  value: _mockId, locked: true),
        const SizedBox(height: 6),
        _InfoTile(icon: Icons.class_outlined,        color: _green,
            label: 'Classe',       value: _mockClass, locked: true),
        const SizedBox(height: 6),
        _InfoTile(icon: Icons.school_outlined,       color: _muted,
            label: 'École',        value: _mockSchool, locked: true),
        const SizedBox(height: 18),

        // Top 3 courses
        _SectionTitle('Mes matières', Icons.menu_book_outlined, _green),
        const SizedBox(height: 8),
        for (final c in _mockCourses.take(3))
          _CourseRow(course: c, showGrade: true),
        GestureDetector(
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('Voir toutes les matières', style: TextStyle(
                  color: _terra, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: _terra, size: 16),
            ]),
          ),
        ),
      ],
    );
  }

  void _showEditSheet(BuildContext context, String field, String current) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _EditSheet(field: field, current: current),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// TAB — Contact
// ══════════════════════════════════════════════════════════════════════════
class _TabContact extends StatelessWidget {
  final String email;
  const _TabContact({required this.email});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _SectionTitle('Informations modifiables', Icons.edit_outlined, _terra),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _terra.withOpacity(.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _terra.withOpacity(.2)),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded, size: 14, color: _terra),
            const SizedBox(width: 8),
            Expanded(child: Text(
                'Seuls l\'email et le téléphone peuvent être modifiés. '
                'Les autres informations sont gérées par l\'administration.',
                style: TextStyle(color: _terra.withOpacity(.8), fontSize: 11.5, height: 1.4))),
          ]),
        ),
        const SizedBox(height: 12),
        _InfoTile(
          icon: Icons.mail_outline_rounded, color: _terra,
          label: 'Adresse email', value: email, locked: false,
          onEdit: () => _showEditSheet(context, 'email', email),
        ),
        const SizedBox(height: 8),
        _InfoTile(
          icon: Icons.phone_outlined, color: _orange,
          label: 'Numéro de téléphone', value: _mockPhone, locked: false,
          onEdit: () => _showEditSheet(context, 'téléphone', _mockPhone),
        ),

        const SizedBox(height: 24),
        _SectionTitle('Informations fixes', Icons.lock_outline_rounded, _muted),
        const SizedBox(height: 12),
        _InfoTile(icon: Icons.badge_outlined,   color: _gold,
            label: 'ID étudiant', value: _mockId, locked: true),
        const SizedBox(height: 8),
        _InfoTile(icon: Icons.class_outlined,    color: _green,
            label: 'Classe', value: _mockClass, locked: true),
        const SizedBox(height: 8),
        _InfoTile(icon: Icons.school_outlined,   color: _muted,
            label: 'Établissement', value: _mockSchool, locked: true),
        const SizedBox(height: 8),
        _InfoTile(icon: Icons.calendar_today_outlined, color: _muted,
            label: 'Inscrit depuis', value: _mockSince, locked: true),
      ],
    );
  }

  void _showEditSheet(BuildContext context, String field, String current) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _EditSheet(field: field, current: current),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// TAB — Académique
// ══════════════════════════════════════════════════════════════════════════
class _TabAcademique extends StatelessWidget {
  final String role;
  const _TabAcademique({required this.role});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // Summary banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A0A00), _terra],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Année scolaire 2024 – 2025',
                  style: TextStyle(color: Colors.white70, fontSize: 11)),
              const SizedBox(height: 4),
              const Text('Terminale S3',
                  style: TextStyle(color: Colors.white, fontSize: 16,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(_mockSchool, style: const TextStyle(color: Colors.white60, fontSize: 11)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Text('Moyenne générale', style: TextStyle(color: Colors.white60, fontSize: 10)),
              Text('$_mockAvg /20', style: const TextStyle(
                  color: _gold, fontSize: 26, fontWeight: FontWeight.w900)),
              Text('Rang : $_mockRank / $_mockTotal',
                  style: const TextStyle(color: Colors.white54, fontSize: 10)),
            ]),
          ]),
        ),
        const SizedBox(height: 18),

        // Course list
        _SectionTitle('Bulletins de notes', Icons.grade_outlined, _terra),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Column(
            children: List.generate(_mockCourses.length, (i) => Column(children: [
              _CourseRow(course: _mockCourses[i], showGrade: true, showTeacher: true),
              if (i < _mockCourses.length - 1)
                Divider(height: 1, indent: 60, color: _border.withOpacity(.5)),
            ])),
          ),
        ),
        const SizedBox(height: 18),

        // Attendance
        _SectionTitle('Assiduité', Icons.check_circle_outline_rounded, _green),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Column(children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Taux de présence', style: TextStyle(
                    color: _ink, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('Trimestre en cours — 2024-2025',
                    style: const TextStyle(color: _muted, fontSize: 11)),
              ])),
              Text('$_mockPresence%', style: const TextStyle(
                  color: _green, fontSize: 26, fontWeight: FontWeight.w900)),
            ]),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _mockPresence / 100,
                minHeight: 8,
                backgroundColor: _green.withOpacity(.1),
                valueColor: const AlwaysStoppedAnimation<Color>(_green),
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              _AttBadge('Présent', '86 j', _green),
              const SizedBox(width: 8),
              _AttBadge('Absent', '4 j', _terra),
              const SizedBox(width: 8),
              _AttBadge('Retard', '2 j', _gold),
            ]),
          ]),
        ),
      ],
    );
  }
}

class _AttBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _AttBadge(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(.2)),
      ),
      child: Row(children: [
        Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(width: 4),
        Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  const _SectionTitle(this.text, this.icon, this.color);
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 15, color: color),
      const SizedBox(width: 8),
      Text(text, style: TextStyle(
          color: color, fontSize: 13, fontWeight: FontWeight.w800)),
    ]);
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final bool locked;
  final VoidCallback? onEdit;
  const _InfoTile({
    required this.icon, required this.color,
    required this.label, required this.value,
    required this.locked, this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(.1),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 17, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: _muted, fontSize: 10.5)),
            const SizedBox(height: 1),
            Text(value, style: const TextStyle(
                color: _ink, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        )),
        // Pencil ONLY for editable fields (email/phone)
        if (!locked && onEdit != null)
          GestureDetector(
            onTap: onEdit,
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: _terra.withOpacity(.07),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _terra.withOpacity(.2)),
              ),
              child: const Icon(Icons.edit_rounded, size: 14, color: _terra),
            ),
          )
        else if (locked)
          const Icon(Icons.lock_outline_rounded, size: 14, color: _muted),
      ]),
    );
  }
}

class _CourseRow extends StatelessWidget {
  final Map<String, dynamic> course;
  final bool showGrade;
  final bool showTeacher;
  const _CourseRow({
    required this.course,
    this.showGrade = false,
    this.showTeacher = false,
  });

  Color _gradeColor(double g) {
    if (g >= 16) return _green;
    if (g >= 12) return _gold;
    return _terra;
  }

  @override
  Widget build(BuildContext context) {
    final grade = (course['grade'] as num).toDouble();
    final coef  = course['coef'] as int;
    final color = _gradeColor(grade);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: color.withOpacity(.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.menu_book_outlined, size: 17, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(course['name'] as String, style: const TextStyle(
              color: _ink, fontSize: 13, fontWeight: FontWeight.w600)),
          if (showTeacher)
            Text(course['teacher'] as String, style: const TextStyle(
                color: _muted, fontSize: 11)),
        ])),
        if (showGrade) ...[
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${grade.toStringAsFixed(1)}', style: TextStyle(
                color: color, fontSize: 15, fontWeight: FontWeight.w900)),
            Text('coef $coef', style: const TextStyle(
                color: _muted, fontSize: 9)),
          ]),
        ],
      ]),
    );
  }
}

// ── Edit bottom sheet ─────────────────────────────────────────────────────
class _EditSheet extends StatefulWidget {
  final String field;
  final String current;
  const _EditSheet({required this.field, required this.current});
  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final TextEditingController _ctrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.current);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _save() async {
    setState(() => _saving = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
          left: 20, right: 20, top: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('Modifier ${widget.field}', style: const TextStyle(
                color: _ink, fontSize: 16, fontWeight: FontWeight.w800)),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.close_rounded, color: _muted, size: 20)),
          ]),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: widget.field == 'email'
                ? TextInputType.emailAddress
                : TextInputType.phone,
            decoration: InputDecoration(
              labelText: widget.field == 'email' ? 'Nouvelle adresse email' : 'Nouveau numéro',
              labelStyle: const TextStyle(color: _muted, fontSize: 13),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _terra, width: 2),
              ),
              filled: true,
              fillColor: const Color(0xFFF5EEE6),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _terra,
                foregroundColor: _white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Enregistrer', style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ── African pattern painter ───────────────────────────────────────────────
class _AfricanPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p1 = Paint()
      ..color = Colors.white.withOpacity(.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (int i = 0; i < 7; i++) {
      canvas.drawCircle(
          Offset(size.width * 0.85, size.height * 0.5), 28.0 + i * 22, p1);
    }
    final p2 = Paint()
      ..color = ScolarisPalette.gold.withOpacity(.07)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < 6; i++) {
      canvas.drawCircle(Offset(size.width * 0.08 + i * 38, size.height * 0.25), 7, p2);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
