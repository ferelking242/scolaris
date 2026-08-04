import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/page_scaffold.dart';
import '../../data/platform_announcement.dart';
import '../../data/platform_mock_data.dart';
import '../../data/platform_repository.dart';
import '../platform_providers.dart';
import '../widgets/platform_search.dart';

/// Diffusion d'annonces aux écoles (maintenance, nouveautés, rappels) — vraie
/// table `platform_announcements`, lue par chaque école via
/// `my_platform_announcements()` (bannière dans son tableau de bord).
class PlatformAnnouncementsPage extends ConsumerStatefulWidget {
  const PlatformAnnouncementsPage({super.key});
  @override
  ConsumerState<PlatformAnnouncementsPage> createState() =>
      _PlatformAnnouncementsPageState();
}

class _PlatformAnnouncementsPageState
    extends ConsumerState<PlatformAnnouncementsPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  AnnouncementAudience _audience = AnnouncementAudience.all;
  AnnouncementKind _kind = AnnouncementKind.info;
  Duration? _expiry;
  bool _publishing = false;

  static const _expiryChoices = <String, Duration?>{
    'Sans expiration': null,
    '24 h': Duration(hours: 24),
    '7 jours': Duration(days: 7),
    '30 jours': Duration(days: 30),
  };

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _publish(List<PlatformSchool> schools) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final reach = _audience.reachAmong(schools);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _publishing = true);
    try {
      await PlatformRepository.publishAnnouncement(
        title: _title.text,
        body: _body.text,
        kind: _kind,
        audience: _audience,
        reach: reach,
        expiresAt: _expiry == null ? null : DateTime.now().add(_expiry!),
      );
      ref.invalidate(platformAnnouncementsProvider);
      setState(() {
        _title.clear();
        _body.clear();
        _audience = AnnouncementAudience.all;
        _kind = AnnouncementKind.info;
        _expiry = null;
      });
      messenger.showSnackBar(SnackBar(
        content: Text('Annonce diffusée à $reach école${reach > 1 ? 's' : ''}.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: ScolarisPalette.forestGreen,
        duration: const Duration(seconds: 2),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Échec : $e'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: ScolarisPalette.terracotta,
      ));
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  Future<void> _unpublish(PlatformAnnouncement item) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await PlatformRepository.unpublishAnnouncement(item.id);
      ref.invalidate(platformAnnouncementsProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Échec : $e'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: ScolarisPalette.terracotta,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final schoolsAsync = ref.watch(platformSchoolsProvider);
    final historyAsync = ref.watch(platformAnnouncementsProvider);
    final schools = schoolsAsync.valueOrNull ?? const <PlatformSchool>[];

    return PageScaffold(
      title: 'Annonces',
      onRefresh: () async {
        ref.invalidate(platformSchoolsProvider);
        ref.invalidate(platformAnnouncementsProvider);
        await Future.wait([
          ref.read(platformSchoolsProvider.future),
          ref.read(platformAnnouncementsProvider.future),
        ]);
      },
      subtitle: 'Diffuser un message aux écoles de la plateforme',
      actions: const [PlatformSearchLauncher()],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Composeur ────────────────────────────────────────────────────
        DataPanel(
          title: 'Nouvelle annonce',
          child: Form(
            key: _formKey,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _Field(
                controller: _title,
                label: 'Titre',
                hint: 'Ex. Maintenance planifiée samedi',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requis' : null,
              ),
              _Field(
                controller: _body,
                label: 'Message',
                hint: 'Rédige le contenu de l\'annonce…',
                maxLines: 4,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requis' : null,
              ),
              const SizedBox(height: 4),
              const _FieldLabel(label: 'Type'),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final k in AnnouncementKind.values)
                  _ChoicePill(
                    label: k.label,
                    icon: k.icon,
                    color: k.color,
                    selected: _kind == k,
                    onTap: () => setState(() => _kind = k),
                  ),
              ]),
              const SizedBox(height: 14),
              const _FieldLabel(label: 'Destinataires'),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final a in AnnouncementAudience.values)
                  _ChoicePill(
                    label: '${a.label} · ${a.reachAmong(schools)}',
                    icon: Icons.groups_rounded,
                    color: ScolarisPalette.terracotta,
                    selected: _audience == a,
                    onTap: () => setState(() => _audience = a),
                  ),
              ]),
              const SizedBox(height: 14),
              const _FieldLabel(label: 'Expiration'),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final entry in _expiryChoices.entries)
                  _ChoicePill(
                    label: entry.key,
                    icon: Icons.timer_outlined,
                    color: ScolarisPalette.terracotta,
                    selected: _expiry == entry.value,
                    onTap: () => setState(() => _expiry = entry.value),
                  ),
              ]),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerRight,
                child: ActionButton(
                  label: _publishing
                      ? 'Diffusion…'
                      : 'Diffuser à ${_audience.reachAmong(schools)} '
                          'école${_audience.reachAmong(schools) > 1 ? 's' : ''}',
                  icon: Icons.send_rounded,
                  primary: true,
                  onTap: _publishing ? () {} : () => _publish(schools),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 14),

        // ── Historique ───────────────────────────────────────────────────
        DataPanel(
          title: 'Annonces diffusées',
          headerActions: historyAsync.maybeWhen(
            data: (history) => [
              Text('${history.length} au total',
                  style: TextStyle(fontSize: 11.5, color: context.cMuted)),
            ],
            orElse: () => const [],
          ),
          child: historyAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Erreur : $e', style: TextStyle(color: context.cMuted)),
            ),
            data: (history) => history.isEmpty
                ? const EmptyState(
                    icon: Icons.campaign_outlined,
                    title: 'Aucune annonce',
                    description: 'Diffuse ta première annonce ci-dessus.')
                : Column(children: [
                    for (var i = 0; i < history.length; i++) ...[
                      _AnnouncementTile(
                        item: history[i],
                        onUnpublish: history[i].isActive
                            ? () => _unpublish(history[i])
                            : null,
                      ),
                      if (i < history.length - 1)
                        Divider(
                            height: 20,
                            color: context.cBorder.withValues(alpha: .5)),
                    ],
                  ]),
          ),
        ),
      ]),
    );
  }
}

// ── Tuile d'annonce (historique) ──────────────────────────────────────────────
class _AnnouncementTile extends StatelessWidget {
  final PlatformAnnouncement item;

  /// null = déjà inactive (expirée ou dépubliée) : pas de bouton à afficher.
  final VoidCallback? onUnpublish;

  const _AnnouncementTile({required this.item, this.onUnpublish});

  static String _fmt(DateTime d) {
    const m = [
      'jan.', 'fév.', 'mar.', 'avr.', 'mai', 'juin',
      'juil.', 'août', 'sep.', 'oct.', 'nov.', 'déc.',
    ];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final inactive = !item.isActive;
    return Opacity(
      opacity: inactive ? .55 : 1,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: item.kind.color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(item.kind.icon, size: 17, color: item.kind.color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.title,
                style: TextStyle(
                    fontSize: 13,
                    color: context.cInk,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(item.body,
                style: TextStyle(
                    fontSize: 12, color: context.cMuted, height: 1.35)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              _Tag(label: item.kind.label, color: item.kind.color),
              _Tag(
                  label: '${item.audience.label} · ${item.reach}',
                  color: ScolarisPalette.terracotta),
              if (item.archivedAt != null)
                const _Tag(label: 'Dépubliée', color: Colors.grey)
              else if (item.expiresAt != null)
                _Tag(
                    label: item.isActive
                        ? 'Expire le ${_fmt(item.expiresAt!)}'
                        : 'Expirée',
                    color: item.isActive ? Colors.blueGrey : Colors.grey),
              Text(_fmt(item.date),
                  style: TextStyle(fontSize: 11, color: context.cMuted)),
            ]),
          ]),
        ),
        if (onUnpublish != null)
          IconButton(
            onPressed: onUnpublish,
            icon: const Icon(Icons.campaign_outlined, size: 17),
            color: ScolarisPalette.terracotta,
            tooltip: 'Dépublier',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
          ),
      ]),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag({required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, color: color, fontWeight: FontWeight.w700)),
    );
  }
}

// ── Pilule de choix (type / destinataires) ────────────────────────────────────
class _ChoicePill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _ChoicePill({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withValues(alpha: .10) : context.cCard,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: selected ? color : context.cBorder,
                width: selected ? 1.6 : 1),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: selected ? color : context.cMuted),
            const SizedBox(width: 7),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: selected ? color : context.cMuted,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
          ]),
        ),
      ),
    );
  }
}

// ── Libellé + champ (réutilisés localement) ───────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(label.toUpperCase(),
          style: TextStyle(
              fontSize: 9,
              color: context.cMuted,
              fontWeight: FontWeight.w700,
              letterSpacing: .6)),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;
  final String? Function(String?)? validator;
  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
    this.validator,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _FieldLabel(label: label),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          maxLines: maxLines,
          style: TextStyle(fontSize: 13, color: context.cInk, height: 1.35),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
                fontSize: 12.5, color: context.cMuted.withValues(alpha: .6)),
            isDense: true,
            filled: true,
            fillColor: context.cSubtle,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: context.cBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: ScolarisPalette.terracotta, width: 1.6),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: ScolarisPalette.terracotta),
            ),
          ),
        ),
      ]),
    );
  }
}
