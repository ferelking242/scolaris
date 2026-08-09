import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../presentation/providers/nav_providers.dart';
import '../../../../shared/data/features_catalog.dart' show AppModule, kAppModules, kCoreModule;
import '../../../../shared/widgets/page_scaffold.dart';

/// Catalogue des modules — écran dédié, retiré de « Mon abonnement »
/// (décision du 09/08/2026, cf. conversation business plan : les modules
/// méritent leur propre écran « app store », avec une vraie installation
/// animée, pas un panneau perdu au milieu de la facturation).
///
/// Académique reste un socle toujours actif (jamais installé/désinstallé
/// depuis ici). Les modules complémentaires (Finances/Présences/Inscriptions)
/// s'installent/se désinstallent un par un, dans la limite du quota
/// d'emplacements de l'offre en cours (`plans.max_modules` +
/// `subscriptions.extra_module_slots`).
class AdminModulesPage extends ConsumerWidget {
  const AdminModulesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subAsync = ref.watch(subscriptionProvider);
    final plansAsync = ref.watch(plansProvider);
    final schoolAsync = ref.watch(schoolProvider);

    Future<void> refresh() async {
      ref.invalidate(subscriptionProvider);
      ref.invalidate(plansProvider);
      ref.invalidate(schoolProvider);
      await Future.wait([
        ref.read(subscriptionProvider.future),
        ref.read(plansProvider.future),
        ref.read(schoolProvider.future),
      ]);
    }

    final loading = subAsync.isLoading || plansAsync.isLoading || schoolAsync.isLoading;
    if (loading) {
      return PageScaffold(
        title: 'Modules',
        onRefresh: refresh,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (subAsync.hasError) {
      return PageScaffold(
        title: 'Modules',
        onRefresh: refresh,
        child: Center(child: Text('Erreur : ${subAsync.error}')),
      );
    }

    final sub = subAsync.value;
    final plans = plansAsync.value ?? const <SbPlan>[];
    final school = schoolAsync.value;
    final currentPlan = plans.where((p) => p.code == sub?.planCode).firstOrNull;
    final planName = currentPlan?.name ?? sub?.planCode?.toUpperCase() ?? '—';
    final quota = (currentPlan?.maxModules ?? 0) + (sub?.extraModuleSlots ?? 0);

    return PageScaffold(
      title: 'Modules',
      subtitle: 'Installez les modules complémentaires inclus dans votre offre',
      onRefresh: refresh,
      child: _ModulesBody(quota: quota, planName: planName, school: school),
    );
  }
}

enum _TileAnim { idle, installing, justInstalled, removing }

class _ModulesBody extends ConsumerStatefulWidget {
  final int quota;
  final String planName;
  final SbSchool? school;
  const _ModulesBody({required this.quota, required this.planName, required this.school});

  @override
  ConsumerState<_ModulesBody> createState() => _ModulesBodyState();
}

class _ModulesBodyState extends ConsumerState<_ModulesBody> {
  final Map<String, _TileAnim> _anim = {};

  Future<void> _toggle(String moduleId, bool install, Set<String> saved) async {
    final schoolId = widget.school?.id;
    if (schoolId == null) return;
    setState(() => _anim[moduleId] = install ? _TileAnim.installing : _TileAnim.removing);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final next = Set<String>.from(saved);
      if (install) { next.add(moduleId); } else { next.remove(moduleId); }
      next.add('academic'); // socle toujours actif — conservé en base pour compat élève/prof/parent

      // Délai minimum pour un vrai effet « installation » : la requête seule
      // est souvent trop rapide pour se voir, ce qui rendrait l'action peu
      // crédible (« ça a vraiment fait quelque chose ? »).
      await Future.wait([
        SupabaseDbSource.updateSchoolModules(schoolId, next.toList()),
        Future.delayed(const Duration(milliseconds: 700)),
      ]);

      ref.invalidate(schoolProvider);
      if (install && mounted) {
        setState(() => _anim[moduleId] = _TileAnim.justInstalled);
        await Future.delayed(const Duration(milliseconds: 900));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('$e'),
        backgroundColor: const Color(0xFF8B1A00),
      ));
    } finally {
      if (mounted) setState(() => _anim.remove(moduleId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final school = widget.school;
    final saved = (school?.modules.isNotEmpty ?? false) ? school!.modules.toSet() : kAppModules.map((m) => m.id).toSet();
    final installed = saved.where((m) => m != 'academic').toSet();
    final used = installed.length;
    final quota = widget.quota;
    final atQuota = used >= quota;

    return Column(children: [
      // ── Bandeau quota ──────────────────────────────────────────────────
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFF0E7490).withValues(alpha: .12), const Color(0xFF0E7490).withValues(alpha: .03)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF0E7490).withValues(alpha: .25)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFF0E7490).withValues(alpha: .15), shape: BoxShape.circle),
            child: const Icon(Icons.widgets_rounded, color: Color(0xFF0E7490), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Offre ${widget.planName}',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.cInk)),
              const SizedBox(height: 3),
              Text(
                quota == 0
                    ? 'Aucun emplacement de module complémentaire inclus'
                    : '$used sur $quota emplacement${quota > 1 ? "s" : ""} de module complémentaire utilisé${used > 1 ? "s" : ""}',
                style: TextStyle(fontSize: 12.5, color: context.cMuted),
              ),
              if (quota > 0) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (used / quota).clamp(0.0, 1.0),
                    minHeight: 7,
                    backgroundColor: context.cSubtle,
                    valueColor: AlwaysStoppedAnimation(
                        atQuota ? const Color(0xFFC17F24) : const Color(0xFF0E7490)),
                  ),
                ),
              ],
            ]),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => ref.read(navIntentProvider.notifier).state = 'nav.subscription',
            style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF0E7490))),
            child: const Text('Voir les offres', style: TextStyle(color: Color(0xFF0E7490), fontSize: 12.5)),
          ),
        ]),
      ),
      const SizedBox(height: 16),

      // ── Académique — socle toujours actif ───────────────────────────────
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF15803D).withValues(alpha: .06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF15803D).withValues(alpha: .3), width: 1.5),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF15803D).withValues(alpha: .15), borderRadius: BorderRadius.circular(12)),
            child: Icon(kCoreModule.icon, size: 26, color: const Color(0xFF15803D)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(kCoreModule.label, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: context.cInk)),
              const SizedBox(height: 2),
              Text(kCoreModule.description, style: TextStyle(fontSize: 12, color: context.cMuted)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFF15803D).withValues(alpha: .15), borderRadius: BorderRadius.circular(8)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF15803D)),
              SizedBox(width: 5),
              Text('Toujours actif', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF15803D))),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 18),

      Align(
        alignment: Alignment.centerLeft,
        child: Text('Modules complémentaires',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: context.cInk)),
      ),
      const SizedBox(height: 10),

      // ── Grille des modules complémentaires ──────────────────────────────
      LayoutBuilder(builder: (ctx, c) {
        final cols = c.maxWidth > 720 ? 3 : c.maxWidth > 460 ? 2 : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: cols == 1 ? 2.6 : 1.15,
          ),
          itemCount: kAppModules.length,
          itemBuilder: (_, i) {
            final m = kAppModules[i];
            final isInstalled = installed.contains(m.id);
            return _ModuleCard(
              module: m,
              installed: isInstalled,
              anim: _anim[m.id] ?? _TileAnim.idle,
              blocked: !isInstalled && atQuota,
              onInstall: school == null ? null : () => _toggle(m.id, true, saved),
              onRemove: school == null ? null : () => _toggle(m.id, false, saved),
            );
          },
        );
      }),

      if (atQuota) ...[
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFC17F24).withValues(alpha: .10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFC17F24).withValues(alpha: .3)),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFFC17F24)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Quota atteint pour votre offre ${widget.planName}. Retirez un module, achetez un '
                'emplacement à la carte, ou passez à une offre supérieure depuis « Mon abonnement ».',
                style: const TextStyle(fontSize: 12, color: Color(0xFF8A5A12), fontWeight: FontWeight.w600),
              ),
            ),
          ]),
        ),
      ],
    ]);
  }
}

/// Tuile « app store » d'un module complémentaire — installation/désinstallation
/// animée (spinner pendant l'appel réseau, flash vert « Installé ! » au succès).
class _ModuleCard extends StatelessWidget {
  final AppModule module;
  final bool installed;
  final _TileAnim anim;
  final bool blocked;
  final VoidCallback? onInstall;
  final VoidCallback? onRemove;

  const _ModuleCard({
    required this.module,
    required this.installed,
    required this.anim,
    required this.blocked,
    required this.onInstall,
    required this.onRemove,
  });

  static const _cyan = Color(0xFF0E7490);
  static const _red = Color(0xFFDC2626);
  static const _green = Color(0xFF15803D);
  static const _gold = Color(0xFFC17F24);

  @override
  Widget build(BuildContext context) {
    final busy = anim == _TileAnim.installing || anim == _TileAnim.removing;
    final justDone = anim == _TileAnim.justInstalled;
    final locked = blocked && anim == _TileAnim.idle;

    final accent = justDone
        ? _green
        : locked
            ? context.cMuted
            : installed
                ? _cyan
                : context.cMuted;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (installed || justDone) ? accent.withValues(alpha: .06) : (locked ? context.cSubtle : context.cCard),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: (installed || justDone) ? .45 : .2), width: (installed || justDone) ? 1.5 : 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: accent.withValues(alpha: .12), borderRadius: BorderRadius.circular(11)),
            child: Icon(locked ? Icons.lock_outline_rounded : module.icon, size: 22, color: accent),
          ),
          const Spacer(),
          if (justDone)
            const Icon(Icons.check_circle_rounded, color: _green, size: 22)
          else if (installed && !busy)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: _cyan.withValues(alpha: .15), borderRadius: BorderRadius.circular(6)),
              child: const Text('Installé', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _cyan)),
            ),
        ]),
        const SizedBox(height: 12),
        Text(module.label, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: context.cInk)),
        const SizedBox(height: 4),
        Expanded(
          child: Text(module.description,
              style: TextStyle(fontSize: 11.5, color: context.cMuted, height: 1.3),
              maxLines: 3, overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 36,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: anim == _TileAnim.installing
                ? _statusRow(key: const ValueKey('installing'), icon: null, label: 'Installation…', color: _cyan, spinner: true)
                : anim == _TileAnim.removing
                    ? _statusRow(key: const ValueKey('removing'), icon: null, label: 'Suppression…', color: _red, spinner: true)
                    : justDone
                        ? _statusRow(key: const ValueKey('done'), icon: Icons.check_circle_rounded, label: 'Installé !', color: _green, spinner: false)
                        : installed
                            ? OutlinedButton(
                                key: const ValueKey('remove'),
                                onPressed: onRemove,
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: _red),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                                ),
                                child: const Text('Retirer', style: TextStyle(fontSize: 12.5, color: _red, fontWeight: FontWeight.w700)),
                              )
                            : ElevatedButton(
                                key: const ValueKey('install'),
                                onPressed: locked ? null : onInstall,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: locked ? context.cBorder : _cyan,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                                ),
                                child: Text(locked ? 'Verrouillé' : 'Installer',
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700,
                                        color: locked ? context.cMuted : Colors.white)),
                              ),
          ),
        ),
        if (locked) ...[
          const SizedBox(height: 6),
          const Row(children: [
            Icon(Icons.workspace_premium_rounded, size: 12, color: _gold),
            SizedBox(width: 4),
            Expanded(
              child: Text('Offre supérieure ou emplacement à la carte requis',
                  style: TextStyle(fontSize: 10, color: _gold, fontWeight: FontWeight.w600)),
            ),
          ]),
        ],
      ]),
    );
  }

  Widget _statusRow({required Key key, required IconData? icon, required String label, required Color color, required bool spinner}) {
    return Row(key: key, mainAxisAlignment: MainAxisAlignment.center, children: [
      if (spinner)
        SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: color))
      else if (icon != null)
        Icon(icon, size: 17, color: color),
      const SizedBox(width: 8),
      Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
    ]);
  }
}
