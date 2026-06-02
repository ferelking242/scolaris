import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ══════════════════════════════════════════════════════════════════════════
// Modèle image simulée
// ══════════════════════════════════════════════════════════════════════════
class _Img {
  final String title;
  final String subtitle;
  final Color color;
  final Color colorEnd;
  final IconData icon;
  final String type;
  final String size;
  final String date;
  const _Img({
    required this.title, required this.subtitle,
    required this.color, required this.colorEnd,
    required this.icon, required this.type,
    required this.size, required this.date,
  });
}

const _gallery = [
  _Img(
    title: 'Schéma — La Cellule Végétale',
    subtitle: 'SVT · 5e A · Dr. Yao',
    color: Color(0xFF1B5E20), colorEnd: Color(0xFF43A047),
    icon: Icons.biotech_rounded, type: 'Schéma',
    size: '2.4 MB', date: '28 Mai 2026',
  ),
  _Img(
    title: 'Carte — L\'Afrique Politique',
    subtitle: 'Géographie · 5e A · M. Kabamba',
    color: Color(0xFF4E342E), colorEnd: Color(0xFF8D6E63),
    icon: Icons.map_rounded, type: 'Carte',
    size: '4.1 MB', date: '22 Mai 2026',
  ),
  _Img(
    title: 'Diagramme — Cycle de l\'Eau',
    subtitle: 'SVT · 5e A · Dr. Yao',
    color: Color(0xFF0277BD), colorEnd: Color(0xFF29B6F6),
    icon: Icons.water_drop_rounded, type: 'Diagramme',
    size: '1.8 MB', date: '18 Mai 2026',
  ),
  _Img(
    title: 'Graphique — Fonctions du 2nd Degré',
    subtitle: 'Mathématiques · 5e A · M. Dupont',
    color: Color(0xFF4527A0), colorEnd: Color(0xFF7B1FA2),
    icon: Icons.show_chart_rounded, type: 'Graphique',
    size: '0.9 MB', date: '15 Mai 2026',
  ),
  _Img(
    title: 'Tableau périodique des éléments',
    subtitle: 'Physique-Chimie · 5e A · Mme Lefèvre',
    color: Color(0xFF880E4F), colorEnd: Color(0xFFC2185B),
    icon: Icons.science_rounded, type: 'Tableau',
    size: '3.6 MB', date: '10 Mai 2026',
  ),
  _Img(
    title: 'Frise chronologique — Guerres mondiales',
    subtitle: 'Histoire · 5e A · M. Kabamba',
    color: Color(0xFFBF360C), colorEnd: Color(0xFFE64A19),
    icon: Icons.timeline_rounded, type: 'Frise',
    size: '2.2 MB', date: '8 Mai 2026',
  ),
  _Img(
    title: 'Schéma — Circuit électrique simple',
    subtitle: 'Physique · 5e A · Mme Lefèvre',
    color: Color(0xFF1565C0), colorEnd: Color(0xFF0288D1),
    icon: Icons.electrical_services_rounded, type: 'Schéma',
    size: '1.1 MB', date: '5 Mai 2026',
  ),
  _Img(
    title: 'Plan — Anatomie du cœur humain',
    subtitle: 'SVT · 5e A · Dr. Yao',
    color: Color(0xFFC62828), colorEnd: Color(0xFFEF5350),
    icon: Icons.favorite_rounded, type: 'Plan',
    size: '5.2 MB', date: '2 Mai 2026',
  ),
];

// ══════════════════════════════════════════════════════════════════════════
// ImageViewerPage
// ══════════════════════════════════════════════════════════════════════════
class ImageViewerPage extends StatefulWidget {
  final int initialIndex;
  final String? title;
  const ImageViewerPage({super.key, this.initialIndex = 0, this.title});

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage>
    with TickerProviderStateMixin {
  late int _idx;
  bool _showUI = true;
  bool _showInfo = false;
  final _transformCtrl = TransformationController();
  late AnimationController _uiAnim;
  late AnimationController _infoAnim;
  late PageController _pageCtrl;
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _idx = widget.initialIndex.clamp(0, _gallery.length - 1);
    _uiAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200))
      ..value = 1.0;
    _infoAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _pageCtrl = PageController(initialPage: _idx);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _uiAnim.dispose();
    _infoAnim.dispose();
    _pageCtrl.dispose();
    _transformCtrl.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleUI() {
    setState(() => _showUI = !_showUI);
    if (_showUI) _uiAnim.forward(); else _uiAnim.reverse();
  }

  void _toggleInfo() {
    setState(() => _showInfo = !_showInfo);
    if (_showInfo) _infoAnim.forward(); else _infoAnim.reverse();
  }

  _Img get _img => _gallery[_idx];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [

        // ── Gallery PageView ───────────────────────────────────────
        PageView.builder(
          controller: _pageCtrl,
          physics: _zoomed
              ? const NeverScrollableScrollPhysics()
              : const BouncingScrollPhysics(),
          onPageChanged: (i) {
            setState(() {
              _idx = i;
              _zoomed = false;
              _transformCtrl.value = Matrix4.identity();
            });
          },
          itemCount: _gallery.length,
          itemBuilder: (_, i) {
            final img = _gallery[i];
            return GestureDetector(
              onTap: _toggleUI,
              onDoubleTap: () {
                if (_zoomed) {
                  _transformCtrl.value = Matrix4.identity();
                  setState(() => _zoomed = false);
                } else {
                  _transformCtrl.value = Matrix4.identity()
                    ..scale(2.5)
                    ..translate(-80.0, -120.0);
                  setState(() => _zoomed = true);
                }
              },
              child: InteractiveViewer(
                transformationController: _transformCtrl,
                minScale: 0.8,
                maxScale: 5.0,
                onInteractionStart: (_) => setState(() => _zoomed = true),
                onInteractionEnd: (_) {
                  if (_transformCtrl.value == Matrix4.identity()) {
                    setState(() => _zoomed = false);
                  }
                },
                child: Center(
                  child: _SimulatedImage(img: img),
                ),
              ),
            );
          },
        ),

        // ── Barre supérieure ───────────────────────────────────────
        AnimatedBuilder(
          animation: _uiAnim,
          builder: (_, __) => Opacity(
            opacity: _uiAnim.value,
            child: IgnorePointer(
              ignoring: !_showUI,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black.withOpacity(0.70), Colors.transparent],
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 4),
                    child: Row(children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded,
                            color: Colors.white, size: 22),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(_img.title,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13,
                                fontWeight: FontWeight.w700),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(_img.subtitle,
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.55),
                                fontSize: 11),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ])),
                      // Reset zoom
                      if (_zoomed)
                        IconButton(
                          icon: const Icon(Icons.zoom_out_map_rounded,
                              color: Colors.white, size: 20),
                          onPressed: () {
                            _transformCtrl.value = Matrix4.identity();
                            setState(() => _zoomed = false);
                          },
                        ),
                      // Share
                      IconButton(
                        icon: const Icon(Icons.share_rounded,
                            color: Colors.white, size: 20),
                        onPressed: () {},
                      ),
                      // Download
                      IconButton(
                        icon: const Icon(Icons.download_rounded,
                            color: Colors.white, size: 20),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Téléchargement : ${_img.title}'),
                              backgroundColor: _img.color,
                              duration: const Duration(milliseconds: 2000),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        },
                      ),
                      // Info
                      IconButton(
                        icon: Icon(Icons.info_outline_rounded,
                            color: _showInfo ? _img.color : Colors.white,
                            size: 20),
                        onPressed: _toggleInfo,
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),

        // ── Compteur + navigation bas ──────────────────────────────
        AnimatedBuilder(
          animation: _uiAnim,
          builder: (_, __) => Opacity(
            opacity: _uiAnim.value,
            child: IgnorePointer(
              ignoring: !_showUI,
              child: Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent,
                          Colors.black.withOpacity(0.65)],
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    ),
                  ),
                  padding: EdgeInsets.fromLTRB(20, 20, 20,
                      MediaQuery.of(context).padding.bottom + 16),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                    // Prev
                    _NavCircleBtn(
                      icon: Icons.chevron_left_rounded,
                      enabled: _idx > 0,
                      onTap: () {
                        _pageCtrl.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut);
                      },
                    ),
                    // Counter + thumbnails
                    Column(children: [
                      Text('${_idx + 1} / ${_gallery.length}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      // Dots
                      Row(mainAxisSize: MainAxisSize.min,
                          children: List.generate(
                              _gallery.length.clamp(0, 10), (i) {
                        final isActive = i == _idx;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          width: isActive ? 18 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isActive
                                ? _img.color
                                : Colors.white.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      })),
                    ]),
                    // Next
                    _NavCircleBtn(
                      icon: Icons.chevron_right_rounded,
                      enabled: _idx < _gallery.length - 1,
                      onTap: () {
                        _pageCtrl.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut);
                      },
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),

        // ── Panneau info (slide up) ────────────────────────────────
        AnimatedBuilder(
          animation: _infoAnim,
          builder: (_, child) => Positioned(
            bottom: -300 + _infoAnim.value * 300,
            left: 0, right: 0,
            child: child!,
          ),
          child: _InfoPanel(img: _img, onClose: _toggleInfo),
        ),
      ]),
    );
  }
}

// ── Image simulée (visuel riche sans fichier réseau) ──────────────────────
class _SimulatedImage extends StatelessWidget {
  final _Img img;
  const _SimulatedImage({required this.img});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.2),
          radius: 1.5,
          colors: [
            img.color.withOpacity(0.90),
            img.colorEnd.withOpacity(0.70),
            Colors.black.withOpacity(0.90),
          ],
        ),
      ),
      child: Stack(alignment: Alignment.center, children: [
        // Grid lines (simulating a diagram)
        CustomPaint(
          painter: _GridPainter(color: Colors.white.withOpacity(0.05)),
          size: Size(size.width, size.height),
        ),
        // Content
        Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withOpacity(0.25), width: 2),
            ),
            child: Icon(img.icon, size: 48, color: Colors.white),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(img.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white, fontSize: 18,
                    fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 8),
          Text(img.subtitle,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.55), fontSize: 13)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: Colors.white.withOpacity(0.20)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.photo_size_select_actual_rounded,
                  size: 14, color: Colors.white.withOpacity(0.60)),
              const SizedBox(width: 6),
              Text('${img.type} · ${img.size}',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.60),
                      fontSize: 12)),
            ]),
          ),
        ]),
      ]),
    );
  }
}

// ── Info panel (bottom) ────────────────────────────────────────────────────
class _InfoPanel extends StatelessWidget {
  final _Img img;
  final VoidCallback onClose;
  const _InfoPanel({required this.img, required this.onClose});

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Color(0xF5111111),
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      border: Border(top: BorderSide(color: Color(0x33FFFFFF))),
    ),
    padding: EdgeInsets.fromLTRB(20, 12, 20,
        MediaQuery.of(context).padding.bottom + 20),
    child: Column(mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(child: Container(
          height: 3, width: 40,
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2)))),
      const SizedBox(height: 16),
      Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [img.color, img.colorEnd]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(img.icon, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(img.title,
              style: const TextStyle(color: Colors.white, fontSize: 14,
                  fontWeight: FontWeight.w800),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(img.subtitle,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.50), fontSize: 11)),
        ])),
        GestureDetector(
          onTap: onClose,
          child: Icon(Icons.keyboard_arrow_down_rounded,
              color: Colors.white.withOpacity(0.50), size: 24),
        ),
      ]),
      const SizedBox(height: 16),
      const Divider(height: 1, color: Color(0x33FFFFFF)),
      const SizedBox(height: 14),
      _InfoRow(label: 'Type', value: img.type),
      _InfoRow(label: 'Taille', value: img.size),
      _InfoRow(label: 'Ajouté le', value: img.date),
      _InfoRow(label: 'Matière', value: img.subtitle.split(' · ').first),
    ]),
  );
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      SizedBox(width: 90,
          child: Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.40),
                  fontSize: 12, fontWeight: FontWeight.w500))),
      Text(value,
          style: const TextStyle(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
    ]),
  );
}

// ── Nav button ─────────────────────────────────────────────────────────────
class _NavCircleBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _NavCircleBtn({
    required this.icon, required this.enabled, required this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: enabled ? onTap : null,
    child: Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: enabled
            ? Colors.white.withOpacity(0.15)
            : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
            color: Colors.white.withOpacity(enabled ? 0.30 : 0.10)),
      ),
      child: Icon(icon, size: 26,
          color: Colors.white.withOpacity(enabled ? 0.90 : 0.25)),
    ),
  );
}

// ── Grid painter ───────────────────────────────────────────────────────────
class _GridPainter extends CustomPainter {
  final Color color;
  const _GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}
