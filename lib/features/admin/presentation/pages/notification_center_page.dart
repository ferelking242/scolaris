import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/auth_providers.dart';
import '../../../../presentation/providers/db_providers.dart';

const _terra  = ScolarisPalette.terracotta;
const _green  = ScolarisPalette.forestGreen;
const _ink    = Color(0xFF1A0A00);
const _muted  = Color(0xFF7A5C44);
const _border = Color(0xFFDDCCBB);
const _white  = Colors.white;
const _bg     = Color(0xFFF5EEE6);

// ── Priorité (mappée sur l'enum announcement_priority) ───────────────────────
enum _Priority { normal, important, urgent }

extension _PriorityX on _Priority {
  String get db => switch (this) {
        _Priority.normal => 'normal',
        _Priority.important => 'important',
        _Priority.urgent => 'urgent',
      };
  String get label => switch (this) {
        _Priority.normal => 'Normal',
        _Priority.important => 'Important',
        _Priority.urgent => 'Urgent',
      };
  IconData get icon => switch (this) {
        _Priority.normal => Icons.info_outline_rounded,
        _Priority.important => Icons.priority_high_rounded,
        _Priority.urgent => Icons.crisis_alert_rounded,
      };
  Color get color => switch (this) {
        _Priority.normal => const Color(0xFF0EA5E9),
        _Priority.important => const Color(0xFFF59E0B),
        _Priority.urgent => ScolarisPalette.terracotta,
      };
  static _Priority fromDb(String? s) => switch (s) {
        'important' => _Priority.important,
        'urgent' => _Priority.urgent,
        _ => _Priority.normal,
      };
}

// ── Destinataires (mappés sur l'enum announcement_target) ────────────────────
enum _Target { tous, eleves, enseignants, parents, classe }

extension _TargetX on _Target {
  String get db => switch (this) {
        _Target.tous => 'all',
        _Target.eleves => 'students',
        _Target.enseignants => 'teachers',
        _Target.parents => 'parents',
        _Target.classe => 'students',
      };
  String get label => switch (this) {
        _Target.tous => 'Tous',
        _Target.eleves => 'Élèves',
        _Target.enseignants => 'Enseignants',
        _Target.parents => 'Parents',
        _Target.classe => 'Par classe',
      };
  IconData get icon => switch (this) {
        _Target.tous => Icons.groups_rounded,
        _Target.eleves => Icons.school_rounded,
        _Target.enseignants => Icons.menu_book_rounded,
        _Target.parents => Icons.family_restroom_rounded,
        _Target.classe => Icons.class_rounded,
      };
  static String labelForRole(String? role) => switch (role) {
        'all' => 'Tous',
        'students' => 'Élèves',
        'teachers' => 'Enseignants',
        'parents' => 'Parents',
        'admin' => 'Administration',
        _ => '—',
      };
}

// ── Page ──────────────────────────────────────────────────────────────────────
class NotificationCenterPage extends ConsumerStatefulWidget {
  const NotificationCenterPage({super.key});
  @override
  ConsumerState<NotificationCenterPage> createState() =>
      _NotificationCenterPageState();
}

class _NotificationCenterPageState
    extends ConsumerState<NotificationCenterPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _titleCtrl   = TextEditingController();
  final _messageCtrl = TextEditingController();
  final _formKey     = GlobalKey<FormState>();

  _Priority _priority = _Priority.normal;
  _Target   _target   = _Target.tous;
  final Set<String> _selClassIds = {};
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _titleCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  void _toast(String msg, Color bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: bg,
      content: Text(msg, style: const TextStyle(color: _white)),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    if (_target == _Target.classe && _selClassIds.isEmpty) {
      _toast('Sélectionnez au moins une classe.', _terra);
      return;
    }
    final schoolId = ref.read(currentSchoolIdProvider);
    final authorId = ref.read(authSessionProvider)?.id;
    if (schoolId == null || authorId == null) {
      _toast('Session invalide.', _terra);
      return;
    }
    setState(() => _sending = true);
    try {
      final title = _titleCtrl.text.trim();
      final content = _messageCtrl.text.trim();
      if (_target == _Target.classe) {
        // Une annonce par classe ciblée.
        for (final classId in _selClassIds) {
          await SupabaseDbSource.createAnnouncement(
            schoolId: schoolId,
            authorId: authorId,
            title: title,
            content: content,
            targetRole: 'students',
            priority: _priority.db,
            targetClassId: classId,
          );
        }
      } else {
        await SupabaseDbSource.createAnnouncement(
          schoolId: schoolId,
          authorId: authorId,
          title: title,
          content: content,
          targetRole: _target.db,
          priority: _priority.db,
        );
      }
      ref.invalidate(announcementsProvider);
      if (!mounted) return;
      setState(() {
        _titleCtrl.clear();
        _messageCtrl.clear();
        _selClassIds.clear();
        _priority = _Priority.normal;
        _target = _Target.tous;
        _sending = false;
      });
      _tab.animateTo(1);
      _toast('Annonce publiée avec succès !', _green);
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        _toast('Échec de la publication : $e', _terra);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      child: Column(
        children: [
          _TopBar(tab: _tab),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _ComposeTab(
                  formKey: _formKey,
                  titleCtrl: _titleCtrl,
                  messageCtrl: _messageCtrl,
                  priority: _priority,
                  target: _target,
                  selClassIds: _selClassIds,
                  sending: _sending,
                  onPriority: (p) => setState(() => _priority = p),
                  onTarget: (t) => setState(() => _target = t),
                  onClassToggle: (id) => setState(() => _selClassIds.contains(id)
                      ? _selClassIds.remove(id)
                      : _selClassIds.add(id)),
                  onSend: _send,
                ),
                const _HistoryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Top bar ────────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final TabController tab;
  const _TopBar({required this.tab});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _white,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF1A0A00), _terra]),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Center(child: Icon(Icons.campaign_rounded,
                  color: _white, size: 20)),
            ),
            const SizedBox(width: 12),
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Annonces & notifications',
                  style: TextStyle(fontSize: 16,
                      fontWeight: FontWeight.w800, color: _ink)),
              Text('Publiez des annonces à la communauté',
                  style: TextStyle(fontSize: 12, color: _muted)),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        TabBar(
          controller: tab,
          labelColor: _terra,
          unselectedLabelColor: _muted,
          indicatorColor: _terra,
          indicatorWeight: 2.5,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.edit_outlined, size: 16), text: 'Composer'),
            Tab(icon: Icon(Icons.history_rounded, size: 16), text: 'Historique'),
          ],
        ),
      ]),
    );
  }
}

// ── Compose tab ───────────────────────────────────────────────────────────────
class _ComposeTab extends ConsumerWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController titleCtrl;
  final TextEditingController messageCtrl;
  final _Priority priority;
  final _Target target;
  final Set<String> selClassIds;
  final bool sending;
  final ValueChanged<_Priority> onPriority;
  final ValueChanged<_Target> onTarget;
  final ValueChanged<String> onClassToggle;
  final VoidCallback onSend;

  const _ComposeTab({
    required this.formKey,
    required this.titleCtrl,
    required this.messageCtrl,
    required this.priority,
    required this.target,
    required this.selClassIds,
    required this.sending,
    required this.onPriority,
    required this.onTarget,
    required this.onClassToggle,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Priorité ──────────────────────────────────────────────────
            const _Label('Priorité'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _Priority.values.map((p) {
                final sel = p == priority;
                return GestureDetector(
                  onTap: () => onPriority(p),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? p.color : _white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: sel ? p.color : _border, width: sel ? 0 : 1),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(p.icon, size: 14, color: sel ? _white : _muted),
                      const SizedBox(width: 6),
                      Text(p.label, style: TextStyle(
                          fontSize: 12.5,
                          color: sel ? _white : _ink,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
                    ]),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // ── Destinataires ─────────────────────────────────────────────
            const _Label('Destinataires'),
            const SizedBox(height: 10),
            Builder(builder: (_) {
              final familiesEnabled =
                  ref.watch(familyAccountsEnabledProvider).valueOrNull ?? false;
              return Wrap(
                spacing: 8, runSpacing: 8,
                children: _Target.values.map((t) {
                  final sel = t == target;
                  final locked = t == _Target.parents && !familiesEnabled;
                  return GestureDetector(
                    onTap: locked ? null : () => onTarget(t),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: locked
                            ? const Color(0xFFF5EEE6)
                            : sel ? _ink : _white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: locked
                                ? _border
                                : sel ? _ink : _border),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(
                          locked ? Icons.lock_outline_rounded : t.icon,
                          size: 14,
                          color: locked ? _muted : sel ? _white : _muted,
                        ),
                        const SizedBox(width: 6),
                        Text(t.label, style: TextStyle(
                            fontSize: 12.5,
                            color: locked ? _muted : sel ? _white : _ink,
                            fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
                        if (locked) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C3AED).withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('Pro',
                                style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF7C3AED))),
                          ),
                        ],
                      ]),
                    ),
                  );
                }).toList(),
              );
            }),

            // ── Sélecteur de classes (réelles) ────────────────────────────
            if (target == _Target.classe) ...[
              const SizedBox(height: 16),
              const _Label('Sélectionner les classes'),
              const SizedBox(height: 10),
              ref.watch(classesProvider).when(
                    loading: () => const Padding(
                        padding: EdgeInsets.all(8),
                        child: LinearProgressIndicator()),
                    error: (e, _) => Text('Classes indisponibles : $e',
                        style: const TextStyle(color: _terra, fontSize: 12)),
                    data: (classes) => classes.isEmpty
                        ? const Text('Aucune classe. Créez-en d\'abord.',
                            style: TextStyle(color: _muted, fontSize: 12.5))
                        : Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: _border),
                            ),
                            child: Wrap(
                              spacing: 6, runSpacing: 6,
                              children: classes.map((c) {
                                final sel = selClassIds.contains(c.id);
                                return GestureDetector(
                                  onTap: () => onClassToggle(c.id),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 120),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: sel
                                          ? _terra
                                          : const Color(0xFFF5EEE6),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: sel ? _terra : _border),
                                    ),
                                    child: Text(c.name, style: TextStyle(
                                        fontSize: 11,
                                        color: sel ? _white : _ink,
                                        fontWeight: sel
                                            ? FontWeight.w700
                                            : FontWeight.w500)),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                  ),
            ],
            const SizedBox(height: 20),

            // ── Titre ─────────────────────────────────────────────────────
            const _Label('Titre'),
            const SizedBox(height: 8),
            TextFormField(
              controller: titleCtrl,
              style: const TextStyle(fontSize: 14, color: _ink),
              decoration: _fieldDeco('Ex: Réunion parents-professeurs du 28 mai'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Titre requis' : null,
            ),
            const SizedBox(height: 16),

            // ── Message ───────────────────────────────────────────────────
            const _Label('Message'),
            const SizedBox(height: 8),
            TextFormField(
              controller: messageCtrl,
              maxLines: 5,
              style: const TextStyle(fontSize: 13.5, color: _ink, height: 1.5),
              decoration: _fieldDeco('Rédigez votre message ici…'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Message requis' : null,
            ),
            const SizedBox(height: 24),

            // ── Bouton d'envoi ────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: sending ? null : onSend,
                icon: sending
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _white))
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(sending ? 'Publication…' : 'Publier l\'annonce',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _terra,
                  foregroundColor: _white,
                  disabledBackgroundColor: _terra.withValues(alpha: .5),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  static InputDecoration _fieldDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: _muted.withValues(alpha: .5), fontSize: 13),
        filled: true,
        fillColor: _white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _terra, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _terra)),
      );
}

// ── History tab (données réelles) ────────────────────────────────────────────
class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcementsAsync = ref.watch(announcementsProvider);
    final classesAsync = ref.watch(classesProvider);
    final classNames = <String, String>{
      for (final c in (classesAsync.valueOrNull ?? const [])) c.id: c.name,
    };
    return announcementsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
          child: Text('Erreur : $e',
              style: const TextStyle(color: _muted, fontSize: 13))),
      data: (list) {
        if (list.isEmpty) {
          return Center(child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.notifications_none_rounded,
                  size: 56, color: _muted.withValues(alpha: .3)),
              const SizedBox(height: 12),
              const Text('Aucune annonce publiée',
                  style: TextStyle(color: _muted, fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ],
          ));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _HistoryCard(
            notif: list[i],
            classNames: classNames,
            onDelete: () async {
              try {
                await SupabaseDbSource.deleteAnnouncement(list[i].id);
                ref.invalidate(announcementsProvider);
              } catch (_) {}
            },
          ),
        );
      },
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final SbAnnouncement notif;
  final Map<String, String> classNames;
  final VoidCallback onDelete;
  const _HistoryCard(
      {required this.notif, required this.classNames, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final prio = _PriorityX.fromDb(notif.priority);
    final c = prio.color;
    final d = notif.createdAt;
    final dateStr = d == null
        ? ''
        : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} · '
            '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final targetLabel = notif.targetClassId != null
        ? (classNames[notif.targetClassId] ?? 'Classe')
        : _TargetX.labelForRole(notif.targetRole);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: const [BoxShadow(
            color: Color(0x08000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: c.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(child: Icon(prio.icon, color: c, size: 18)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: c.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(prio.label.toUpperCase(),
                    style: TextStyle(color: c, fontSize: 9,
                        fontWeight: FontWeight.w800, letterSpacing: .7)),
              ),
              const SizedBox(width: 6),
              Icon(Icons.groups_rounded, size: 12, color: _muted),
              const SizedBox(width: 3),
              Flexible(child: Text(targetLabel,
                  style: const TextStyle(color: _muted, fontSize: 11),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 5),
            Text(notif.title, style: const TextStyle(
                color: _ink, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(notif.content ?? '',
                style: const TextStyle(color: _muted, fontSize: 11.5, height: 1.4),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.access_time_rounded, size: 11,
                  color: _muted.withValues(alpha: .6)),
              const SizedBox(width: 4),
              Text(dateStr, style: TextStyle(
                  color: _muted.withValues(alpha: .7), fontSize: 10.5)),
              if (notif.authorName != null) ...[
                const SizedBox(width: 8),
                Icon(Icons.person_outline_rounded, size: 11,
                    color: _muted.withValues(alpha: .6)),
                const SizedBox(width: 3),
                Flexible(child: Text(notif.authorName!,
                    style: TextStyle(
                        color: _muted.withValues(alpha: .7), fontSize: 10.5),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ]),
          ],
        )),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: _muted),
          tooltip: 'Supprimer',
          onPressed: onDelete,
        ),
      ]),
    );
  }
}

// ── Helper widget ─────────────────────────────────────────────────────────────
class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 13, color: _ink,
          fontWeight: FontWeight.w700));
}
