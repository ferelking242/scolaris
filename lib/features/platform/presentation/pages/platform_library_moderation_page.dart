import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../shared/widgets/page_scaffold.dart';

const _terra = Color(0xFF8B1A00);

/// File de modération de la bibliothèque partagée : les 3 catalogues
/// (`bibliotheque`, `exam_subjects`, `course_materials`) sont universels
/// (pas de school_id) — un item approuvé ici devient visible par TOUTES les
/// écoles, pas seulement celle qui l'a soumis.
class PlatformLibraryModerationPage extends ConsumerStatefulWidget {
  const PlatformLibraryModerationPage({super.key});
  @override
  ConsumerState<PlatformLibraryModerationPage> createState() =>
      _PlatformLibraryModerationPageState();
}

class _PlatformLibraryModerationPageState
    extends ConsumerState<PlatformLibraryModerationPage> {
  List<SbLibrarySubmission> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await SupabaseDbSource.getPendingLibraryItems();
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approve(SbLibrarySubmission item) async {
    try {
      await SupabaseDbSource.approveLibraryItem(item.category, item.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('« ${item.title} » publié — visible par toutes les écoles.'),
      ));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur : $e'),
        backgroundColor: _terra,
      ));
    }
  }

  Future<void> _reject(SbLibrarySubmission item) async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rejeter cette soumission'),
        content: TextField(
          controller: reasonCtrl,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
              labelText: 'Motif (obligatoire)', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _terra),
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) return;
              Navigator.pop(context, reasonCtrl.text.trim());
            },
            child: const Text('Rejeter'),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;
    try {
      await SupabaseDbSource.rejectLibraryItem(item.category, item.id, reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('« ${item.title} » rejeté.'),
      ));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur : $e'),
        backgroundColor: _terra,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Modération bibliothèque',
      subtitle: '${_items.length} en attente de validation',
      child: _loading
          ? const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          : _error != null
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Erreur : $_error',
                      style: const TextStyle(color: _terra)),
                )
              : _items.isEmpty
                  ? EmptyState(
                      icon: Icons.local_library_outlined,
                      title: 'Rien à modérer',
                      description:
                          'Aucune soumission en attente pour le moment.',
                    )
                  : DataPanel(
                      title: 'En attente',
                      child: Column(
                        children: [
                          for (final item in _items)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(item.title,
                                          style: TextStyle(
                                              color: context.cInk,
                                              fontWeight: FontWeight.w700)),
                                      Text(
                                          '${item.categoryLabel} · ${item.schoolName ?? 'École inconnue'} · '
                                          '${item.createdAt != null ? DateFormat('dd/MM/yy').format(item.createdAt!) : '—'}',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: context.cMuted)),
                                    ],
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () => _reject(item),
                                  icon: const Icon(Icons.close_rounded,
                                      size: 18, color: _terra),
                                  label: const Text('Rejeter',
                                      style: TextStyle(color: _terra)),
                                ),
                                const SizedBox(width: 4),
                                ActionButton(
                                  label: 'Approuver',
                                  icon: Icons.check_rounded,
                                  primary: true,
                                  onTap: () => _approve(item),
                                ),
                              ]),
                            ),
                        ],
                      ),
                    ),
    );
  }
}
