import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/user_entity.dart';
import '../pages/help_page.dart';
import '../widgets/responsive_role_shell.dart';

const _terra  = Color(0xFF8B1A00);
const _orange = Color(0xFFD4540A);

/// Drawer mobile theme-aware — couleurs depuis le thème actif.
class CurvedDrawer extends StatelessWidget {
  final List<RoleNavEntry> entries;
  final String currentLabelKey;
  final AppUser? user;
  final ValueChanged<RoleNavEntry> onSelect;
  const CurvedDrawer({
    super.key,
    required this.entries,
    required this.currentLabelKey,
    required this.user,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: PhysicalShape(
          color: cs.surface,
          elevation: 8,
          shadowColor: Colors.black26,
          clipper: _CurvedShapeClipper(),
          child: SizedBox(
            width: 220,
            child: _DrawerBody(
              entries: entries,
              currentLabelKey: currentLabelKey,
              user: user,
              onSelect: onSelect,
            ),
          ),
        ),
      ),
    );
  }
}

class _CurvedShapeClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const radius = 28.0;
    final p = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width - radius, 0)
      ..quadraticBezierTo(size.width, 0, size.width, radius)
      ..lineTo(size.width, size.height - radius)
      ..quadraticBezierTo(
          size.width, size.height, size.width - radius, size.height)
      ..lineTo(0, size.height)
      ..close();
    return p;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _DrawerBody extends StatelessWidget {
  final List<RoleNavEntry> entries;
  final String currentLabelKey;
  final AppUser? user;
  final ValueChanged<RoleNavEntry> onSelect;
  const _DrawerBody({
    required this.entries,
    required this.currentLabelKey,
    required this.user,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final initials = (user?.fullName.isNotEmpty ?? false)
        ? user!.fullName
            .split(' ')
            .map((w) => w.isNotEmpty ? w[0] : '')
            .take(2)
            .join()
            .toUpperCase()
        : '?';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        // ── Brand row ───────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/logo.png',
                width: 28, height: 28, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: _terra,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text('S', style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text('Scolaris', style: TextStyle(
                color: _terra, fontWeight: FontWeight.w800, fontSize: 14)),
          ]),
        ),
        // ── User card ────────────────────────────────────────────────────
        if (user != null) ...[
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outline.withOpacity(.3)),
              ),
              child: Row(children: [
                Container(
                  width: 30, height: 30,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_terra, _orange],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(initials, style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user!.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface)),
                      Text(user!.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 10.5,
                              color: cs.onSurface.withOpacity(.5))),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 16, 6),
          child: Text('NAVIGATION',
              style: TextStyle(
                  fontSize: 9.5,
                  color: cs.onSurface.withOpacity(.4),
                  fontWeight: FontWeight.w800, letterSpacing: 1.2)),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            children: [
              for (final e in entries)
                _DrawerItem(
                  entry: e,
                  selected: e.labelKey == currentLabelKey,
                  onTap: () => onSelect(e),
                ),
            ],
          ),
        ),
        Container(height: 1, color: cs.outline.withOpacity(.15)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(9),
              onTap: () => Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(builder: (_) => const HelpPage()),
              ),
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(children: [
                  Icon(Icons.help_outline_rounded,
                      size: 16, color: cs.onSurface.withOpacity(.55)),
                  const SizedBox(width: 10),
                  Text('Aide & démarrage',
                      style: TextStyle(
                          color: cs.onSurface, fontSize: 12.5, fontWeight: FontWeight.w500)),
                ]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final RoleNavEntry entry;
  final bool selected;
  final VoidCallback onTap;
  const _DrawerItem({
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Material(
        color: selected ? _terra.withOpacity(.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(children: [
              Icon(entry.icon,
                  size: 16,
                  color: selected ? _terra : cs.onSurface.withOpacity(.55)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  entry.labelKey.tr(),
                  style: TextStyle(
                    color: selected ? _terra : cs.onSurface,
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (selected)
                Container(
                  width: 5, height: 5,
                  decoration: const BoxDecoration(
                      color: _terra, shape: BoxShape.circle),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}
