import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';

const _terra  = ScolarisPalette.terracotta;
const _orange = ScolarisPalette.orange;
const _gold   = ScolarisPalette.gold;
const _green  = ScolarisPalette.forestGreen;
const _ink    = Color(0xFF1A0A00);
const _muted  = Color(0xFF7A5C44);
const _border = Color(0xFFDDCCBB);
const _white  = Colors.white;
const _bg     = Color(0xFFF5EEE6);

// ── Notification types ────────────────────────────────────────────────────────
enum _NotifType { info, alerte, resultat, rappel, urgence }

extension _NotifTypeX on _NotifType {
  String get label {
    switch (this) {
      case _NotifType.info:      return 'Info';
      case _NotifType.alerte:    return 'Alerte';
      case _NotifType.resultat:  return 'Résultat';
      case _NotifType.rappel:    return 'Rappel';
      case _NotifType.urgence:   return 'Urgence';
    }
  }
  IconData get icon {
    switch (this) {
      case _NotifType.info:      return Icons.info_outline_rounded;
      case _NotifType.alerte:    return Icons.warning_amber_rounded;
      case _NotifType.resultat:  return Icons.grade_outlined;
      case _NotifType.rappel:    return Icons.alarm_rounded;
      case _NotifType.urgence:   return Icons.crisis_alert_rounded;
    }
  }
  Color get color {
    switch (this) {
      case _NotifType.info:      return const Color(0xFF0EA5E9);
      case _NotifType.alerte:    return const Color(0xFFF59E0B);
      case _NotifType.resultat:  return ScolarisPalette.forestGreen;
      case _NotifType.rappel:    return ScolarisPalette.orange;
      case _NotifType.urgence:   return ScolarisPalette.terracotta;
    }
  }
}

// ── Target ────────────────────────────────────────────────────────────────────
enum _Target { tous, eleves, enseignants, parents, classe }

extension _TargetX on _Target {
  String get label {
    switch (this) {
      case _Target.tous:         return 'Tous';
      case _Target.eleves:       return 'Élèves';
      case _Target.enseignants:  return 'Enseignants';
      case _Target.parents:      return 'Parents';
      case _Target.classe:       return 'Par classe';
    }
  }
  IconData get icon {
    switch (this) {
      case _Target.tous:         return Icons.groups_rounded;
      case _Target.eleves:       return Icons.school_rounded;
      case _Target.enseignants:  return Icons.menu_book_rounded;
      case _Target.parents:      return Icons.family_restroom_rounded;
      case _Target.classe:       return Icons.class_rounded;
    }
  }
}

// ── Sent notification model ────────────────────────────────────────────────────
class _SentNotif {
  final _NotifType type;
  final _Target target;
  final String targetDetail;
  final String title;
  final String message;
  final DateTime sentAt;
  const _SentNotif({
    required this.type,
    required this.target,
    required this.targetDetail,
    required this.title,
    required this.message,
    required this.sentAt,
  });
}

// ── Mock history ──────────────────────────────────────────────────────────────
final _mockHistory = <_SentNotif>[
  _SentNotif(
    type: _NotifType.rappel,
    target: _Target.tous,
    targetDetail: 'Toute l\'école',
    title: 'Réunion parents-professeurs',
    message: 'La réunion annuelle aura lieu le 28 mai 2026 à 15h00 en salle polyvalente.',
    sentAt: DateTime(2026, 5, 20, 9, 14),
  ),
  _SentNotif(
    type: _NotifType.resultat,
    target: _Target.eleves,
    targetDetail: 'Terminale C',
    title: 'Résultats du 2e semestre',
    message: 'Les résultats du semestre 2 sont maintenant disponibles dans votre espace élève.',
    sentAt: DateTime(2026, 5, 18, 14, 30),
  ),
  _SentNotif(
    type: _NotifType.alerte,
    target: _Target.parents,
    targetDetail: '4e A · 4e B',
    title: 'Absence non justifiée',
    message: 'Votre enfant présente des absences non justifiées. Veuillez contacter la direction.',
    sentAt: DateTime(2026, 5, 15, 8, 5),
  ),
  _SentNotif(
    type: _NotifType.info,
    target: _Target.enseignants,
    targetDetail: 'Corps enseignant',
    title: 'Conseil pédagogique',
    message: 'Le conseil pédagogique de fin d\'année se tient le 30 mai 2026.',
    sentAt: DateTime(2026, 5, 10, 11, 0),
  ),
];

const _classes = [
  'CP A', 'CP B', 'CE1 A', 'CE1 B', 'CE2 A', 'CE2 B',
  'CM1 A', 'CM1 B', 'CM2 A', 'CM2 B',
  '6e A', '6e B', '5e A', '5e B', '4e A', '4e B', '3e A', '3e B',
  '2nde A', '2nde C', '1ère A', '1ère C', 'Tle A', 'Tle C', 'Tle D',
];

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

  _NotifType _type        = _NotifType.info;
  _Target    _target      = _Target.tous;
  List<String> _selClasses = [];
  bool _sending = false;

  final List<_SentNotif> _history = List.from(_mockHistory);

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

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    if (_target == _Target.classe && _selClasses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _terra,
          content: const Text('Sélectionnez au moins une classe.',
              style: TextStyle(color: _white)),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }
    setState(() => _sending = true);
    await Future.delayed(const Duration(milliseconds: 900));
    final detail = _target == _Target.classe
        ? _selClasses.join(' · ')
        : _target.label;
    setState(() {
      _history.insert(0, _SentNotif(
        type: _type,
        target: _target,
        targetDetail: detail,
        title: _titleCtrl.text.trim(),
        message: _messageCtrl.text.trim(),
        sentAt: DateTime.now(),
      ));
      _titleCtrl.clear();
      _messageCtrl.clear();
      _selClasses.clear();
      _type = _NotifType.info;
      _target = _Target.tous;
      _sending = false;
    });
    _tab.animateTo(1);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _green,
          content: Row(children: const [
            Icon(Icons.check_circle_rounded, color: _white, size: 18),
            SizedBox(width: 10),
            Text('Notification envoyée avec succès !',
                style: TextStyle(color: _white, fontWeight: FontWeight.w600)),
          ]),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
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
                  type: _type,
                  target: _target,
                  selClasses: _selClasses,
                  sending: _sending,
                  onType: (t) => setState(() => _type = t),
                  onTarget: (t) => setState(() => _target = t),
                  onClassToggle: (c) => setState(() =>
                      _selClasses.contains(c)
                          ? _selClasses.remove(c)
                          : _selClasses.add(c)),
                  onSend: _send,
                ),
                _HistoryTab(history: _history),
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
              Text('Centre de notifications',
                  style: TextStyle(fontSize: 16,
                      fontWeight: FontWeight.w800, color: _ink)),
              Text('Envoyez des messages à toute la communauté',
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
class _ComposeTab extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController titleCtrl;
  final TextEditingController messageCtrl;
  final _NotifType type;
  final _Target target;
  final List<String> selClasses;
  final bool sending;
  final ValueChanged<_NotifType> onType;
  final ValueChanged<_Target> onTarget;
  final ValueChanged<String> onClassToggle;
  final VoidCallback onSend;

  const _ComposeTab({
    required this.formKey,
    required this.titleCtrl,
    required this.messageCtrl,
    required this.type,
    required this.target,
    required this.selClasses,
    required this.sending,
    required this.onType,
    required this.onTarget,
    required this.onClassToggle,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Type ──────────────────────────────────────────────────────
            _Label('Type de notification'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _NotifType.values.map((t) {
                final sel = t == type;
                return GestureDetector(
                  onTap: () => onType(t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? t.color : _white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: sel ? t.color : _border, width: sel ? 0 : 1),
                      boxShadow: sel
                          ? [BoxShadow(color: t.color.withOpacity(.3),
                              blurRadius: 8, offset: const Offset(0, 2))]
                          : [],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(t.icon, size: 14,
                          color: sel ? _white : _muted),
                      const SizedBox(width: 6),
                      Text(t.label, style: TextStyle(
                          fontSize: 12.5,
                          color: sel ? _white : _ink,
                          fontWeight: sel
                              ? FontWeight.w700
                              : FontWeight.w500)),
                    ]),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // ── Destinataires ─────────────────────────────────────────────
            _Label('Destinataires'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _Target.values.map((t) {
                final sel = t == target;
                return GestureDetector(
                  onTap: () => onTarget(t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? _ink : _white,
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: sel ? _ink : _border),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(t.icon, size: 14,
                          color: sel ? _white : _muted),
                      const SizedBox(width: 6),
                      Text(t.label, style: TextStyle(
                          fontSize: 12.5,
                          color: sel ? _white : _ink,
                          fontWeight: sel
                              ? FontWeight.w700
                              : FontWeight.w500)),
                    ]),
                  ),
                );
              }).toList(),
            ),

            // ── Sélecteur de classes ───────────────────────────────────────
            if (target == _Target.classe) ...[
              const SizedBox(height: 16),
              _Label('Sélectionner les classes'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border),
                ),
                child: Wrap(
                  spacing: 6, runSpacing: 6,
                  children: _classes.map((c) {
                    final sel = selClasses.contains(c);
                    return GestureDetector(
                      onTap: () => onClassToggle(c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: sel ? _terra : const Color(0xFFF5EEE6),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: sel ? _terra : _border),
                        ),
                        child: Text(c, style: TextStyle(
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
            ],
            const SizedBox(height: 20),

            // ── Titre ─────────────────────────────────────────────────────
            _Label('Titre'),
            const SizedBox(height: 8),
            TextFormField(
              controller: titleCtrl,
              style: const TextStyle(fontSize: 14, color: _ink),
              decoration: InputDecoration(
                hintText: 'Ex: Réunion parents-professeurs du 28 mai',
                hintStyle: TextStyle(color: _muted.withOpacity(.5), fontSize: 13),
                filled: true,
                fillColor: _white,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _terra, width: 1.5)),
                errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _terra)),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Titre requis' : null,
            ),
            const SizedBox(height: 16),

            // ── Message ───────────────────────────────────────────────────
            _Label('Message'),
            const SizedBox(height: 8),
            TextFormField(
              controller: messageCtrl,
              maxLines: 5,
              style: const TextStyle(fontSize: 13.5, color: _ink, height: 1.5),
              decoration: InputDecoration(
                hintText: 'Rédigez votre message ici…',
                hintStyle: TextStyle(color: _muted.withOpacity(.5), fontSize: 13),
                filled: true,
                fillColor: _white,
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _terra, width: 1.5)),
                errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _terra)),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Message requis' : null,
            ),
            const SizedBox(height: 24),

            // ── Aperçu ────────────────────────────────────────────────────
            _NotifPreview(type: type, target: target, selClasses: selClasses),
            const SizedBox(height: 24),

            // ── Bouton d'envoi ────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: ElevatedButton.icon(
                  onPressed: sending ? null : onSend,
                  icon: sending
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: _white))
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(sending ? 'Envoi en cours…' : 'Envoyer la notification',
                      style: const TextStyle(fontWeight: FontWeight.w700,
                          fontSize: 14)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _terra,
                    foregroundColor: _white,
                    disabledBackgroundColor: _terra.withOpacity(.5),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                    shadowColor: _terra.withOpacity(.3),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ── Notification preview card ─────────────────────────────────────────────────
class _NotifPreview extends StatelessWidget {
  final _NotifType type;
  final _Target target;
  final List<String> selClasses;
  const _NotifPreview(
      {required this.type, required this.target, required this.selClasses});

  @override
  Widget build(BuildContext context) {
    final detail = target == _Target.classe
        ? (selClasses.isEmpty ? 'Aucune classe sélectionnée' : selClasses.join(', '))
        : target.label;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: type.color.withOpacity(.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: type.color.withOpacity(.2)),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: type.color.withOpacity(.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(child: Icon(type.icon, color: type.color, size: 20)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: type.color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(type.label.toUpperCase(),
                    style: const TextStyle(color: _white, fontSize: 9,
                        fontWeight: FontWeight.w800, letterSpacing: .8)),
              ),
              const SizedBox(width: 6),
              Text('→ $detail',
                  style: TextStyle(color: _muted, fontSize: 11)),
            ]),
            const SizedBox(height: 4),
            Text('Aperçu de la notification en temps réel',
                style: TextStyle(color: type.color.withOpacity(.8),
                    fontSize: 11.5, fontWeight: FontWeight.w600)),
          ],
        )),
      ]),
    );
  }
}

// ── History tab ───────────────────────────────────────────────────────────────
class _HistoryTab extends StatelessWidget {
  final List<_SentNotif> history;
  const _HistoryTab({required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_none_rounded,
              size: 56, color: _muted.withOpacity(.3)),
          const SizedBox(height: 12),
          Text('Aucune notification envoyée',
              style: TextStyle(color: _muted, fontSize: 14,
                  fontWeight: FontWeight.w600)),
        ],
      ));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: history.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _HistoryCard(notif: history[i]),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final _SentNotif notif;
  const _HistoryCard({required this.notif});

  @override
  Widget build(BuildContext context) {
    final c = notif.type.color;
    final d = notif.sentAt;
    final dateStr =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} · '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
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
            color: c.withOpacity(.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(child: Icon(notif.type.icon, color: c, size: 18)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: c.withOpacity(.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(notif.type.label.toUpperCase(),
                    style: TextStyle(color: c, fontSize: 9,
                        fontWeight: FontWeight.w800, letterSpacing: .7)),
              ),
              const SizedBox(width: 6),
              Icon(notif.target.icon, size: 12, color: _muted),
              const SizedBox(width: 3),
              Flexible(child: Text(notif.targetDetail,
                  style: const TextStyle(color: _muted, fontSize: 11),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 5),
            Text(notif.title, style: const TextStyle(
                color: _ink, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(notif.message,
                style: const TextStyle(color: _muted, fontSize: 11.5, height: 1.4),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.access_time_rounded, size: 11,
                  color: _muted.withOpacity(.6)),
              const SizedBox(width: 4),
              Text(dateStr, style: TextStyle(
                  color: _muted.withOpacity(.7), fontSize: 10.5)),
            ]),
          ],
        )),
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
