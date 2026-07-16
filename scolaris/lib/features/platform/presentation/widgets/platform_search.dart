import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../presentation/providers/nav_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';
import '../../data/platform_mock_data.dart';
import '../platform_providers.dart';
import 'platform_widgets.dart';

/// Lanceur de recherche globale — à poser dans le slot `actions` du
/// `PageScaffold` de chaque page de la console. Ouvre une palette modale qui
/// cherche une école dans toute la plateforme et ouvre sa fiche à la sélection.
class PlatformSearchLauncher extends ConsumerWidget {
  const PlatformSearchLauncher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Pill(onTap: () => _open(context, ref));
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final picked = await showDialog<PlatformSchool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .35),
      builder: (_) => const _SearchPalette(),
    );
    if (picked == null) return;
    // Ouvre la fiche inline sur l'onglet « Écoles » (pas de route à part).
    ref.read(selectedPlatformSchoolProvider.notifier).state = picked;
    ref.read(navIntentProvider.notifier).state = 'Écoles';
  }
}

/// Pastille « Rechercher » — même langage visuel que `SearchInput`, mais bouton.
class _Pill extends StatelessWidget {
  final VoidCallback onTap;
  const _Pill({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.cCard,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.cBorder),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.search_rounded, size: 15, color: context.cMuted),
            const SizedBox(width: 7),
            Text('Rechercher',
                style: TextStyle(
                    fontSize: 12.5,
                    color: context.cMuted,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

/// Palette de recherche (modale) — champ + résultats filtrés en direct.
class _SearchPalette extends StatefulWidget {
  const _SearchPalette();
  @override
  State<_SearchPalette> createState() => _SearchPaletteState();
}

class _SearchPaletteState extends State<_SearchPalette> {
  final _controller = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<PlatformSchool> get _results {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) {
      // Sans requête : les plus récentes, pour un point de départ utile.
      return PlatformMock.recent.take(6).toList();
    }
    return PlatformMock.schools
        .where((s) =>
            s.name.toLowerCase().contains(q) ||
            s.city.toLowerCase().contains(q) ||
            s.country.toLowerCase().contains(q) ||
            s.email.toLowerCase().contains(q) ||
            s.director.toLowerCase().contains(q))
        .take(8)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return Dialog(
      backgroundColor: context.cCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 520),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Champ de recherche.
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: TextField(
              controller: _controller,
              autofocus: true,
              onChanged: (v) => setState(() => _q = v),
              style: TextStyle(fontSize: 14, color: context.cInk),
              decoration: InputDecoration(
                hintText: 'Rechercher une école, une ville, un email…',
                hintStyle: TextStyle(
                    fontSize: 13, color: context.cMuted.withValues(alpha: .7)),
                prefixIcon:
                    Icon(Icons.search_rounded, size: 18, color: context.cMuted),
                suffixIcon: _q.isEmpty
                    ? null
                    : IconButton(
                        icon: Icon(Icons.close_rounded,
                            size: 16, color: context.cMuted),
                        onPressed: () {
                          _controller.clear();
                          setState(() => _q = '');
                        },
                      ),
                isDense: true,
                filled: true,
                fillColor: context.cSubtle,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.cBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: ScolarisPalette.terracotta, width: 1.6),
                ),
              ),
            ),
          ),
          // En-tête de section.
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _q.trim().isEmpty
                    ? 'ÉCOLES RÉCENTES'
                    : '${results.length} RÉSULTAT${results.length > 1 ? 'S' : ''}',
                style: TextStyle(
                    fontSize: 9,
                    color: context.cMuted,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .6),
              ),
            ),
          ),
          // Résultats.
          Flexible(
            child: results.isEmpty
                ? const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'Aucune école',
                      description: 'Aucun résultat pour cette recherche.',
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                    itemCount: results.length,
                    separatorBuilder: (_, __) => Divider(
                        height: 1,
                        indent: 14,
                        endIndent: 14,
                        color: context.cBorder.withValues(alpha: .5)),
                    itemBuilder: (_, i) => _ResultTile(
                      school: results[i],
                      onTap: () => Navigator.pop(context, results[i]),
                    ),
                  ),
          ),
        ]),
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  final PlatformSchool school;
  final VoidCallback onTap;
  const _ResultTile({required this.school, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final s = school;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        child: Row(children: [
          Avatar(name: s.name, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: context.cInk,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 1),
              Text('${s.city}, ${s.country}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.cMuted, fontSize: 11.5)),
            ]),
          ),
          const SizedBox(width: 8),
          PlanBadge(plan: s.plan),
          const SizedBox(width: 6),
          SubStatusBadge(status: s.status),
        ]),
      ),
    );
  }
}
