import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════════════════
// Modèles
// ══════════════════════════════════════════════════════════════════════════
class Track {
  final String title;
  final String artist;
  final String album;
  final Duration duration;
  final Color color;
  final Color colorEnd;
  final String? genre;
  const Track({
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.color,
    required this.colorEnd,
    this.genre,
  });
}

// ── Playlist mock ──────────────────────────────────────────────────────────
const _playlist = [
  Track(
    title: 'Mathématiques — Leçon 1',
    artist: 'M. Dupont · 5e A',
    album: 'Cours Audio Maths',
    duration: Duration(minutes: 18, seconds: 42),
    color: Color(0xFF4527A0), colorEnd: Color(0xFF7B1FA2),
    genre: 'Cours',
  ),
  Track(
    title: 'SVT — La Cellule',
    artist: 'Dr. Yao · 5e A',
    album: 'Cours Audio SVT',
    duration: Duration(minutes: 24, seconds: 15),
    color: Color(0xFF00695C), colorEnd: Color(0xFF00897B),
    genre: 'Cours',
  ),
  Track(
    title: 'Français — La Narration',
    artist: 'M. Mbiya · 5e A',
    album: 'Cours Audio Français',
    duration: Duration(minutes: 31, seconds: 08),
    color: Color(0xFFBF360C), colorEnd: Color(0xFFE64A19),
    genre: 'Cours',
  ),
  Track(
    title: 'Histoire — La Colonisation',
    artist: 'M. Kabamba · 5e A',
    album: 'Cours Audio Histoire',
    duration: Duration(minutes: 27, seconds: 50),
    color: Color(0xFF4E342E), colorEnd: Color(0xFF6D4C41),
    genre: 'Cours',
  ),
  Track(
    title: 'Anglais — Listening Practice',
    artist: 'Ms. Carter · 5e A',
    album: 'Cours Audio Anglais',
    duration: Duration(minutes: 15, seconds: 30),
    color: Color(0xFF1565C0), colorEnd: Color(0xFF0288D1),
    genre: 'Cours',
  ),
  Track(
    title: 'Physique — Les Ondes',
    artist: 'Mme Lefèvre · 5e A',
    album: 'Cours Audio Physique',
    duration: Duration(minutes: 22, seconds: 18),
    color: Color(0xFF880E4F), colorEnd: Color(0xFFC2185B),
    genre: 'Cours',
  ),
  Track(
    title: 'Géographie — L\'Afrique',
    artist: 'M. Kabamba · 5e A',
    album: 'Cours Audio Géo',
    duration: Duration(minutes: 19, seconds: 55),
    color: Color(0xFF1B5E20), colorEnd: Color(0xFF388E3C),
    genre: 'Cours',
  ),
  Track(
    title: 'Révision BEPC — Maths',
    artist: 'M. Dupont · Prépa Exam',
    album: 'Révisions Audio',
    duration: Duration(minutes: 45, seconds: 00),
    color: Color(0xFF6D28D9), colorEnd: Color(0xFF7C3AED),
    genre: 'Révision',
  ),
];

// ══════════════════════════════════════════════════════════════════════════
// MusicPlayerPage
// ══════════════════════════════════════════════════════════════════════════
class MusicPlayerPage extends StatefulWidget {
  final int initialIndex;
  const MusicPlayerPage({super.key, this.initialIndex = 0});

  @override
  State<MusicPlayerPage> createState() => _MusicPlayerPageState();
}

class _MusicPlayerPageState extends State<MusicPlayerPage>
    with TickerProviderStateMixin {
  late int _idx;
  bool _playing = false;
  Duration _position = Duration.zero;
  Timer? _timer;
  bool _shuffle = false;
  int _repeat = 0; // 0=off 1=all 2=one
  double _volume = 0.85;
  bool _showQueue = false;

  late AnimationController _rotAnim;
  late AnimationController _waveAnim;
  late AnimationController _coverAnim;

  final _rand = Random();
  late List<double> _barHeights;

  @override
  void initState() {
    super.initState();
    _idx = widget.initialIndex.clamp(0, _playlist.length - 1);
    _rotAnim = AnimationController(
        vsync: this, duration: const Duration(seconds: 12))
      ..repeat();
    _waveAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
    _coverAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400),
        lowerBound: 0.94, upperBound: 1.0)
      ..value = 1.0;
    _barHeights = List.generate(28, (_) => 0.15 + _rand.nextDouble() * 0.85);
    // Animate bars periodically
    _startWaveLoop();
  }

  void _startWaveLoop() {
    Timer.periodic(const Duration(milliseconds: 180), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_playing) {
        setState(() {
          _barHeights = List.generate(
            28, (_) => 0.15 + _rand.nextDouble() * 0.85,
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _rotAnim.dispose();
    _waveAnim.dispose();
    _coverAnim.dispose();
    super.dispose();
  }

  Track get _track => _playlist[_idx];

  void _togglePlay() {
    setState(() => _playing = !_playing);
    if (_playing) {
      if (!_rotAnim.isAnimating) _rotAnim.repeat();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          _position += const Duration(seconds: 1);
          if (_position >= _track.duration) {
            _onTrackEnd();
          }
        });
      });
    } else {
      _rotAnim.stop();
      _timer?.cancel();
    }
  }

  void _onTrackEnd() {
    _timer?.cancel();
    _playing = false;
    if (_repeat == 2) {
      _position = Duration.zero;
      _togglePlay();
    } else {
      _position = Duration.zero;
      if (_repeat == 1 || _idx < _playlist.length - 1) {
        _nextTrack();
      }
    }
  }

  void _nextTrack() {
    _timer?.cancel();
    _playing = false;
    _position = Duration.zero;
    setState(() {
      if (_shuffle) {
        _idx = _rand.nextInt(_playlist.length);
      } else {
        _idx = (_idx + 1) % _playlist.length;
      }
    });
    _coverAnim.reverse().then((_) => _coverAnim.forward());
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _togglePlay();
    });
  }

  void _prevTrack() {
    if (_position.inSeconds > 3) {
      setState(() => _position = Duration.zero);
      return;
    }
    _timer?.cancel();
    _playing = false;
    _position = Duration.zero;
    setState(() {
      _idx = (_idx - 1 + _playlist.length) % _playlist.length;
    });
    _coverAnim.reverse().then((_) => _coverAnim.forward());
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _togglePlay();
    });
  }

  void _seekTo(double frac) {
    final ms = (frac * _track.duration.inMilliseconds).round();
    setState(() => _position = Duration(milliseconds: ms));
  }

  double get _progress {
    if (_track.duration.inMilliseconds == 0) return 0;
    return (_position.inMilliseconds / _track.duration.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  String _fmt(Duration d) {
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final t = _track;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(children: [

        // ── Fond dynamique ─────────────────────────────────────────
        Positioned.fill(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 800),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.5, -0.6),
                radius: 1.8,
                colors: [
                  t.color.withOpacity(0.45),
                  t.colorEnd.withOpacity(0.20),
                  const Color(0xFF0A0A0A),
                ],
                stops: const [0, 0.4, 1],
              ),
            ),
          ),
        ),

        // ── Contenu principal ──────────────────────────────────────
        SafeArea(
          child: Column(children: [

            // ── Barre supérieure ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(child: Column(children: [
                  Text('EN LECTURE',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.50),
                          fontSize: 10, fontWeight: FontWeight.w700,
                          letterSpacing: 1.5)),
                  const SizedBox(height: 2),
                  Text(t.album,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13,
                          fontWeight: FontWeight.w700),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ])),
                IconButton(
                  icon: Icon(Icons.queue_music_rounded,
                      color: _showQueue ? t.color : Colors.white, size: 22),
                  onPressed: () => setState(() => _showQueue = !_showQueue),
                ),
              ]),
            ),

            // ── Pochette d'album animée ────────────────────────────
            Expanded(
              flex: 5,
              child: Center(
                child: ScaleTransition(
                  scale: _coverAnim,
                  child: AnimatedBuilder(
                    animation: _rotAnim,
                    builder: (_, child) => Transform.rotate(
                      angle: _playing ? _rotAnim.value * 2 * pi : 0,
                      child: child,
                    ),
                    child: Container(
                      width: 220, height: 220,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [t.color, t.colorEnd],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: t.color.withOpacity(0.5),
                              blurRadius: 40, spreadRadius: 10),
                        ],
                      ),
                      child: Stack(alignment: Alignment.center, children: [
                        // Vinyl groove rings
                        ...List.generate(4, (i) => Container(
                          width: 60.0 + i * 38,
                          height: 60.0 + i * 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.black.withOpacity(0.15),
                                width: 1.5),
                          ),
                        )),
                        // Center icon
                        Container(
                          width: 56, height: 56,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.headphones_rounded,
                              size: 26, color: t.color),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
            ),

            // ── Visualiseur de forme d'onde ────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: SizedBox(
                height: 36,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(28, (i) {
                    final h = _playing ? _barHeights[i] : 0.15;
                    return AnimatedContainer(
                      duration: Duration(milliseconds: 100 + i * 5),
                      width: 3,
                      height: 36 * h,
                      decoration: BoxDecoration(
                        color: _playing
                            ? Color.lerp(t.color, t.colorEnd, i / 28)!
                                .withOpacity(0.85)
                            : Colors.white.withOpacity(0.20),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Titre + Artiste ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Row(children: [
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.title,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 19,
                          fontWeight: FontWeight.w900),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(t.artist,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.55), fontSize: 13),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ])),
                // Heart
                GestureDetector(
                  onTap: () {},
                  child: Icon(Icons.favorite_border_rounded,
                      color: Colors.white.withOpacity(0.50), size: 24),
                ),
              ]),
            ),
            const SizedBox(height: 22),

            // ── Barre de progression ───────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(children: [
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 7),
                    overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 14),
                    activeTrackColor: t.color,
                    inactiveTrackColor: Colors.white.withOpacity(0.15),
                    thumbColor: Colors.white,
                    overlayColor: t.color.withOpacity(0.20),
                  ),
                  child: Slider(
                    value: _progress,
                    onChanged: _seekTo,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(children: [
                    Text(_fmt(_position),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 11,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text(_fmt(_track.duration),
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.45),
                            fontSize: 11)),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 16),

            // ── Contrôles principaux ───────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                // Shuffle
                GestureDetector(
                  onTap: () => setState(() => _shuffle = !_shuffle),
                  child: Stack(alignment: Alignment.topRight, children: [
                    Icon(Icons.shuffle_rounded,
                        size: 24,
                        color: _shuffle ? t.color : Colors.white.withOpacity(0.45)),
                    if (_shuffle)
                      Positioned(
                        right: 0, top: 0,
                        child: Container(
                          width: 6, height: 6,
                          decoration: BoxDecoration(
                              color: t.color, shape: BoxShape.circle),
                        ),
                      ),
                  ]),
                ),
                // Précédent
                GestureDetector(
                  onTap: _prevTrack,
                  child: const Icon(Icons.skip_previous_rounded,
                      color: Colors.white, size: 38),
                ),
                // Play / Pause
                GestureDetector(
                  onTap: _togglePlay,
                  child: Container(
                    width: 66, height: 66,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [t.color, t.colorEnd]),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: t.color.withOpacity(0.45),
                            blurRadius: 20, spreadRadius: 2),
                      ],
                    ),
                    child: Icon(
                        _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white, size: 36),
                  ),
                ),
                // Suivant
                GestureDetector(
                  onTap: _nextTrack,
                  child: const Icon(Icons.skip_next_rounded,
                      color: Colors.white, size: 38),
                ),
                // Repeat
                GestureDetector(
                  onTap: () => setState(() => _repeat = (_repeat + 1) % 3),
                  child: Stack(alignment: Alignment.topRight, children: [
                    Icon(
                        _repeat == 2
                            ? Icons.repeat_one_rounded
                            : Icons.repeat_rounded,
                        size: 24,
                        color: _repeat > 0
                            ? t.color
                            : Colors.white.withOpacity(0.45)),
                    if (_repeat > 0)
                      Positioned(
                        right: 0, top: 0,
                        child: Container(
                          width: 6, height: 6,
                          decoration: BoxDecoration(
                              color: t.color, shape: BoxShape.circle),
                        ),
                      ),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 16),

            // ── Volume ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Row(children: [
                Icon(Icons.volume_down_rounded, size: 18,
                    color: Colors.white.withOpacity(0.40)),
                Expanded(child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 5),
                    activeTrackColor: Colors.white.withOpacity(0.70),
                    inactiveTrackColor: Colors.white.withOpacity(0.15),
                    thumbColor: Colors.white,
                  ),
                  child: Slider(
                    value: _volume, min: 0, max: 1,
                    onChanged: (v) => setState(() => _volume = v),
                  ),
                )),
                Icon(Icons.volume_up_rounded, size: 18,
                    color: Colors.white.withOpacity(0.40)),
              ]),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ]),
        ),

        // ── Queue panel ────────────────────────────────────────────
        AnimatedPositioned(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          top: 0, bottom: 0,
          right: _showQueue ? 0 : -320,
          width: 300,
          child: _QueuePanel(
            playlist: _playlist,
            currentIndex: _idx,
            track: _track,
            onSelect: (i) {
              setState(() {
                _idx = i;
                _position = Duration.zero;
                _playing = false;
              });
              _timer?.cancel();
              Future.delayed(const Duration(milliseconds: 200), () {
                if (mounted) _togglePlay();
              });
            },
          ),
        ),
      ]),
    );
  }
}

// ── Queue panel ────────────────────────────────────────────────────────────
class _QueuePanel extends StatelessWidget {
  final List<Track> playlist;
  final int currentIndex;
  final Track track;
  final Function(int) onSelect;
  const _QueuePanel({
    required this.playlist, required this.currentIndex,
    required this.track, required this.onSelect,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Color(0xF2111111),
      border: Border(left: BorderSide(color: Color(0x33FFFFFF))),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('File d\'attente',
              style: const TextStyle(color: Colors.white, fontSize: 15,
                  fontWeight: FontWeight.w800)),
        ),
      ),
      const Divider(height: 1, color: Color(0x33FFFFFF)),
      Expanded(child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: playlist.length,
        itemBuilder: (_, i) {
          final t = playlist[i];
          final isActive = i == currentIndex;
          return GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isActive ? t.color.withOpacity(0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [t.color, t.colorEnd]),
                    shape: BoxShape.circle,
                  ),
                  child: isActive
                      ? const Icon(Icons.volume_up_rounded,
                          color: Colors.white, size: 16)
                      : Center(child: Text('${i + 1}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11,
                              fontWeight: FontWeight.w800))),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.title,
                      style: TextStyle(
                          color: isActive ? Colors.white : Colors.white.withOpacity(0.80),
                          fontSize: 12,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w400),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(t.artist,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.45), fontSize: 10),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ])),
              ]),
            ),
          );
        },
      )),
    ]),
  );
}
