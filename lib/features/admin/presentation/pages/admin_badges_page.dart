import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';

const _terra = ScolarisPalette.terracotta;
const _gold  = ScolarisPalette.gold;
const _white = Colors.white; // sur fond de marque coloré

// ══════════════════════════════════════════════════════════════════════════
// Catalogue de badges — CÔTÉ ADMIN.
//
// Les badges appartiennent à l'ÉCOLE : chacune a ses traditions (« Tableau
// d'honneur », « Grand lecteur », « Super présence »…). On ne lui impose pas
// une liste toute faite — la direction crée les siens, et les enseignants les
// décernent ensuite depuis leur espace.
//
// Sans cet écran, le prof n'a aucun badge à décerner et le carnet des élèves
// reste vide.
// ══════════════════════════════════════════════════════════════════════════
class AdminBadgesPage extends ConsumerWidget {
  const AdminBadgesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badgesAsync = ref.watch(badgeCatalogProvider);
    Future<void> refresh() async {
      ref.invalidate(badgeCatalogProvider);
      await ref.read(badgeCatalogProvider.future);
    }

    return badgesAsync.when(
      loading: () => PageScaffold(
        title: 'Badges',
        onRefresh: refresh,
        child: const Center(child: Padding(
          padding: EdgeInsets.only(top: 60),
          child: CircularProgressIndicator(),
        )),
      ),
      error: (e, _) => PageScaffold(
        title: 'Badges',
        onRefresh: refresh,
        child: Center(child: Text('Erreur : $e',
            style: TextStyle(color: context.cMuted))),
      ),
      data: (badges) => PageScaffold(
        title: 'Badges',
        onRefresh: refresh,
        subtitle: badges.isEmpty
            ? 'Aucun badge défini'
            : '${badges.length} badge(s) — décernés par les enseignants',
        actions: [
          ActionButton(
            label: 'Nouveau badge',
            icon: Icons.add_rounded,
            primary: true,
            onTap: () => _create(context, ref),
          ),
        ],
        child: badges.isEmpty
            ? const EmptyState(
                icon: Icons.emoji_events_outlined,
                title: 'Aucun badge',
                description:
                    'Créez les badges de votre école (Tableau d\'honneur, '
                    'Grand lecteur…). Les enseignants pourront ensuite les '
                    'décerner à leurs élèves.',
              )
            : LayoutBuilder(builder: (ctx, c) {
                final cols = c.maxWidth > 900 ? 3 : c.maxWidth > 600 ? 2 : 1;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: badges.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    mainAxisExtent: 92,
                  ),
                  itemBuilder: (_, i) => _BadgeRow(
                    badge: badges[i],
                    onDelete: () => _delete(context, ref, badges[i]),
                  ),
                );
              }),
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final schoolId = ref.read(currentSchoolIdProvider);
    if (schoolId == null) return;

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _BadgeDialog(schoolId: schoolId),
    );
    if (saved == true) ref.invalidate(badgeCatalogProvider);
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, SbBadge badge) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Supprimer ce badge ?'),
        content: Text('« ${badge.title} » sera retiré du catalogue — et des '
            'carnets des élèves qui l\'avaient obtenu.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Supprimer',
                  style: TextStyle(color: _terra))),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await SupabaseDbSource.deleteBadge(badge.id);
      ref.invalidate(badgeCatalogProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Suppression refusée : $e')),
      );
    }
  }
}

// ── Carte badge ───────────────────────────────────────────────────────────────
class _BadgeRow extends StatelessWidget {
  final SbBadge badge;
  final VoidCallback onDelete;
  const _BadgeRow({required this.badge, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.cBorder),
      ),
      child: Row(children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            color: _gold.withOpacity(.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: Text(badge.emoji ?? '🏅',
              style: const TextStyle(fontSize: 24))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
          Text(badge.title, style: TextStyle(
              fontSize: 13.5, fontWeight: FontWeight.w700,
              color: context.cInk),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          if (badge.description != null &&
              badge.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(badge.description!, style: TextStyle(
                fontSize: 11, color: context.cMuted, height: 1.3),
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ])),
        IconButton(
          onPressed: onDelete,
          icon: Icon(Icons.delete_outline_rounded,
              size: 18, color: context.cMuted),
          tooltip: 'Supprimer',
        ),
      ]),
    );
  }
}

// ── Création d'un badge ───────────────────────────────────────────────────────
class _BadgeDialog extends StatefulWidget {
  final String schoolId;
  const _BadgeDialog({required this.schoolId});

  @override
  State<_BadgeDialog> createState() => _BadgeDialogState();
}

class _BadgeDialogState extends State<_BadgeDialog> {
  final _title = TextEditingController();
  final _desc  = TextEditingController();
  String _emoji = '🏆';
  bool _saving = false;

  static const _emojis = [
    '🏆', '📚', '🧮', '✍️', '🌟', '🎨', '⚽', '🔬',
    '🎵', '🤝', '🧹', '🕐', '💡', '🏅',
  ];

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouveau badge'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Nom du badge',
                hintText: 'Tableau d\'honneur',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _desc,
              decoration: const InputDecoration(
                labelText: 'Comment l\'obtenir (facultatif)',
                hintText: 'Classé 1er du trimestre',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Symbole', style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w600,
                  color: context.cMuted)),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final e in _emojis)
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => setState(() => _emoji = e),
                    child: Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: _emoji == e
                            ? _gold.withOpacity(.18)
                            : context.cSubtle,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: _emoji == e ? _gold : context.cBorder,
                            width: _emoji == e ? 1.5 : 1),
                      ),
                      child: Center(
                          child: Text(e, style: const TextStyle(fontSize: 20))),
                    ),
                  ),
                ),
            ]),
          ]),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context, false),
            child: const Text('Annuler')),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
              backgroundColor: _terra, foregroundColor: _white),
          child: _saving
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: _white))
              : const Text('Créer'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Donnez un nom au badge.')),
      );
      return;
    }

    // `key` est stable et sert d'identifiant lisible (contrainte
    // unique(school_id, key)) : on le dérive du nom.
    final key = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');

    setState(() => _saving = true);
    try {
      await SupabaseDbSource.createBadge(
        schoolId: widget.schoolId,
        key: key.isEmpty ? DateTime.now().microsecondsSinceEpoch.toString() : key,
        title: title,
        description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        emoji: _emoji,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Création impossible : $e')),
      );
    }
  }
}
