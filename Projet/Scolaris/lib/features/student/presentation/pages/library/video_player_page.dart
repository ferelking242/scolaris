import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ══════════════════════════════════════════════════════════════════════════
// Modèles
// ══════════════════════════════════════════════════════════════════════════
class VideoChapter {
  final String title;
  final Duration start;
  const VideoChapter({required this.title, required this.start});
}

class VideoLesson {
  final String title;
  final String subject;
  final String teacher;
  final Color color;
  final Duration duration;
  final List<VideoChapter> chapters;
  const VideoLesson({
    required this.title,
    required this.subject,
    required this.teacher,
    required this.color,
    required this.duration,
    this.chapters = const [],
  });
}

// ── Mock data ──────────────────────────────────────────────────────────────
final _mockLessons = <VideoLesson>[
  VideoLesson(
    title: 'Introduction aux Équations du 2nd Degré',
    subject: 'Mathématiques', teacher: 'M. Dupont',
    color: const Color(0xFF4527A0),
    duration: const Duration(minutes: 38, seconds: 22),
    chapters: [
      VideoChapter(title: 'Introduction & rappels', start: Duration.zero),
      VideoChapter(title: 'Définition et forme canonique', start: const Duration(minutes: 6)),
      VideoChapter(title: 'Le discriminant Δ', start: const Duration(minutes: 14)),
      VideoChapter(title: 'Cas Δ > 0 — deux solutions réelles', start: const Duration(minutes: 20)),
      VideoChapter(title: "Cas Δ = 0 — solution double", start: const Duration(minutes: 28)),
      VideoChapter(title: 'Exercices corrigés', start: const Duration(minutes: 33)),
    ],
  ),
  VideoLesson(
    title: 'La Cellule — Structure et Fonctions',
    subject: 'SVT', teacher: 'Dr. Yao',
    color: const Color(0xFF00838F),
    duration: const Duration(minutes: 45, seconds: 10),
    chapters: [
      VideoChapter(title: 'Qu\'est-ce qu\'une cellule ?', start: Duration.zero),
      VideoChapter(title: 'La membrane plasmique', start: const Duration(minutes: 8)),
      VideoChapter(title: 'Le noyau cellulaire', start: const Duration(minutes: 17)),
      VideoChapter(title: 'Les organites', start: const Duration(minutes: 26)),
      VideoChapter(title: 'Division cellulaire', start: const Duration(minutes: 38)),
    ],
  ),
  VideoLesson(
    title: 'La Révolution Française — Causes et Conséquences',
    subject: 'Histoire-Géo', teacher: 'M. Kabamba',
    color: const Color(0xFFBF360C),
    duration: const Duration(minutes: 52),
    chapters: [
      VideoChapter(title: 'La France en 1789', start: Duration.zero),
      VideoChapter(title: 'Les causes économiques', start: const Duration(minutes: 9)),
      VideoChapter(title: 'La prise de la Bastille', start: const Duration(minutes: 20)),
      VideoChapter(title: 'La Déclaration des Droits', start: const Duration(minutes: 31)),
      VideoChapter(title: 'Conséquences en Afrique', start: const Duration(minutes: 43)),
    ],
  ),
];

// ══════════════════════════════════════════════════════════════════════════
// VideoPlayerPage
// ══════════════════════════════════════════════════════════════════════════
class VideoPlayerPage extends StatefulWidget {
  final VideoLesson? lesson;
  final String? title;
  final Color? color;

  const VideoPlayerPage({super.key, this.lesson, this.title, this.color});

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage>
    with TickerProviderStateMixin {
  late VideoLesson _lesson;
  bool _playing = false;
  Duration _position = Duration.zero;
  Timer? _playTimer;
  Timer? _hideTimer;
  bool _showControls = true;
  bool _fullscreen = false;
  double _speed = 1.0;
  String _quality = '720p';
  bool _showChapters = false;
  double _volume = 1.0;
  bool _showVolume = false;

  late AnimationController _playAnim;
  late AnimationController _controlsAnim;

  static const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  static const _qualities = ['360p', '480p', '720p', '1080p'];

  @override
  void initState() {
    super.initState();
    _lesson = widget.lesson ?? _mockLessons.first;
    _playAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _controlsAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220));
    _controlsAnim.value = 1.0;
    _scheduleHide();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _playTimer?.cancel();
    _hideTimer?.cancel();
    _playAnim.dispose();
    _controlsAnim.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _togglePlay() {
    setState(() => _playing = !_playing);
    if (_playing) {
      _playAnim.forward();
      _playTimer = Timer.periodic(
        Duration(milliseconds: (1000 / _speed).round()),
        (_) {
          if (!mounted) return;
          setState(() {
            _position += const Duration(seconds: 1);
            if (_position >= _lesson.duration) {
              _position = _lesson.duration;
              _playing = false;
              _playTimer?.cancel();
              _playAnim.reverse();
            }
          });
        },
      );
      _scheduleHide();
    } else {
      _playAnim.reverse();
      _playTimer?.cancel();
      _showControlsTemporarily();
    }
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _playing) {
        _controlsAnim.reverse();
        setState(() => _showControls = false);
      }
    });
  }

  void _showControlsTemporarily() {
    if (!_showControls) {
      setState(() => _showControls = true);
      _controlsAnim.forward();
    }
    _scheduleHide();
  }

  void _seek(Duration to) {
    setState(() => _position = to.clamp(Duration.zero, _lesson.duration));
    _showControlsTemporarily();
  }

  void _skip(int seconds) => _seek(_position + Duration(seconds: seconds));

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double get _progressFraction {
    if (_lesson.duration.inMilliseconds == 0) return 0;
    return _position.inMilliseconds / _lesson.duration.inMilliseconds;
  }

  VideoChapter? get _currentChapter {
    VideoChapter? ch;
    for (final c in _lesson.chapters) {
      if (_position >= c.start) ch = c;
    }
    return ch;
  }

  @override
  Widget build(BuildContext context) {
    final c = _lesson.color;
    final accent = Colors.white;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {
          if (_showControls) {
            setState(() => _showControls = false);
            _controlsAnim.reverse();
            _hideTimer?.cancel();
          } else {
            _showControlsTemporarily();
          }
        },
        child: Stack(children: [

          // ── Simulated video ──────────────────────────────────────
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [c.withOpacity(0.35), Colors.black],
                ),
              ),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: c.withOpacity(0.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: c.withOpacity(0.4), width: 2),
                  ),
                  child: Icon(Icons.play_lesson_rounded, size: 40, color: c),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(_lesson.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 8),
                Text('${_lesson.subject} · ${_lesson.teacher}',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.50),
                        fontSize: 13)),
              ]),
            ),
          ),

          // ── Buffering shimmer ──────────────────────────────────────
          if (!_playing && _position == Duration.zero)
            const SizedBox.shrink(),

          // ── Controls overlay ───────────────────────────────────────
          AnimatedBuilder(
            animation: _controlsAnim,
            builder: (_, __) => Opacity(
              opacity: _controlsAnim.value,
              child: IgnorePointer(
                ignoring: !_showControls,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.65),
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withOpacity(0.75),
                      ],
                      stops: const [0, 0.25, 0.7, 1],
                    ),
                  ),
                  child: Column(children: [

                    // ── Top bar ──────────────────────────────────────
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                        child: Row(children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_rounded,
                                color: Colors.white, size: 22),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(_lesson.title,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 13,
                                    fontWeight: FontWeight.w700),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            if (_currentChapter != null)
                              Text(_currentChapter!.title,
                                  style: TextStyle(
                                      color: Colors.white.withOpacity(0.6),
                                      fontSize: 11)),
                          ])),
                          // Volume
                          IconButton(
                            icon: Icon(
                              _volume == 0
                                  ? Icons.volume_off_rounded
                                  : _volume < 0.5
                                      ? Icons.volume_down_rounded
                                      : Icons.volume_up_rounded,
                              color: Colors.white, size: 20),
                            onPressed: () => setState(() =>
                                _showVolume = !_showVolume),
                          ),
                          // Chapters
                          IconButton(
                            icon: Icon(Icons.view_list_rounded,
                                color: _showChapters ? c : Colors.white,
                                size: 20),
                            onPressed: () => setState(() =>
                                _showChapters = !_showChapters),
                          ),
                          // More
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert_rounded,
                                color: Colors.white, size: 20),
                            color: const Color(0xFF1C1C1C),
                            itemBuilder: (_) => [
                              ..._speeds.map((s) => PopupMenuItem(
                                value: 'speed_$s',
                                child: Row(children: [
                                  Icon(Icons.speed_rounded,
                                      size: 16,
                                      color: s == _speed ? c : Colors.grey),
                                  const SizedBox(width: 8),
                                  Text('${s}x',
                                      style: TextStyle(
                                          color: s == _speed ? c : Colors.white,
                                          fontSize: 13,
                                          fontWeight: s == _speed
                                              ? FontWeight.w700
                                              : FontWeight.w400)),
                                ]),
                              )),
                              const PopupMenuDivider(),
                              ..._qualities.map((q) => PopupMenuItem(
                                value: 'quality_$q',
                                child: Row(children: [
                                  Icon(Icons.hd_rounded,
                                      size: 16,
                                      color: q == _quality ? c : Colors.grey),
                                  const SizedBox(width: 8),
                                  Text(q, style: TextStyle(
                                      color: q == _quality ? c : Colors.white,
                                      fontSize: 13,
                                      fontWeight: q == _quality
                                          ? FontWeight.w700
                                          : FontWeight.w400)),
                                ]),
                              )),
                            ],
                            onSelected: (v) {
                              if (v.startsWith('speed_')) {
                                setState(() {
                                  _speed = double.parse(v.substring(6));
                                });
                                if (_playing) {
                                  _playTimer?.cancel();
                                  _playing = false;
                                  Future.microtask(_togglePlay);
                                }
                              } else if (v.startsWith('quality_')) {
                                setState(() => _quality = v.substring(8));
                              }
                            },
                          ),
                        ]),
                      ),
                    ),

                    const Spacer(),

                    // ── Center play controls ─────────────────────────
                    Row(mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      // Skip -10
                      _IconBtn(
                        icon: Icons.replay_10_rounded,
                        size: 36,
                        onTap: () => _skip(-10),
                      ),
                      const SizedBox(width: 32),
                      // Play/pause
                      GestureDetector(
                        onTap: _togglePlay,
                        child: Container(
                          width: 64, height: 64,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white.withOpacity(0.4),
                                width: 1.5),
                          ),
                          child: AnimatedIcon(
                            icon: AnimatedIcons.play_pause,
                            progress: _playAnim,
                            color: Colors.white, size: 32,
                          ),
                        ),
                      ),
                      const SizedBox(width: 32),
                      // Skip +10
                      _IconBtn(
                        icon: Icons.forward_10_rounded,
                        size: 36,
                        onTap: () => _skip(10),
                      ),
                    ]),

                    const Spacer(),

                    // ── Bottom controls ──────────────────────────────
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16,
                          MediaQuery.of(context).padding.bottom + 12),
                      child: Column(children: [
                        // Chapter markers + progress bar
                        SizedBox(
                          height: 20,
                          child: Stack(alignment: Alignment.center, children: [
                            // Track
                            Positioned.fill(
                              child: GestureDetector(
                                onHorizontalDragUpdate: (d) {
                                  final box = context.findRenderObject()
                                      as RenderBox?;
                                  if (box == null) return;
                                  final frac = (d.localPosition.dx / box.size.width)
                                      .clamp(0.0, 1.0);
                                  _seek(Duration(
                                      milliseconds: (frac *
                                              _lesson.duration.inMilliseconds)
                                          .round()));
                                },
                                onTapDown: (d) {
                                  final box = context.findRenderObject()
                                      as RenderBox?;
                                  if (box == null) return;
                                  final frac = (d.localPosition.dx / box.size.width)
                                      .clamp(0.0, 1.0);
                                  _seek(Duration(
                                      milliseconds: (frac *
                                              _lesson.duration.inMilliseconds)
                                          .round()));
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    value: _progressFraction,
                                    minHeight: 4,
                                    backgroundColor:
                                        Colors.white.withOpacity(0.20),
                                    valueColor: AlwaysStoppedAnimation(c),
                                  ),
                                ),
                              ),
                            ),
                            // Chapter dots
                            for (final ch in _lesson.chapters)
                              if (ch.start > Duration.zero)
                                Positioned(
                                  left: (ch.start.inMilliseconds /
                                          _lesson.duration.inMilliseconds) *
                                      (MediaQuery.of(context).size.width - 32),
                                  child: Container(
                                    width: 6, height: 6,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.black, width: 1),
                                    ),
                                  ),
                                ),
                          ]),
                        ),
                        const SizedBox(height: 8),
                        // Time + quality + speed
                        Row(children: [
                          Text(_fmt(_position),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12, fontWeight: FontWeight.w700)),
                          Text(' / ${_fmt(_lesson.duration)}',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.50),
                                  fontSize: 12)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: c.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(_quality,
                                style: TextStyle(
                                    color: c,
                                    fontSize: 10, fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text('${_speed}x',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.80),
                                    fontSize: 10, fontWeight: FontWeight.w700)),
                          ),
                        ]),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
          ),

          // ── Volume slider ──────────────────────────────────────────
          if (_showVolume)
            Positioned(
              top: 56 + MediaQuery.of(context).padding.top,
              right: 60,
              child: _VolumePanel(
                volume: _volume,
                color: c,
                onChanged: (v) => setState(() => _volume = v),
                onClose: () => setState(() => _showVolume = false),
              ),
            ),

          // ── Chapters panel ─────────────────────────────────────────
          if (_showChapters)
            Positioned(
              top: 0, right: 0, bottom: 0,
              child: _ChaptersPanel(
                chapters: _lesson.chapters,
                currentPosition: _position,
                color: c,
                onChapter: (ch) {
                  _seek(ch.start);
                  setState(() => _showChapters = false);
                },
                onClose: () => setState(() => _showChapters = false),
              ),
            ),
        ]),
      ),
    );
  }
}

// ── Volume panel ───────────────────────────────────────────────────────────
class _VolumePanel extends StatelessWidget {
  final double volume;
  final Color color;
  final ValueChanged<double> onChanged;
  final VoidCallback onClose;
  const _VolumePanel({
    required this.volume, required this.color,
    required this.onChanged, required this.onClose,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: Container(
      width: 200,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xDD1C1C1C),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Icon(Icons.volume_up_rounded, size: 16,
              color: Colors.white.withOpacity(0.70)),
          const Expanded(child: SizedBox()),
          GestureDetector(
            onTap: onClose,
            child: Icon(Icons.close_rounded, size: 14,
                color: Colors.white.withOpacity(0.50)),
          ),
        ]),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            activeTrackColor: color,
            inactiveTrackColor: Colors.white.withOpacity(0.15),
            thumbColor: Colors.white,
          ),
          child: Slider(
            value: volume, min: 0, max: 1,
            onChanged: onChanged,
          ),
        ),
        Text('${(volume * 100).toInt()}%',
            style: TextStyle(color: Colors.white.withOpacity(0.60),
                fontSize: 11)),
      ]),
    ),
  );
}

// ── Chapters panel ─────────────────────────────────────────────────────────
class _ChaptersPanel extends StatelessWidget {
  final List<VideoChapter> chapters;
  final Duration currentPosition;
  final Color color;
  final Function(VideoChapter) onChapter;
  final VoidCallback onClose;
  const _ChaptersPanel({
    required this.chapters, required this.currentPosition,
    required this.color, required this.onChapter, required this.onClose,
  });

  String _fmt(Duration d) {
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => Container(
    width: 240,
    height: double.infinity,
    decoration: const BoxDecoration(
      color: Color(0xEE111111),
      border: Border(left: BorderSide(color: Color(0x33FFFFFF))),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 16, 8, 8),
        child: Row(children: [
          const Expanded(child: Text('Chapitres',
              style: TextStyle(color: Colors.white, fontSize: 15,
                  fontWeight: FontWeight.w800))),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
            onPressed: onClose,
          ),
        ]),
      ),
      const Divider(height: 1, color: Color(0x33FFFFFF)),
      Expanded(child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: chapters.length,
        itemBuilder: (_, i) {
          final ch = chapters[i];
          final isActive = currentPosition >= ch.start &&
              (i + 1 >= chapters.length ||
                  currentPosition < chapters[i + 1].start);
          return GestureDetector(
            onTap: () => onChapter(ch),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isActive ? color.withOpacity(0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: isActive ? color.withOpacity(0.4) : Colors.transparent),
              ),
              child: Row(children: [
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    color: isActive ? color : Colors.white.withOpacity(0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Center(child: Text('${i + 1}',
                      style: TextStyle(
                          color: isActive ? Colors.white : Colors.white.withOpacity(0.70),
                          fontSize: 10, fontWeight: FontWeight.w800))),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(ch.title,
                      style: TextStyle(
                          color: isActive ? Colors.white : Colors.white.withOpacity(0.75),
                          fontSize: 12,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w400),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(_fmt(ch.start),
                      style: TextStyle(color: color.withOpacity(0.80),
                          fontSize: 10, fontWeight: FontWeight.w600)),
                ])),
              ]),
            ),
          );
        },
      )),
    ]),
  );
}

// ── Icon button helper ─────────────────────────────────────────────────────
class _IconBtn extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.size, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Icon(icon, color: Colors.white, size: size),
  );
}
