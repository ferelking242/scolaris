import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/user_entity.dart';
import '../../presentation/providers/auth_providers.dart';
import '../../presentation/providers/db_providers.dart';
import '../data/features_catalog.dart';
import '../widgets/plan_gate.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _terra  = ScolarisPalette.terracotta;
const _orange = ScolarisPalette.orange;
const _gold   = ScolarisPalette.gold;
const _green  = ScolarisPalette.forestGreen;
const _ink    = Color(0xFF1A0A00);
const _muted  = Color(0xFF7A5C44);
const _border = Color(0xFFDDCCBB);
const _white  = Colors.white;
const _bg     = Color(0xFFF5EEE6);
const _sh1    = Color(0xFF1A0A00);
const _sh2    = Color(0xFF3E1A00);

// ─────────────────────────────────────────────────────────────────────────────
class FeaturesHubPage extends ConsumerStatefulWidget {
  const FeaturesHubPage({super.key});
  @override
  ConsumerState<FeaturesHubPage> createState() => _FeaturesHubPageState();
}

class _FeaturesHubPageState extends ConsumerState<FeaturesHubPage> {
  /// Override manuel du niveau (écoles multi-cycles). Null → niveau dynamique
  /// déduit de la classe de l'élève / du type d'école.
  SchoolLevel? _levelOverride;
  FeatureStatus? _filterStatus;
  FeatureCategory? _filterCat;
  final Set<String> _closedCats = {};

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authSessionProvider);
    final role = user?.role ?? UserRole.student;
    final isAdmin = role == UserRole.staff;
    final planCode = ref.watch(currentPlanCodeProvider).valueOrNull;

    // Niveau dynamique (type d'école / classe) + niveaux réellement offerts.
    final dynLevel = ref.watch(studentSchoolLevelProvider).valueOrNull
        ?? SchoolLevel.lycee;
    final schoolLevels = ref.watch(schoolLevelsProvider).valueOrNull
        ?? const <SchoolLevel>[];
    final level = _levelOverride ?? dynLevel;
    // Sélecteur affiché seulement si l'école couvre plusieurs niveaux.
    final canSwitchLevel = role == UserRole.student && schoolLevels.length > 1;

    final raw = isAdmin
        ? FeaturesCatalog.all
        : FeaturesCatalog.forRole(role, role == UserRole.student ? level : null);

    final filtered = raw.where((f) {
      if (_filterStatus != null && f.status != _filterStatus) return false;
      if (_filterCat != null && f.category != _filterCat) return false;
      return true;
    }).toList();

    final cats = FeaturesCatalog.categoriesIn(filtered);

    final availableCount = raw.where((f) => f.status == FeatureStatus.available).length;
    final plannedCount   = raw.where((f) => f.status == FeatureStatus.planned).length;
    final betaCount      = raw.where((f) => f.status == FeatureStatus.beta).length;

    return Container(
      color: _bg,
      child: CustomScrollView(
        slivers: [

          // ── Hero header ───────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _HeroHeader(
              role: role,
              level: level,
              availableLevels: schoolLevels,
              total: raw.length,
              availableCount: availableCount,
              plannedCount: plannedCount,
              betaCount: betaCount,
              onLevelChange: canSwitchLevel
                  ? (l) => setState(() => _levelOverride = l)
                  : null,
            ),
          ),

          // ── Filter chips ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _FilterBar(
              filterStatus: _filterStatus,
              filterCat: _filterCat,
              onStatusFilter: (s) => setState(() =>
                  _filterStatus = _filterStatus == s ? null : s),
              onCatFilter: (c) => setState(() =>
                  _filterCat = _filterCat == c ? null : c),
              availableCats: FeaturesCatalog.categoriesIn(raw),
            ),
          ),

          // ── Empty state ──────────────────────────────────────────────────
          if (filtered.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        color: _terra.withOpacity(.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.search_off_rounded,
                          color: _terra, size: 32),
                    ),
                    const SizedBox(height: 14),
                    const Text('Aucune fonctionnalité',
                        style: TextStyle(color: _ink, fontSize: 16,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text('Essayez un autre filtre',
                        style: TextStyle(color: _muted, fontSize: 13)),
                  ],
                ),
              ),
            )
          else ...[
            // ── Category sections ─────────────────────────────────────────
            for (final cat in cats) ...[
              SliverToBoxAdapter(
                child: _CatHeader(
                  cat: cat,
                  count: filtered.where((f) => f.category == cat).length,
                  closed: _closedCats.contains(cat.name),
                  onTap: () => setState(() {
                    if (_closedCats.contains(cat.name)) {
                      _closedCats.remove(cat.name);
                    } else {
                      _closedCats.add(cat.name);
                    }
                  }),
                ),
              ),
              if (!_closedCats.contains(cat.name))
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 320,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 2.0,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final features =
                            filtered.where((f) => f.category == cat).toList();
                        return _FeatureCard(
                          feature: features[i],
                          showRoleBadges: isAdmin,
                          userRole: role,
                          level: role == UserRole.student ? level : null,
                          planCode: planCode,
                        );
                      },
                      childCount: filtered
                          .where((f) => f.category == cat)
                          .length,
                    ),
                  ),
                ),
            ],

            const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero Header
// ─────────────────────────────────────────────────────────────────────────────
class _HeroHeader extends StatelessWidget {
  final UserRole role;
  final SchoolLevel level;
  final List<SchoolLevel> availableLevels;
  final int total;
  final int availableCount;
  final int plannedCount;
  final int betaCount;
  final ValueChanged<SchoolLevel>? onLevelChange;

  const _HeroHeader({
    required this.role,
    required this.level,
    required this.availableLevels,
    required this.total,
    required this.availableCount,
    required this.plannedCount,
    required this.betaCount,
    this.onLevelChange,
  });

  String get _roleLabel {
    switch (role) {
      case UserRole.staff:    return 'Administrateur';
      case UserRole.teacher:  return 'Enseignant';
      case UserRole.student:  return 'Élève';
      case UserRole.parent:   return 'Parent';
    }
  }

  String get _roleDesc {
    switch (role) {
      case UserRole.staff:
        return 'Accès complet — toutes les fonctionnalités de l\'application';
      case UserRole.teacher:
        return 'Outils pédagogiques, suivi des élèves et communication';
      case UserRole.student:
        return 'Fonctionnalités disponibles pour le niveau ${level.label} (${level.range})';
      case UserRole.parent:
        return 'Suivi de vos enfants, paiements et communication avec l\'école';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_sh1, _sh2, Color(0xFF5A1A00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _sh1.withOpacity(.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: CustomPaint(painter: _HexPainter()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Role badge + title
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _terra.withOpacity(.3),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _terra.withOpacity(.5)),
                    ),
                    child: Text(_roleLabel.toUpperCase(),
                        style: const TextStyle(
                            color: _white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8)),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.auto_awesome_rounded,
                      size: 14, color: Color(0xFFC17F24)),
                ]),
                const SizedBox(height: 10),
                const Text('Fonctionnalités',
                    style: TextStyle(
                        color: _white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(_roleDesc,
                    style: TextStyle(
                        color: _white.withOpacity(.6),
                        fontSize: 12.5,
                        height: 1.4)),
                const SizedBox(height: 16),

                // Stats row
                Row(children: [
                  _StatPill(
                      value: availableCount.toString(),
                      label: 'Disponibles',
                      color: _green),
                  const SizedBox(width: 8),
                  if (betaCount > 0) ...[
                    _StatPill(
                        value: betaCount.toString(),
                        label: 'Bêta',
                        color: _gold),
                    const SizedBox(width: 8),
                  ],
                  _StatPill(
                      value: plannedCount.toString(),
                      label: 'À venir',
                      color: _muted),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _white.withOpacity(.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('$total modules',
                        style: const TextStyle(
                            color: _white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ),
                ]),

                // Level selector (student only)
                if (onLevelChange != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    height: 1, color: _white.withOpacity(.1)),
                  const SizedBox(height: 12),
                  const Text('NIVEAU SCOLAIRE',
                      style: TextStyle(
                          color: Color(0xFFC17F24),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: availableLevels.map((l) {
                        final sel = l == level;
                        return GestureDetector(
                          onTap: () => onLevelChange!(l),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: sel
                                  ? _terra
                                  : _white.withOpacity(.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: sel
                                      ? _terra
                                      : _white.withOpacity(.15)),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(l.label,
                                    style: TextStyle(
                                        color: sel
                                            ? _white
                                            : _white.withOpacity(.7),
                                        fontSize: 12,
                                        fontWeight: sel
                                            ? FontWeight.w700
                                            : FontWeight.w500)),
                                Text(l.range,
                                    style: TextStyle(
                                        color: sel
                                            ? _white.withOpacity(.8)
                                            : _white.withOpacity(.4),
                                        fontSize: 9)),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _StatPill(
      {required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 6, height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text('$value $label',
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter Bar
// ─────────────────────────────────────────────────────────────────────────────
class _FilterBar extends StatelessWidget {
  final FeatureStatus? filterStatus;
  final FeatureCategory? filterCat;
  final ValueChanged<FeatureStatus> onStatusFilter;
  final ValueChanged<FeatureCategory> onCatFilter;
  final List<FeatureCategory> availableCats;

  const _FilterBar({
    required this.filterStatus,
    required this.filterCat,
    required this.onStatusFilter,
    required this.onCatFilter,
    required this.availableCats,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status filters
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _FilterChip(
                label: 'Disponibles',
                color: _green,
                active: filterStatus == FeatureStatus.available,
                onTap: () => onStatusFilter(FeatureStatus.available),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'À venir',
                color: _muted,
                active: filterStatus == FeatureStatus.planned,
                onTap: () => onStatusFilter(FeatureStatus.planned),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Bêta',
                color: _gold,
                active: filterStatus == FeatureStatus.beta,
                onTap: () => onStatusFilter(FeatureStatus.beta),
              ),
            ]),
          ),
        ),
        // Category filters
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: availableCats.map((cat) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _FilterChip(
                    label: cat.label,
                    color: _terra,
                    active: filterCat == cat,
                    onTap: () => onCatFilter(cat),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.color,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color : _white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? color : _border),
          boxShadow: active
              ? [
                  BoxShadow(
                      color: color.withOpacity(.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ]
              : [],
        ),
        child: Text(label,
            style: TextStyle(
                color: active ? _white : _muted,
                fontSize: 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Category Header
// ─────────────────────────────────────────────────────────────────────────────
class _CatHeader extends StatelessWidget {
  final FeatureCategory cat;
  final int count;
  final bool closed;
  final VoidCallback onTap;

  const _CatHeader({
    required this.cat,
    required this.count,
    required this.closed,
    required this.onTap,
  });

  static const _catIcons = {
    FeatureCategory.core:          Icons.star_rounded,
    FeatureCategory.academic:      Icons.school_rounded,
    FeatureCategory.communication: Icons.chat_bubble_rounded,
    FeatureCategory.finance:       Icons.account_balance_wallet_rounded,
    FeatureCategory.documents:     Icons.folder_rounded,
    FeatureCategory.admin:         Icons.admin_panel_settings_rounded,
    FeatureCategory.research:      Icons.science_rounded,
  };

  static const _catColors = {
    FeatureCategory.core:          Color(0xFF8B1A00),
    FeatureCategory.academic:      Color(0xFFD4540A),
    FeatureCategory.communication: Color(0xFF2D6A4F),
    FeatureCategory.finance:       Color(0xFFC17F24),
    FeatureCategory.documents:     Color(0xFF7A5C44),
    FeatureCategory.admin:         Color(0xFF8B1A00),
    FeatureCategory.research:      Color(0xFF2D6A4F),
  };

  @override
  Widget build(BuildContext context) {
    final color = _catColors[cat] ?? _terra;
    final icon  = _catIcons[cat] ?? Icons.apps_rounded;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 10),
          Text(cat.label.toUpperCase(),
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$count',
                style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w800)),
          ),
          const Spacer(),
          Icon(
            closed ? Icons.expand_more_rounded : Icons.expand_less_rounded,
            size: 18, color: _muted.withOpacity(.5),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Feature Card
// ─────────────────────────────────────────────────────────────────────────────
class _FeatureCard extends StatefulWidget {
  final AppFeature feature;
  final bool showRoleBadges;
  final UserRole userRole;
  final SchoolLevel? level;
  final String? planCode;

  const _FeatureCard({
    required this.feature,
    required this.showRoleBadges,
    required this.userRole,
    this.level,
    this.planCode,
  });

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _hover = false;

  Color get _statusColor {
    switch (widget.feature.status) {
      case FeatureStatus.available: return _green;
      case FeatureStatus.beta:      return _gold;
      case FeatureStatus.planned:   return _muted;
    }
  }

  String get _statusLabel {
    switch (widget.feature.status) {
      case FeatureStatus.available: return 'Disponible';
      case FeatureStatus.beta:      return 'Bêta';
      case FeatureStatus.planned:   return 'À venir';
    }
  }

  IconData get _statusIcon {
    switch (widget.feature.status) {
      case FeatureStatus.available: return Icons.check_circle_rounded;
      case FeatureStatus.beta:      return Icons.science_rounded;
      case FeatureStatus.planned:   return Icons.schedule_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.feature;
    final planLocked = !planMeetsRequirement(widget.planCode, f.minPlan);
    // Verrouillée par l'offre OU pas encore disponible → présentation atténuée.
    final isAvailable = f.status == FeatureStatus.available && !planLocked;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _hover
                ? f.color.withOpacity(.3)
                : _border.withOpacity(.6),
          ),
          boxShadow: _hover
              ? [
                  BoxShadow(
                    color: f.color.withOpacity(.1),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  )
                ]
              : [
                  const BoxShadow(
                    color: Color(0x08000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  )
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon + status
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: isAvailable
                          ? f.color.withOpacity(.12)
                          : _muted.withOpacity(.07),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(f.icon,
                        size: 20,
                        color: isAvailable
                            ? f.color
                            : _muted.withOpacity(.5)),
                  ),
                  const Spacer(),
                  if (planLocked) ...[
                    _PlanLockBadge(plan: f.minPlan),
                    const SizedBox(width: 5),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: _statusColor.withOpacity(.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: _statusColor.withOpacity(.25)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(_statusIcon, size: 9, color: _statusColor),
                      const SizedBox(width: 4),
                      Text(_statusLabel,
                          style: TextStyle(
                              fontSize: 9,
                              color: _statusColor,
                              fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Title
              Text(f.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: isAvailable ? _ink : _ink.withOpacity(.5),
                      fontSize: 13,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),

              // Description
              Expanded(
                child: Text(f.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: isAvailable
                            ? _muted
                            : _muted.withOpacity(.5),
                        fontSize: 11,
                        height: 1.4)),
              ),

              // Role badges (admin view only)
              if (widget.showRoleBadges) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: f.roles.map((r) => _RoleBadge(role: r)).toList(),
                ),
              ],

              // Level badges (if applicable)
              if (f.levels != null &&
                  f.levels!.length < SchoolLevel.values.length) ...[
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: f.levels!.map((l) => Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: f.color.withOpacity(.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(l.label,
                            style: TextStyle(
                                color: f.color.withOpacity(.8),
                                fontSize: 9,
                                fontWeight: FontWeight.w600)),
                      ),
                    )).toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Badge « 🔒 Pro » / « 🔒 Max » affiché quand l'offre courante ne couvre pas
/// la feature. Distinct du badge de statut (« À venir » = maturité du code).
class _PlanLockBadge extends StatelessWidget {
  final String plan;
  const _PlanLockBadge({required this.plan});

  static const _colors = {'pro': Color(0xFF0E7490), 'max': Color(0xFF7C3AED)};
  static const _labels = {'pro': 'Pro', 'max': 'Max'};

  @override
  Widget build(BuildContext context) {
    final c = _colors[plan] ?? _terra;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withOpacity(.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.lock_rounded, size: 9, color: c),
        const SizedBox(width: 3),
        Text(_labels[plan] ?? plan,
            style: TextStyle(fontSize: 9, color: c, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final UserRole role;
  const _RoleBadge({required this.role});

  static const _colors = {
    UserRole.staff:   Color(0xFF8B1A00),
    UserRole.teacher: Color(0xFF2D6A4F),
    UserRole.student: Color(0xFFD4540A),
    UserRole.parent:  Color(0xFFC17F24),
  };

  static const _labels = {
    UserRole.staff:   'Admin',
    UserRole.teacher: 'Prof',
    UserRole.student: 'Élève',
    UserRole.parent:  'Parent',
  };

  @override
  Widget build(BuildContext context) {
    final c = _colors[role] ?? _muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: c.withOpacity(.1),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: c.withOpacity(.25)),
      ),
      child: Text(_labels[role] ?? '',
          style: TextStyle(
              color: c, fontSize: 8.5, fontWeight: FontWeight.w700)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hex pattern painter
// ─────────────────────────────────────────────────────────────────────────────
class _HexPainter extends CustomPainter {
  final double opacity;
  const _HexPainter({this.opacity = 0.04});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Color.fromRGBO(255, 255, 255, opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;
    const r = 20.0;
    final dx = r * math.sqrt(3);
    final dy = r * 1.5;
    for (double y = -r; y < size.height + r * 2; y += dy) {
      for (double x = -dx; x < size.width + dx; x += dx) {
        final off = ((y / dy).floor() % 2 == 0) ? 0.0 : dx / 2;
        final path = Path();
        for (int i = 0; i < 6; i++) {
          final a = math.pi / 180 * (60 * i - 30);
          final p = Offset(x + off + r * math.cos(a), y + r * math.sin(a));
          i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
        }
        path.close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HexPainter old) => old.opacity != opacity;
}
