import 'package:flutter/material.dart';

import 'role_workspace_models.dart';

/// Organigramme des rôles : place chaque rôle sur une ligne selon son
/// niveau hiérarchique (Direction en haut → Support/Famille en bas) et relie
/// les rôles à leur "hérite de" par une courbe de Bézier, façon n8n.
class RoleOrgChart extends StatelessWidget {
  final List<RoleDraft> roles;
  final String? selectedDraftId;
  final ValueChanged<String> onSelect;
  const RoleOrgChart({super.key, required this.roles, required this.selectedDraftId, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final byLevel = <String, List<RoleDraft>>{for (final l in kRoleLevels) l: []};
    for (final r in roles) {
      // Un niveau inconnu (typo, accent manquant, valeur venue d'une autre
      // version) ne doit pas faire DISPARAÎTRE le rôle : le filtre ci-dessous
      // ne retient que les niveaux de kRoleLevels. On rabat sur le dernier.
      final level = byLevel.containsKey(r.level) ? r.level : kRoleLevels.last;
      byLevel[level]!.add(r);
    }
    final levels = kRoleLevels.where((l) => byLevel[l]!.isNotEmpty).toList();
    if (levels.isEmpty) return const SizedBox(height: 40);

    const rowH = 74.0;
    final height = levels.length * rowH + 24;

    // Largeur intrinsèque : l'organigramme vit dans un InteractiveViewer
    // (constrained: false) qui lui offre une largeur INFINIE. Les positions
    // étant calculées en fraction de la largeur (x = width * i / n), une
    // largeur infinie envoie tous les nœuds à l'infini — le cadre paraît vide
    // alors que les rôles sont bien là. On se calcule donc une largeur finie
    // à partir du niveau le plus peuplé.
    const nodeW = 150.0;
    final widest = levels
        .map((l) => byLevel[l]!.length)
        .fold<int>(1, (a, b) => a > b ? a : b);

    return LayoutBuilder(builder: (context, constraints) {
      final available = constraints.maxWidth;
      final width = available.isFinite
          ? (available < widest * nodeW ? widest * nodeW : available)
          : widest * nodeW;
      final positions = <String, Offset>{};
      for (var li = 0; li < levels.length; li++) {
        final items = byLevel[levels[li]]!;
        final y = 24 + li * rowH + rowH / 2;
        for (var i = 0; i < items.length; i++) {
          final x = width * (i + 1) / (items.length + 1);
          positions[items[i].draftId] = Offset(x, y);
        }
      }
      return SizedBox(
        height: height,
        width: width,
        child: Stack(children: [
          CustomPaint(
            size: Size(width, height),
            painter: _EdgePainter(roles: roles, positions: positions),
          ),
          for (final r in roles)
            if (positions[r.draftId] != null)
              Positioned(
                left: positions[r.draftId]!.dx,
                top: positions[r.draftId]!.dy,
                child: FractionalTranslation(
                  translation: const Offset(-0.5, -0.5),
                  child: _OrgNode(
                    role: r,
                    selected: r.draftId == selectedDraftId,
                    onTap: () => onSelect(r.draftId),
                  ),
                ),
              ),
        ]),
      );
    });
  }
}

class _EdgePainter extends CustomPainter {
  final List<RoleDraft> roles;
  final Map<String, Offset> positions;
  _EdgePainter({required this.roles, required this.positions});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB9A99A)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    for (final r in roles) {
      final parentId = r.parentDraftId;
      if (parentId == null) continue;
      final a = positions[parentId];
      final b = positions[r.draftId];
      if (a == null || b == null) continue;
      final midY = (a.dy + b.dy) / 2;
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..cubicTo(a.dx, midY, b.dx, midY, b.dx, b.dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _EdgePainter oldDelegate) =>
      oldDelegate.roles != roles || oldDelegate.positions != positions;
}

class _OrgNode extends StatelessWidget {
  final RoleDraft role;
  final bool selected;
  final VoidCallback onTap;
  const _OrgNode({required this.role, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = colorFromHex(role.color);
    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(.16) : Theme.of(context).colorScheme.surface,
          border: Border.all(color: selected ? color : Theme.of(context).colorScheme.outlineVariant, width: selected ? 1.4 : 1),
          borderRadius: BorderRadius.circular(9),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(role.name,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: selected ? color : Theme.of(context).colorScheme.onSurface,
              )),
        ]),
      ),
    );
  }
}
