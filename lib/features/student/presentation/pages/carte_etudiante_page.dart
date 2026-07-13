import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../presentation/providers/auth_providers.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';

const _terra = ScolarisPalette.terracotta;
const _gold  = ScolarisPalette.gold;

// ── Page principale ───────────────────────────────────────────────────────────
class CarteEtudiantePage extends ConsumerWidget {
  const CarteEtudiantePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs      = Theme.of(context).colorScheme;
    final user    = ref.watch(authSessionProvider);
    final profile = ref.watch(myStudentProfileProvider).valueOrNull;
    final school  = ref.watch(schoolProvider).valueOrNull;

    final name     = user?.fullName ?? 'Étudiant';
    final initials = _initials(name);
    final classe   = profile?.classe ?? '—';
    final niveau   = profile?.niveau ?? '—';
    final matricule = profile?.matricule ?? '—';
    final schoolName = school?.name ?? '—';
    final year    = school?.academicYear ?? '—';
    final qrCode  = 'SCO-${user?.id?.substring(0, 8).toUpperCase() ?? "ABCDEF12"}';

    return PageScaffold(
      title: 'Carte étudiante',
      subtitle: 'Identifiant scolaire numérique',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Carte physique ────────────────────────────────────────────────────
        _StudentCard(name: name, initials: initials, classe: classe, year: year, qrCode: qrCode),
        const SizedBox(height: 20),

        // ── QR Code simulé ────────────────────────────────────────────────────
        Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cs.outlineVariant),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(children: [
              Text('QR Code d\'accès',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: cs.onSurface)),
              const SizedBox(height: 4),
              Text('Valable jusqu\'au 31 Août ${_nextAugust()}',
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              const SizedBox(height: 16),
              _QrWidget(data: qrCode),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(qrCode,
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w900,
                        color: cs.onSurface, letterSpacing: 2)),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 20),

        // ── Accès autorisés ───────────────────────────────────────────────────
        _SectionHeader(title: 'Accès autorisés', cs: cs),
        const SizedBox(height: 10),
        const _AccesGrid(),
        const SizedBox(height: 20),

        // ── Infos académiques ─────────────────────────────────────────────────
        _SectionHeader(title: 'Informations académiques', cs: cs),
        const SizedBox(height: 10),
        _InfoCard(
          schoolName: schoolName,
          classe: classe,
          niveau: niveau,
          matricule: matricule,
          year: year,
        ),
      ]),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'E';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  String _nextAugust() {
    final now = DateTime.now();
    return now.month >= 9 ? '${now.year + 1}' : '${now.year}';
  }
}

// ── Carte physique ────────────────────────────────────────────────────────────
class _StudentCard extends StatelessWidget {
  final String name, initials, classe, year, qrCode;
  const _StudentCard({
    required this.name, required this.initials,
    required this.classe, required this.year, required this.qrCode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF1A0500), Color(0xFF5A1200), _terra],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: _terra.withOpacity(.4), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: Stack(children: [
        Positioned(right: -20, top: -20, child: Container(
          width: 120, height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(.06),
          ),
        )),
        Positioned(right: 30, bottom: -30, child: Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _gold.withOpacity(.1),
          ),
        )),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.school_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              const Text('SCOLARIS', style: TextStyle(
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _gold,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(year, style: const TextStyle(
                    color: Color(0xFF1A0A00), fontSize: 9, fontWeight: FontWeight.w800)),
              ),
            ]),
            const Spacer(),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _gold,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Center(child: Text(initials,
                    style: const TextStyle(color: Color(0xFF1A0A00), fontSize: 20, fontWeight: FontWeight.w900))),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(classe, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                const SizedBox(height: 2),
                Text('N° : $qrCode', style: const TextStyle(
                    color: Colors.white54, fontSize: 10, letterSpacing: .5)),
              ])),
            ]),
            const SizedBox(height: 6),
            Container(height: 4, decoration: BoxDecoration(
              color: _gold.withOpacity(.4),
              borderRadius: BorderRadius.circular(2),
            )),
          ]),
        ),
      ]),
    );
  }
}

// ── QR simulé (pattern géométrique) ─────────────────────────────────────────
class _QrWidget extends StatelessWidget {
  final String data;
  const _QrWidget({required this.data});
  @override
  Widget build(BuildContext context) => SizedBox(
      width: 160, height: 160,
      child: CustomPaint(painter: _QrPainter(data: data)));
}

class _QrPainter extends CustomPainter {
  final String data;
  _QrPainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    const darkColor = Color(0xFF1A0A00);
    final paint = Paint()..color = darkColor..style = PaintingStyle.fill;
    final bg    = Paint()..color = Colors.white..style = PaintingStyle.fill;
    canvas.drawRect(Offset.zero & size, bg);
    final cell = size.width / 21;
    final rng  = math.Random(data.hashCode);
    _drawMarker(canvas, paint, 0, 0, cell);
    _drawMarker(canvas, paint, 14, 0, cell);
    _drawMarker(canvas, paint, 0, 14, cell);
    for (var r = 0; r < 21; r++) {
      for (var c = 0; c < 21; c++) {
        if (_isMarker(r, c)) continue;
        if (rng.nextBool()) {
          canvas.drawRect(
            Rect.fromLTWH(c * cell + 1, r * cell + 1, cell - 2, cell - 2), paint);
        }
      }
    }
  }

  void _drawMarker(Canvas c, Paint p, int col, int row, double cell) {
    const darkColor = Color(0xFF1A0A00);
    final outer  = Paint()..color = darkColor..style = PaintingStyle.fill;
    final inner  = Paint()..color = Colors.white..style = PaintingStyle.fill;
    final center = Paint()..color = darkColor..style = PaintingStyle.fill;
    c.drawRect(Rect.fromLTWH(col * cell, row * cell, 7 * cell, 7 * cell), outer);
    c.drawRect(Rect.fromLTWH((col + 1) * cell, (row + 1) * cell, 5 * cell, 5 * cell), inner);
    c.drawRect(Rect.fromLTWH((col + 2) * cell, (row + 2) * cell, 3 * cell, 3 * cell), center);
  }

  bool _isMarker(int r, int c) =>
      (r < 8 && c < 8) || (r < 8 && c > 12) || (r > 12 && c < 8);

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Grille accès ─────────────────────────────────────────────────────────────
class _AccesGrid extends StatelessWidget {
  const _AccesGrid();

  static const _acces = [
    (icon: Icons.local_library_rounded,  label: 'Bibliothèque',  color: _terra),
    (icon: Icons.restaurant_rounded,     label: 'Cantine',       color: Color(0xFF059669)),
    (icon: Icons.quiz_rounded,           label: 'Examens',       color: _gold),
    (icon: Icons.computer_rounded,       label: 'Labo Info',     color: Color(0xFF6D28D9)),
    (icon: Icons.sports_rounded,         label: 'Sport',         color: Color(0xFF0EA5E9)),
    (icon: Icons.wifi_rounded,           label: 'Wi-Fi campus',  color: Color(0xFF0891B2)),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.1,
      children: _acces.map((a) => Container(
        decoration: BoxDecoration(
          color: a.color.withOpacity(.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: a.color.withOpacity(.2)),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(a.icon, color: a.color, size: 24),
          const SizedBox(height: 6),
          Text(a.label, style: TextStyle(
              fontSize: 10.5, fontWeight: FontWeight.w700, color: a.color),
              textAlign: TextAlign.center),
        ]),
      )).toList(),
    );
  }
}

// ── Info card ─────────────────────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final String schoolName, classe, niveau, matricule, year;
  const _InfoCard({
    required this.schoolName, required this.classe, required this.niveau,
    required this.matricule, required this.year,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rows = [
      ('Établissement', schoolName),
      ('Classe / Niveau', '$classe · $niveau'),
      ('N° Matricule', matricule),
      ('Année académique', year),
      ('Statut', 'Élève régulier(e)'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(children: rows.asMap().entries.map((e) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: e.key > 0 ? Border(top: BorderSide(color: cs.outlineVariant)) : null,
        ),
        child: Row(children: [
          Text(e.value.$1, style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(e.value.$2, style: TextStyle(fontSize: 12.5, color: cs.onSurface, fontWeight: FontWeight.w700)),
        ]),
      )).toList()),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final ColorScheme cs;
  const _SectionHeader({required this.title, required this.cs});
  @override
  Widget build(BuildContext context) => Text(title,
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: cs.onSurface));
}
