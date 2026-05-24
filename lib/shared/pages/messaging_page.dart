import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

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

// ── Modèles ───────────────────────────────────────────────────────────────────
class _Message {
  final String text;
  final bool isMine;
  final DateTime time;
  _Message({required this.text, required this.isMine, required this.time});
}

class _Conversation {
  final String id;
  final String name;
  final String role;
  final String initials;
  final Color avatarColor;
  bool unread;
  final List<_Message> messages;
  _Conversation({
    required this.id,
    required this.name,
    required this.role,
    required this.initials,
    required this.avatarColor,
    this.unread = false,
    required this.messages,
  });

  _Message? get last => messages.isEmpty ? null : messages.last;
}

final _conversations = <_Conversation>[
  _Conversation(
    id: 'c1',
    name: 'M. Ngakosso Jean-Pierre',
    role: 'Enseignant · Maths',
    initials: 'NJ',
    avatarColor: const Color(0xFF6D28D9),
    unread: true,
    messages: [
      _Message(text: 'Bonjour Junior, votre travail sur les logarithmes était excellent.', isMine: false, time: DateTime.now().subtract(const Duration(minutes: 35))),
      _Message(text: 'Merci beaucoup Monsieur ! J\'ai beaucoup révisé.', isMine: true, time: DateTime.now().subtract(const Duration(minutes: 30))),
      _Message(text: 'Continuez ainsi. Le cours de demain est avancé à 7h30.', isMine: false, time: DateTime.now().subtract(const Duration(minutes: 12))),
    ],
  ),
  _Conversation(
    id: 'c2',
    name: 'Direction Scolaire',
    role: 'Administration',
    initials: 'DS',
    avatarColor: const Color(0xFF8B1A00),
    unread: true,
    messages: [
      _Message(text: 'Chers parents, la réunion est programmée le 28 mai à 15h00.', isMine: false, time: DateTime.now().subtract(const Duration(hours: 2))),
      _Message(text: 'D\'accord, nous serons présents.', isMine: true, time: DateTime.now().subtract(const Duration(hours: 1, minutes: 45))),
    ],
  ),
  _Conversation(
    id: 'c3',
    name: 'Mme Mavoungou Cécile',
    role: 'Enseignante · Français',
    initials: 'MC',
    avatarColor: const Color(0xFFEA580C),
    unread: false,
    messages: [
      _Message(text: 'Votre commentaire littéraire sur Oyono était bien construit. Note : 14/20.', isMine: false, time: DateTime(2026, 5, 22, 11, 30)),
      _Message(text: 'Merci Madame, je ferai mieux pour le prochain !', isMine: true, time: DateTime(2026, 5, 22, 12, 5)),
      _Message(text: 'Bonne résolution. N\'hésitez pas si vous avez des questions.', isMine: false, time: DateTime(2026, 5, 22, 12, 10)),
    ],
  ),
  _Conversation(
    id: 'c4',
    name: 'Mme Monianga Sylvie',
    role: 'Enseignante · Sciences',
    initials: 'MS',
    avatarColor: const Color(0xFF2D6A4F),
    unread: false,
    messages: [
      _Message(text: 'Kevin progresse très bien en sciences ce trimestre.', isMine: false, time: DateTime(2026, 5, 20, 9, 14)),
      _Message(text: 'C\'est une très bonne nouvelle, merci de nous tenir informés.', isMine: true, time: DateTime(2026, 5, 20, 9, 45)),
    ],
  ),
  _Conversation(
    id: 'c5',
    name: 'Service Finance',
    role: 'Comptabilité',
    initials: 'SF',
    avatarColor: const Color(0xFFC17F24),
    unread: false,
    messages: [
      _Message(text: 'Rappel : les frais de scolarité du semestre 2 sont dus au 31 mai 2026. Montant : 85 000 XAF.', isMine: false, time: DateTime(2026, 5, 15, 8, 0)),
      _Message(text: 'Message bien reçu, nous procéderons au règlement cette semaine.', isMine: true, time: DateTime(2026, 5, 15, 10, 30)),
    ],
  ),
];

// ── Page ──────────────────────────────────────────────────────────────────────
class MessagingPage extends StatefulWidget {
  const MessagingPage({super.key});
  @override
  State<MessagingPage> createState() => _MessagingPageState();
}

class _MessagingPageState extends State<MessagingPage> {
  _Conversation? _selected;
  final _msgCtrl = TextEditingController();
  final _listKey = GlobalKey<AnimatedListState>();

  @override
  void initState() {
    super.initState();
    _selected = _conversations.first;
  }

  @override
  void dispose() { _msgCtrl.dispose(); super.dispose(); }

  void _send() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _selected!.messages.add(_Message(text: text, isMine: true, time: DateTime.now()));
      _msgCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 700;
    return Container(
      color: _bg,
      child: wide ? _WideLayout(
        conversations: _conversations,
        selected: _selected,
        msgCtrl: _msgCtrl,
        onSelect: (c) => setState(() { _selected = c; c.unread = false; }),
        onSend: _send,
      ) : _NarrowLayout(
        conversations: _conversations,
        selected: _selected,
        msgCtrl: _msgCtrl,
        onSelect: (c) => setState(() { _selected = c; c.unread = false; }),
        onSend: _send,
        onBack: () => setState(() => _selected = null),
      ),
    );
  }
}

// ── Wide (side-by-side) ────────────────────────────────────────────────────────
class _WideLayout extends StatelessWidget {
  final List<_Conversation> conversations;
  final _Conversation? selected;
  final TextEditingController msgCtrl;
  final ValueChanged<_Conversation> onSelect;
  final VoidCallback onSend;
  const _WideLayout({
    required this.conversations, required this.selected,
    required this.msgCtrl, required this.onSelect, required this.onSend,
  });
  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        width: 280,
        child: _ConversationList(
          conversations: conversations,
          selected: selected,
          onSelect: onSelect,
        ),
      ),
      Container(width: 1, color: _border),
      Expanded(child: selected == null
          ? _EmptyChat()
          : _ChatPanel(conv: selected!, msgCtrl: msgCtrl, onSend: onSend)),
    ]);
  }
}

// ── Narrow ────────────────────────────────────────────────────────────────────
class _NarrowLayout extends StatelessWidget {
  final List<_Conversation> conversations;
  final _Conversation? selected;
  final TextEditingController msgCtrl;
  final ValueChanged<_Conversation> onSelect;
  final VoidCallback onSend;
  final VoidCallback onBack;
  const _NarrowLayout({
    required this.conversations, required this.selected,
    required this.msgCtrl, required this.onSelect,
    required this.onSend, required this.onBack,
  });
  @override
  Widget build(BuildContext context) {
    if (selected != null) {
      return Column(children: [
        Container(
          color: _white,
          padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.arrow_back_rounded, color: _ink), onPressed: onBack),
            _Avatar(initials: selected!.initials, color: selected!.avatarColor, size: 36),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(selected!.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _ink)),
              Text(selected!.role, style: const TextStyle(fontSize: 11, color: _muted)),
            ])),
          ]),
        ),
        const Divider(height: 1),
        Expanded(child: _ChatPanel(conv: selected!, msgCtrl: msgCtrl, onSend: onSend, hideHeader: true)),
      ]);
    }
    return _ConversationList(conversations: conversations, selected: null, onSelect: onSelect);
  }
}

// ── Conversation list ─────────────────────────────────────────────────────────
class _ConversationList extends StatelessWidget {
  final List<_Conversation> conversations;
  final _Conversation? selected;
  final ValueChanged<_Conversation> onSelect;
  const _ConversationList({required this.conversations, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        color: _white,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Row(children: [
          Container(width: 36, height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_sh1, _sh2]),
              borderRadius: BorderRadius.circular(10)),
            child: const Center(child: Icon(Icons.chat_rounded, color: _white, size: 18))),
          const SizedBox(width: 10),
          const Expanded(child: Text('Messagerie', style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w800, color: _ink))),
          Container(
            width: 22, height: 22,
            decoration: BoxDecoration(color: _terra, shape: BoxShape.circle),
            child: Center(child: Text(
              '${conversations.where((c) => c.unread).length}',
              style: const TextStyle(color: _white, fontSize: 10, fontWeight: FontWeight.w800))),
          ),
        ]),
      ),
      const Divider(height: 1),
      Expanded(child: ListView.separated(
        itemCount: conversations.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 70),
        itemBuilder: (_, i) {
          final c = conversations[i];
          final sel = c.id == selected?.id;
          return _ConvItem(conv: c, selected: sel, onTap: () => onSelect(c));
        },
      )),
    ]);
  }
}

class _ConvItem extends StatelessWidget {
  final _Conversation conv;
  final bool selected;
  final VoidCallback onTap;
  const _ConvItem({required this.conv, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final last = conv.last;
    final timeStr = last == null ? '' : _formatTime(last.time);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        color: selected ? _terra.withOpacity(.08) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Avatar(initials: conv.initials, color: conv.avatarColor, size: 42),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(conv.name, style: TextStyle(
                  fontSize: 13, fontWeight: conv.unread ? FontWeight.w800 : FontWeight.w600,
                  color: _ink), maxLines: 1, overflow: TextOverflow.ellipsis)),
              Text(timeStr, style: TextStyle(
                  fontSize: 10.5, color: conv.unread ? _terra : _muted,
                  fontWeight: conv.unread ? FontWeight.w700 : FontWeight.w400)),
            ]),
            const SizedBox(height: 2),
            Row(children: [
              Expanded(child: Text(last?.text ?? '', style: TextStyle(
                  fontSize: 12, color: conv.unread ? _ink : _muted,
                  fontWeight: conv.unread ? FontWeight.w600 : FontWeight.w400),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (conv.unread) Container(
                width: 8, height: 8, margin: const EdgeInsets.only(left: 6),
                decoration: const BoxDecoration(color: _terra, shape: BoxShape.circle),
              ),
            ]),
          ])),
        ]),
      ),
    );
  }
}

// ── Chat panel ─────────────────────────────────────────────────────────────────
class _ChatPanel extends StatefulWidget {
  final _Conversation conv;
  final TextEditingController msgCtrl;
  final VoidCallback onSend;
  final bool hideHeader;
  const _ChatPanel({
    required this.conv,
    required this.msgCtrl,
    required this.onSend,
    this.hideHeader = false,
  });
  @override
  State<_ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<_ChatPanel> {
  final _scroll = ScrollController();

  @override
  void didUpdateWidget(_ChatPanel old) {
    super.didUpdateWidget(old);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      if (!widget.hideHeader) _ChatHeader(conv: widget.conv),
      Expanded(child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.all(16),
        itemCount: widget.conv.messages.length,
        itemBuilder: (_, i) => _Bubble(msg: widget.conv.messages[i]),
      )),
      _MessageInput(ctrl: widget.msgCtrl, onSend: widget.onSend),
    ]);
  }
}

class _ChatHeader extends StatelessWidget {
  final _Conversation conv;
  const _ChatHeader({required this.conv});
  @override
  Widget build(BuildContext context) => Container(
    color: _white,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(children: [
      _Avatar(initials: conv.initials, color: conv.avatarColor, size: 38),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(conv.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _ink)),
        Text(conv.role, style: const TextStyle(fontSize: 11, color: _muted)),
      ]),
    ]),
  );
}

class _Bubble extends StatelessWidget {
  final _Message msg;
  const _Bubble({required this.msg});
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: msg.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: msg.isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .65),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: msg.isMine ? _terra : _white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: msg.isMine ? const Radius.circular(16) : const Radius.circular(4),
                  bottomRight: msg.isMine ? const Radius.circular(4) : const Radius.circular(16),
                ),
                border: msg.isMine ? null : Border.all(color: _border),
                boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 2))],
              ),
              child: Text(msg.text, style: TextStyle(
                  color: msg.isMine ? _white : _ink, fontSize: 13, height: 1.4)),
            ),
            const SizedBox(height: 3),
            Text(_formatTime(msg.time), style: const TextStyle(color: _muted, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _MessageInput extends StatelessWidget {
  final TextEditingController ctrl;
  final VoidCallback onSend;
  const _MessageInput({required this.ctrl, required this.onSend});
  @override
  Widget build(BuildContext context) => Container(
    color: _white,
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
    child: Row(children: [
      Expanded(child: TextField(
        controller: ctrl,
        style: const TextStyle(fontSize: 14, color: _ink),
        onSubmitted: (_) => onSend(),
        maxLines: null,
        decoration: InputDecoration(
          hintText: 'Écrire un message…',
          hintStyle: TextStyle(color: _muted.withOpacity(.5), fontSize: 13),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          filled: true,
          fillColor: _bg,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: const BorderSide(color: _border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: const BorderSide(color: _border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide(color: _terra, width: 1.5)),
        ),
      )),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: onSend,
        child: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: _terra, shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: _terra.withOpacity(.3), blurRadius: 8, offset: const Offset(0, 3))]),
          child: const Center(child: Icon(Icons.send_rounded, color: _white, size: 20)),
        ),
      ),
    ]),
  );
}

// ── Empty chat ─────────────────────────────────────────────────────────────────
class _EmptyChat extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.chat_bubble_outline_rounded, size: 56, color: _muted.withOpacity(.3)),
      const SizedBox(height: 12),
      const Text('Sélectionnez une conversation',
          style: TextStyle(color: _muted, fontSize: 14, fontWeight: FontWeight.w600)),
    ]),
  );
}

// ── Shared avatar ─────────────────────────────────────────────────────────────
class _Avatar extends StatelessWidget {
  final String initials;
  final Color color;
  final double size;
  const _Avatar({required this.initials, required this.color, required this.size});
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      color: color.withOpacity(.15), shape: BoxShape.circle,
      border: Border.all(color: color.withOpacity(.3)),
    ),
    child: Center(child: Text(initials, style: TextStyle(
        color: color, fontSize: size * .3, fontWeight: FontWeight.w900))),
  );
}

// ── Utils ─────────────────────────────────────────────────────────────────────
String _formatTime(DateTime t) {
  final now = DateTime.now();
  final diff = now.difference(t);
  if (diff.inMinutes < 1) return 'À l\'instant';
  if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';
  return '${t.day.toString().padLeft(2,'0')}/${t.month.toString().padLeft(2,'0')}';
}
