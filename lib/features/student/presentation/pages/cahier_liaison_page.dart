import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/page_scaffold.dart';

const _terra  = ScolarisPalette.terracotta;
const _gold   = ScolarisPalette.gold;
const _green  = ScolarisPalette.forestGreen;
const _orange = ScolarisPalette.orange;
// Neutres (texte/fond/bordure) : jamais figés → `context.c*` (page_scaffold).
// Ces deux-là sont du texte posé sur un fond de marque coloré : ils restent
// constants, valables en clair comme en sombre.
const _white    = Colors.white;   // sur terracotta / couleur de type
const _onGold   = Color(0xFF1A0A00); // sur la pastille or

// ── Types de message ──────────────────────────────────────────────────────────
enum _MsgType { info, sortie, medicament, permission, felicitation, avertissement }

extension _MsgTypeX on _MsgType {
  String get label {
    switch (this) {
      case _MsgType.info: return 'Information';
      case _MsgType.sortie: return 'Sortie';
      case _MsgType.medicament: return 'Médicament';
      case _MsgType.permission: return 'Permission';
      case _MsgType.felicitation: return 'Félicitation';
      case _MsgType.avertissement: return 'Avertissement';
    }
  }

  Color get color {
    switch (this) {
      case _MsgType.info: return const Color(0xFF0891B2);
      case _MsgType.sortie: return const Color(0xFF6D28D9);
      case _MsgType.medicament: return const Color(0xFFDB2777);
      case _MsgType.permission: return _gold;
      case _MsgType.felicitation: return _green;
      case _MsgType.avertissement: return _terra;
    }
  }

  IconData get icon {
    switch (this) {
      case _MsgType.info: return Icons.info_rounded;
      case _MsgType.sortie: return Icons.directions_bus_rounded;
      case _MsgType.medicament: return Icons.medical_services_rounded;
      case _MsgType.permission: return Icons.event_available_rounded;
      case _MsgType.felicitation: return Icons.emoji_events_rounded;
      case _MsgType.avertissement: return Icons.warning_amber_rounded;
    }
  }
}

class _Message {
  final String titre;
  final String contenu;
  final String date;
  final String auteur;
  final _MsgType type;
  final bool lu;
  const _Message({
    required this.titre, required this.contenu, required this.date,
    required this.auteur, required this.type, this.lu = false,
  });
}

const _messages = [
  _Message(
    type: _MsgType.felicitation, lu: false,
    titre: 'Bravo pour ton tableau d\'honneur !',
    contenu: 'Chère famille, nous avons le plaisir de vous informer que votre enfant a été classé au tableau d\'honneur du 2e trimestre avec une moyenne de 8,5/10. Félicitations !',
    date: 'Aujourd\'hui 09h15', auteur: 'Direction',
  ),
  _Message(
    type: _MsgType.sortie, lu: false,
    titre: 'Sortie scolaire — Zoo de Brazzaville',
    contenu: 'Une sortie pédagogique est organisée le vendredi 4 juillet au Zoo de Brazzaville. Coût : 2 000 FCFA. Merci de signer l\'autorisation jointe et de remettre le règlement avant le 1er juillet.',
    date: 'Hier 14h30', auteur: 'M. Moanda - CE1',
  ),
  _Message(
    type: _MsgType.medicament, lu: true,
    titre: 'Administration de médicaments',
    contenu: 'Votre enfant a reçu du paracétamol (250mg) ce matin à 10h suite à une légère fièvre (37,8°). Il se porte bien. Merci de consulter un médecin si les symptômes persistent.',
    date: 'Lun 23 Jun', auteur: 'Infirmerie',
  ),
  _Message(
    type: _MsgType.info, lu: true,
    titre: 'Réunion parents-enseignants',
    contenu: 'Nous vous rappelons que la réunion parents-enseignants du 3e trimestre aura lieu le samedi 5 juillet de 9h à 12h. Votre présence est vivement souhaitée.',
    date: 'Ven 20 Jun', auteur: 'Direction',
  ),
  _Message(
    type: _MsgType.permission, lu: true,
    titre: 'Autorisation de sortie validée',
    contenu: 'L\'autorisation de sortie anticipée du 18 juin (rendez-vous médical) a bien été enregistrée. Votre enfant sera libéré à 11h30.',
    date: 'Mar 17 Jun', auteur: 'Secrétariat',
  ),
  _Message(
    type: _MsgType.avertissement, lu: true,
    titre: 'Retards répétés',
    contenu: 'Nous avons constaté 3 retards de votre enfant cette semaine. Nous vous demandons de veiller à son heure d\'arrivée (7h45 au plus tard). Merci de votre compréhension.',
    date: 'Lun 16 Jun', auteur: 'M. Moanda - CE1',
  ),
];

// ── Page principale ───────────────────────────────────────────────────────────
class CahierLiaisonPage extends StatefulWidget {
  const CahierLiaisonPage({super.key});
  @override
  State<CahierLiaisonPage> createState() => _CahierLiaisonPageState();
}

class _CahierLiaisonPageState extends State<CahierLiaisonPage> {
  _MsgType? _filtre;

  List<_Message> get _filtered => _messages
      .where((m) => _filtre == null || m.type == _filtre)
      .toList();

  int get _nonLus => _messages.where((m) => !m.lu).length;

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return PageScaffold(
      title: 'Cahier de liaison',
      subtitle: _nonLus > 0 ? '$_nonLus message(s) non lu(s)' : 'Tous les messages lus',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Résumé coloré ───────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A0500), _terra],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: _white.withOpacity(.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.import_contacts_rounded, color: _white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Cahier de liaison numérique',
                  style: TextStyle(color: _white, fontSize: 14, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text('${_messages.length} messages · Classe CE1 · M. Moanda',
                  style: TextStyle(color: _white.withOpacity(.7), fontSize: 11)),
            ])),
            if (_nonLus > 0)
              Container(
                width: 28, height: 28,
                decoration: const BoxDecoration(color: _gold, shape: BoxShape.circle),
                child: Center(child: Text('$_nonLus',
                    style: const TextStyle(color: _onGold, fontSize: 12, fontWeight: FontWeight.w900))),
              ),
          ]),
        ),
        const SizedBox(height: 14),

        // ── Filtres type ────────────────────────────────────────────────────
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _FilterChip(
                label: 'Tous',
                color: _terra,
                selected: _filtre == null,
                onTap: () => setState(() => _filtre = null),
              ),
              const SizedBox(width: 6),
              ..._MsgType.values.map((t) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _FilterChip(
                  label: t.label,
                  color: t.color,
                  selected: _filtre == t,
                  onTap: () => setState(() => _filtre = _filtre == t ? null : t),
                ),
              )),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── Liste messages ──────────────────────────────────────────────────
        if (filtered.isEmpty)
          const EmptyState(
            icon: Icons.import_contacts_outlined,
            title: 'Aucun message',
            description: 'Aucun message pour ce filtre.',
          )
        else
          ...filtered.map((m) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _MessageCard(msg: m),
          )),
      ]),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.color, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? color : context.cCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? color : context.cBorder),
      ),
      child: Text(label, style: TextStyle(
          color: selected ? _white : context.cMuted,
          fontSize: 11.5, fontWeight: FontWeight.w600)),
    ),
  );
}

// ── Carte message ─────────────────────────────────────────────────────────────
class _MessageCard extends StatefulWidget {
  final _Message msg;
  const _MessageCard({required this.msg});
  @override
  State<_MessageCard> createState() => _MessageCardState();
}

class _MessageCardState extends State<_MessageCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.msg;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: m.lu ? context.cCard : m.type.color.withOpacity(.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: m.lu ? context.cBorder : m.type.color.withOpacity(.35),
            width: m.lu ? 1 : 1.5),
      ),
      child: Column(children: [
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: m.type.color.withOpacity(.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(m.type.icon, color: m.type.color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: m.type.color.withOpacity(.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(m.type.label, style: TextStyle(
                        fontSize: 9.5, fontWeight: FontWeight.w700, color: m.type.color)),
                  ),
                  const Spacer(),
                  Text(m.date, style: TextStyle(fontSize: 10, color: context.cMuted)),
                ]),
                const SizedBox(height: 5),
                Row(children: [
                  if (!m.lu) Container(
                    width: 8, height: 8,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(color: m.type.color, shape: BoxShape.circle),
                  ),
                  Expanded(child: Text(m.titre, style: TextStyle(
                      fontSize: 13, fontWeight: m.lu ? FontWeight.w600 : FontWeight.w800,
                      color: context.cInk))),
                ]),
                const SizedBox(height: 3),
                Text(m.auteur, style: TextStyle(fontSize: 10.5, color: context.cMuted)),
              ])),
              const SizedBox(width: 6),
              Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  size: 18, color: context.cMuted),
            ]),
          ),
        ),
        if (_expanded)
          Container(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(height: 1, color: context.cBorder,
                  margin: const EdgeInsets.only(bottom: 10)),
              Text(m.contenu,
                  style: TextStyle(fontSize: 13, color: context.cInk, height: 1.6)),
            ]),
          ),
      ]),
    );
  }
}
