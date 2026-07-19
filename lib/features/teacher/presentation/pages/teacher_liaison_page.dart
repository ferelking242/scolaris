import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/permissions/my_grants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/auth_providers.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';

const _terra = ScolarisPalette.terracotta;
const _gold  = ScolarisPalette.gold;
const _green = ScolarisPalette.forestGreen;
const _white = Colors.white; // sur fond de marque coloré

// Vocabulaire de la base (contrainte `category` de `liaison_entries`).
const _categories = <String, ({String label, Color color, IconData icon})>{
  'info':          (label: 'Information',   color: Color(0xFF0891B2), icon: Icons.info_rounded),
  'devoir':        (label: 'Devoir',        color: Color(0xFF1565C0), icon: Icons.assignment_rounded),
  'sortie':        (label: 'Sortie',        color: Color(0xFF6D28D9), icon: Icons.directions_bus_rounded),
  'medicament':    (label: 'Médicament',    color: Color(0xFFDB2777), icon: Icons.medical_services_rounded),
  'permission':    (label: 'Permission',    color: _gold,             icon: Icons.event_available_rounded),
  'felicitation':  (label: 'Félicitation',  color: _green,            icon: Icons.emoji_events_rounded),
  'avertissement': (label: 'Avertissement', color: _terra,            icon: Icons.warning_amber_rounded),
};

// ══════════════════════════════════════════════════════════════════════════
// Cahier de liaison — CÔTÉ ENSEIGNANT (l'écriture).
//
// C'est la pièce sans laquelle tout le reste ne sert à rien : un cahier de
// liaison où personne n'écrit reste une boîte vide. Le prof choisit une de
// SES classes, écrit un mot, et décide s'il exige une signature du parent.
//
// La RLS refuse l'écriture hors de ses classes (`teaches_class`) et sans la
// permission `liaison.ecrire` — l'UI ne fait que refléter cette règle.
// ══════════════════════════════════════════════════════════════════════════
class TeacherLiaisonPage extends ConsumerStatefulWidget {
  const TeacherLiaisonPage({super.key});
  @override
  ConsumerState<TeacherLiaisonPage> createState() => _TeacherLiaisonPageState();
}

class _TeacherLiaisonPageState extends ConsumerState<TeacherLiaisonPage> {
  SbClass? _class;

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(teacherClassesProvider);

    return classesAsync.when(
      loading: () => const PageScaffold(
        title: 'Cahier de liaison',
        child: Center(child: Padding(
          padding: EdgeInsets.only(top: 60),
          child: CircularProgressIndicator(),
        )),
      ),
      error: (e, _) => PageScaffold(
        title: 'Cahier de liaison',
        child: Center(child: Text('Erreur : $e',
            style: TextStyle(color: context.cMuted))),
      ),
      data: (classes) {
        if (classes.isEmpty) {
          return const PageScaffold(
            title: 'Cahier de liaison',
            child: EmptyState(
              icon: Icons.class_outlined,
              title: 'Aucune classe',
              description:
                  'Vous n\'êtes affecté à aucune classe. Contactez la direction.',
            ),
          );
        }

        final selected = _class ?? classes.first;
        final entriesAsync =
            ref.watch(liaisonEntriesForClassProvider(selected.id));
        final entries = entriesAsync.valueOrNull ?? const <SbLiaisonEntry>[];

        return PageScaffold(
          title: 'Cahier de liaison',
          subtitle: entries.isEmpty
              ? 'Aucun mot écrit'
              : '${entries.length} mot(s) · ${selected.name}',
          actions: [
            // Écrire dans le cahier est une permission à part (`liaison.ecrire`) :
            // un directeur peut n'ouvrir l'écriture qu'aux instituteurs.
            if (ref.watch(canProvider('liaison.ecrire')))
              ActionButton(
                label: 'Écrire un mot',
                icon: Icons.edit_rounded,
                primary: true,
                onTap: () => _compose(selected),
              ),
          ],
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── Choix de la classe ────────────────────────────────────────
            if (classes.length > 1) ...[
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: classes.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final c = classes[i];
                    final sel = c.id == selected.id;
                    return MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => setState(() => _class = c),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: sel ? _terra : context.cCard,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: sel ? _terra : context.cBorder),
                          ),
                          child: Text(c.name, style: TextStyle(
                              color: sel ? _white : context.cMuted,
                              fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
            ],

            if (entriesAsync.isLoading)
              const Center(child: Padding(
                padding: EdgeInsets.only(top: 40),
                child: CircularProgressIndicator(),
              ))
            else if (entries.isEmpty)
              EmptyState(
                icon: Icons.import_contacts_outlined,
                title: 'Le cahier de ${selected.name} est vide',
                description:
                    'Écrivez un mot : il apparaîtra chez les parents et les élèves.',
              )
            else
              for (final e in entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _EntryRow(
                    entry: e,
                    onDelete: () => _delete(e, selected.id),
                  ),
                ),
          ]),
        );
      },
    );
  }

  Future<void> _compose(SbClass klass) async {
    final session = ref.read(authSessionProvider);
    final schoolId = ref.read(currentSchoolIdProvider);
    if (session == null || schoolId == null) return;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ComposeSheet(
        klass: klass,
        schoolId: schoolId,
        authorId: session.id,
      ),
    );

    if (saved == true) {
      ref.invalidate(liaisonEntriesForClassProvider(klass.id));
    }
  }

  Future<void> _delete(SbLiaisonEntry e, String classId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Supprimer ce mot ?'),
        content: Text('« ${e.title} » disparaîtra du cahier des familles.'),
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
      await SupabaseDbSource.deleteLiaisonEntry(e.id);
      ref.invalidate(liaisonEntriesForClassProvider(classId));
    } catch (err) {
      if (!mounted) return;
      // La RLS n'accorde `liaison.supprimer` ni à l'enseignant ni au
      // surveillant : l'échec ici est un refus légitime, pas un bug.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Suppression refusée : $err')),
      );
    }
  }
}

// ── Ligne d'un mot déjà écrit ─────────────────────────────────────────────────
class _EntryRow extends StatelessWidget {
  final SbLiaisonEntry entry;
  final VoidCallback onDelete;
  const _EntryRow({required this.entry, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cat = _categories[entry.category] ?? _categories['info']!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.cBorder),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: cat.color.withOpacity(.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(cat.icon, color: cat.color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: cat.color.withOpacity(.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(cat.label, style: TextStyle(
                  fontSize: 9.5, fontWeight: FontWeight.w700,
                  color: cat.color)),
            ),
            if (entry.requiresAck) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _gold.withOpacity(.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Signature demandée',
                    style: TextStyle(fontSize: 9.5,
                        fontWeight: FontWeight.w600, color: _gold)),
              ),
            ],
            const Spacer(),
            Text(_fmt(entry.createdAt),
                style: TextStyle(fontSize: 10, color: context.cMuted)),
          ]),
          const SizedBox(height: 5),
          Text(entry.title, style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700,
              color: context.cInk)),
          const SizedBox(height: 3),
          Text(entry.body,
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: context.cMuted,
                  height: 1.4)),
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

  static String _fmt(DateTime? d) {
    if (d == null) return '';
    const mois = ['janv.','févr.','mars','avr.','mai','juin','juil.','août',
                  'sept.','oct.','nov.','déc.'];
    return '${d.day} ${mois[d.month - 1]}';
  }
}

// ── Rédaction d'un mot ────────────────────────────────────────────────────────
class _ComposeSheet extends StatefulWidget {
  final SbClass klass;
  final String schoolId, authorId;
  const _ComposeSheet({
    required this.klass,
    required this.schoolId,
    required this.authorId,
  });

  @override
  State<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<_ComposeSheet> {
  final _title = TextEditingController();
  final _body  = TextEditingController();
  String _category = 'info';
  bool _requiresAck = false;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: BoxDecoration(
          color: context.cPage,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: context.cBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: Text('Écrire à ${widget.klass.name}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                    color: context.cInk))),
          ]),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Le mot sera visible par les parents et les élèves '
                'de la classe.',
                style: TextStyle(fontSize: 11.5, color: context.cMuted)),
          ),
          const SizedBox(height: 16),

          // Catégorie
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final e in _categories.entries) ...[
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => setState(() => _category = e.key),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _category == e.key
                              ? e.value.color
                              : context.cCard,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: _category == e.key
                                  ? e.value.color
                                  : context.cBorder),
                        ),
                        child: Text(e.value.label, style: TextStyle(
                            color: _category == e.key
                                ? _white
                                : context.cMuted,
                            fontSize: 11.5, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: 'Titre',
              hintText: 'Sortie au musée vendredi',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _body,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Message',
              hintText: 'Détaillez ici ce que les parents doivent savoir…',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _requiresAck,
            onChanged: (v) => setState(() => _requiresAck = v),
            title: Text('Demander une signature',
                style: TextStyle(fontSize: 13, color: context.cInk,
                    fontWeight: FontWeight.w600)),
            subtitle: Text('Le parent devra confirmer qu\'il a lu le mot.',
                style: TextStyle(fontSize: 11, color: context.cMuted)),
            activeColor: _terra,
          ),
          const SizedBox(height: 8),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _terra,
                foregroundColor: _white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _white))
                  : const Text('Envoyer le mot',
                      style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final body  = _body.text.trim();
    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le titre et le message sont requis.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await SupabaseDbSource.createLiaisonEntry(
        schoolId: widget.schoolId,
        authorId: widget.authorId,
        classId: widget.klass.id,
        title: title,
        body: body,
        category: _category,
        requiresAck: _requiresAck,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Envoi impossible : $e')),
      );
    }
  }
}
