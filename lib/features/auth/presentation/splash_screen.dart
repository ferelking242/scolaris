import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _scaleAnim = Tween<double>(begin: 0.72, end: 1.0).animate(
        CurvedAnimation(
            parent: _ctrl,
            curve: const Interval(0, 0.65, curve: Curves.easeOutBack)));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _ctrl,
            curve: const Interval(0, 0.5, curve: Curves.easeOut)));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A0A00), Color(0xFF3E1A00), ScolarisPalette.terracotta],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // Subtle hex pattern
            Positioned.fill(
              child: CustomPaint(painter: _HexPatternPainter()),
            ),

            // Top accent stripe
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                height: 3,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      ScolarisPalette.terracotta,
                      ScolarisPalette.gold,
                      ScolarisPalette.orange,
                    ],
                  ),
                ),
              ),
            ),

            // Main content
            Center(
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) => FadeTransition(
                  opacity: _fadeAnim,
                  child: ScaleTransition(
                    scale: _scaleAnim,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo with glow
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: ScolarisPalette.gold.withOpacity(.35),
                                blurRadius: 36,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Image.asset(
                              'assets/images/logo.png',
                              width: 96,
                              height: 96,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 96,
                                height: 96,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      ScolarisPalette.terracotta,
                                      ScolarisPalette.orange,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                      color: Colors.white24, width: 1.5),
                                ),
                                child: const Center(
                                  child: Text(
                                    'S',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 44,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 26),

                        // App name
                        const Text(
                          AppConfig.appName,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 34,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          AppConfig.appTagline,
                          style: TextStyle(
                            color: ScolarisPalette.gold.withOpacity(.9),
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            letterSpacing: .5,
                          ),
                        ),
                        const SizedBox(height: 50),

                        // Spinner
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            color: Colors.white.withOpacity(.8),
                            strokeWidth: 2.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Bottom copyright
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Center(
                  child: Text(
                    '© ${DateTime.now().year} Scolaris · v${AppConfig.appVersion}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(.25),
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Subtle African hex pattern for splash background
class _HexPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withOpacity(.03)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    const spacing = 60.0;
    final cols = (size.width / spacing).ceil() + 1;
    final rows = (size.height / spacing).ceil() + 1;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final cx = c * spacing + (r.isOdd ? spacing / 2 : 0);
        final cy = r * spacing * 0.866;
        _drawHex(canvas, Offset(cx, cy), 22, p);
      }
    }
  }

  void _drawHex(Canvas canvas, Offset center, double radius, Paint p) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60 - 30) * math.pi / 180;
      final dx = center.dx + radius * math.cos(angle);
      final dy = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(dx, dy);
      } else {
        path.lineTo(dx, dy);
      }
    }
    path.close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_) => false;
}
