import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';

class MessagesPage extends ConsumerWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final msgsAsync = ref.watch(messagesProvider);
    return msgsAsync.when(
      loading: () => const PageScaffold(
        title: 'Messages',
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => PageScaffold(
        title: 'Messages',
        child: Center(child: Text('Erreur : $e')),
      ),
      data: (msgs) => PageScaffold(
        title: 'Messages',
        subtitle: '${msgs.where((m) => !m.isRead).length} non lu(s)',
        actions: [
          ActionButton(
              label: 'Composer',
              icon: Icons.edit_outlined,
              primary: true,
              onTap: () {}),
        ],
        child: msgs.isEmpty
            ? _empty()
            : DataPanel(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < msgs.length; i++) ...[
                      if (i > 0) const Divider(height: 1, color: border),
                      _MessageRow(msg: msgs[i]),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  static Widget _empty() => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.mail_outline_rounded, size: 48, color: muted),
              SizedBox(height: 12),
              Text('Aucun message',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ink)),
              SizedBox(height: 4),
              Text('Vos messages apparaîtront ici.',
                  style: TextStyle(fontSize: 13, color: muted)),
            ],
          ),
        ),
      );
}

class _MessageRow extends StatelessWidget {
  final SbMessage msg;
  const _MessageRow({required this.msg});

  @override
  Widget build(BuildContext context) {
    final sender = msg.senderName ?? 'Inconnu';
    final timeStr = msg.createdAt != null
        ? DateFormat('HH:mm').format(msg.createdAt!)
        : '';
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Avatar(name: sender, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(sender,
                      style: TextStyle(
                          fontSize: 13,
                          color: ink,
                          fontWeight: msg.isRead
                              ? FontWeight.w500
                              : FontWeight.w700)),
                  const Spacer(),
                  Text(timeStr,
                      style: const TextStyle(fontSize: 11, color: muted)),
                ]),
                const SizedBox(height: 2),
                Text(
                  msg.content ?? '(message vide)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12,
                      color: msg.isRead ? muted : ink),
                ),
              ],
            ),
          ),
          if (!msg.isRead) ...[
            const SizedBox(width: 8),
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF8B1A00),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}
