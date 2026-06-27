import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_theme.dart';
import '../../../presentation/providers/auth_providers.dart';
import 'forgot_password_screen.dart';

// ── Brand tokens ──────────────────────────────────────────────────────────────
const _terra  = ScolarisPalette.terracotta;   // #8B1A00
const _gold   = ScolarisPalette.gold;          // #C17F24
const _forest = ScolarisPalette.forestGreen;   // #1B5E20

// ── Neutral tokens ────────────────────────────────────────────────────────────
const _ink    = Color(0xFF0F172A);
const _muted  = Color(0xFF64748B);
const _subtle = Color(0xFF94A3B8);
const _border = Color(0xFFE2E8F0);
const _white  = Colors.white;
const _pageBg = Color(0xFFF8F9FB);

// ══════════════════════════════════════════════════════════════════════════════
// LoginScreen
// ══════════════════════════════════════════════════════════════════════════════
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _emailCtrl  = TextEditingController();
  final _passCtrl   = TextEditingController();
  final _emailFocus = FocusNode();
  final _passFocus  = FocusNode();

  bool    _loading       = false;
  bool    _obscure       = true;
  String? _error;
  bool    _showQrScanner = false;
  int     _titleTaps     = 0;

  String  _selectedRole    = 'student';
  String? _selectedSubtype = 'lycee';

  late final AnimationController _fadeCtrl;
  late final Animation<double>   _fadeAnim;
  late final Animation<Offset>   _slideAnim;

  static const _roles = [
    ('student',      Icons.school_outlined,               'Élève'),
    ('parent',       Icons.family_restroom_outlined,      'Parent'),
    ('teacher',      Icons.menu_book_outlined,            'Prof'),
    ('surveillance', Icons.shield_outlined,               'Surv.'),
    ('finance',      Icons.payments_outlined,             'Finance'),
    ('admin',        Icons.admin_panel_settings_outlined, 'Admin'),
  ];

  static const _subTypeMap = <String, List<(String, String, IconData)>>{
    'student': [
      ('primaire',   'Primaire',    Icons.child_care_outlined),
      ('college',    'Collège',     Icons.school_outlined),
      ('lycee',      'Lycée',       Icons.account_balance_outlined),
      ('univ',       'Université',  Icons.science_outlined),
    ],
    'teacher': [
      ('primaire',   'Primaire',    Icons.child_care_outlined),
      ('secondaire', 'Secondaire',  Icons.school_outlined),
      ('univ',       'Université',  Icons.science_outlined),
    ],
    'parent': [
      ('primaire',   'Primaire',    Icons.child_care_outlined),
      ('college',    'Collège',     Icons.school_outlined),
      ('lycee',      'Lycée',       Icons.account_balance_outlined),
    ],
    'admin': [
      ('directeur',  'Directeur',   Icons.badge_outlined),
      ('secretaire', 'Secrétariat', Icons.person_outlined),
      ('dg',         'Dir. Gén.',   Icons.workspace_premium_outlined),
    ],
    'finance': [
      ('comptable',  'Comptable',   Icons.calculate_outlined),
      ('caissier',   'Caissier',    Icons.point_of_sale_outlined),
    ],
    'surveillance': [
      ('sg',  'Surv. Gén.',  Icons.security_outlined),
      ('aux', 'Auxiliaire',  Icons.shield_outlined),
    ],
  };

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic));
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose(); _passCtrl.dispose();
    _emailFocus.dispose(); _passFocus.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── 3-tap secret demo ──────────────────────────────────────────────────────
  void _onTitleTap() {
    setState(() => _titleTaps++);
    if (_titleTaps >= 3) {
      setState(() => _titleTaps = 0);
      _openDemoSheet();
    }
  }

  void _openDemoSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DemoSheet(
        selectedRole: _selectedRole,
        selectedSubtype: _selectedSubtype,
        roles: _roles,
        subTypeMap: _subTypeMap,
        onConfirm: (role, sub) {
          setState(() {
            _selectedRole    = role;
            _selectedSubtype = sub;
            _emailCtrl.text  = sub != null ? '${role}_${sub}@scolaris.app' : '$role@scolaris.app';
            _passCtrl.text   = 'demo1234';
            _error           = null;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  // ── Auth ───────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final email = _emailCtrl.text.trim();
    final pass  = _passCtrl.text;
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'E-mail invalide');
      return;
    }
    if (pass.isEmpty) {
      setState(() => _error = 'Mot de passe requis');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(signInUseCaseProvider)(email, pass);
    } on ArgumentError catch (e) {
      if (mounted) setState(() => _error = e.message as String);
    } catch (_) {
      if (mounted) setState(() => _error = 'Identifiants incorrects. Réessayez.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleQr(BarcodeCapture capture) async {
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || !raw.startsWith('scolaris://')) return;
    final parts = raw.replaceFirst('scolaris://', '').split(':');
    if (parts.length < 2) return;
    setState(() {
      _showQrScanner  = false;
      _emailCtrl.text = Uri.decodeComponent(parts[0]);
      _passCtrl.text  = Uri.decodeComponent(parts[1]);
      _error          = null;
    });
    Future.microtask(_submit);
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_showQrScanner) {
      return _QrScannerOverlay(
        onDetect: _handleQr,
        onClose: () => setState(() => _showQrScanner = false),
      );
    }

    final w         = MediaQuery.sizeOf(context).width;
    final isDesktop = w >= 900;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDesktop ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: isDesktop ? const Color(0xFF1A0D1E) : _pageBg,
        resizeToAvoidBottomInset: false,
        body: FadeTransition(
          opacity: _fadeAnim,
          child: isDesktop ? _buildDesktop() : _buildMobile(),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DESKTOP — grand card arrondi (réf. Behance)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildDesktop() {
    return Stack(children: [
      // Gradient background
      Positioned.fill(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A0D1E), Color(0xFF3D1A00), Color(0xFF1A0D1E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      // Subtle dot pattern
      Positioned.fill(child: CustomPaint(painter: _DotPatternPainter())),
      // Central card
      Center(
        child: SlideTransition(
          position: _slideAnim,
          child: Container(
            width: 860,
            height: 520,
            margin: const EdgeInsets.all(32),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.50),
                  blurRadius: 60,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Row(children: [
              // ── Left hero panel ──────────────────────────────────────────
              Expanded(
                flex: 47,
                child: Stack(fit: StackFit.expand, children: [
                  // Background image
                  Image.asset(
                    'assets/images/login_bg.webp',
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    errorBuilder: (_, __, ___) => Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF1C0500), Color(0xFF6B1200)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  ),
                  // Dark overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.50),
                          Colors.black.withOpacity(0.25),
                          Colors.black.withOpacity(0.65),
                        ],
                      ),
                    ),
                  ),
                  // Text content
                  Padding(
                    padding: const EdgeInsets.all(36),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Logo
                        Row(children: [
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: _white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(color: _white.withOpacity(0.25)),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(9),
                              child: Image.asset('assets/images/logo.png', fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Center(
                                  child: Text('S', style: TextStyle(
                                    color: _white, fontSize: 18, fontWeight: FontWeight.w900,
                                  )),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text('Scolaris', style: TextStyle(
                            color: _white, fontSize: 18,
                            fontWeight: FontWeight.w900, letterSpacing: -0.4,
                          )),
                        ]),
                        const Spacer(),
                        const Text(
                          'La plateforme\nde gestion\nscolaire africaine.',
                          style: TextStyle(
                            color: _white, fontSize: 28,
                            fontWeight: FontWeight.w800,
                            height: 1.20, letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Élèves · Notes · Finance · Emplois du temps',
                          style: TextStyle(
                            color: _white.withOpacity(0.60),
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '© ${DateTime.now().year} Scolaris',
                          style: TextStyle(
                            color: _white.withOpacity(0.30), fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
              // ── Right form panel ─────────────────────────────────────────
              Expanded(
                flex: 53,
                child: Container(
                  color: _white,
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      GestureDetector(
                        onTap: _onTitleTap,
                        behavior: HitTestBehavior.opaque,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Connexion', style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w800,
                              color: _ink, letterSpacing: -0.5,
                            )),
                            const SizedBox(height: 4),
                            Text('Bon retour sur Scolaris', style: TextStyle(
                              fontSize: 13, color: _muted,
                            )),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      // Email
                      _LineInput(
                        controller: _emailCtrl,
                        focusNode: _emailFocus,
                        label: 'Adresse e-mail',
                        hint: 'prenom.nom@ecole.com',
                        icon: Icons.alternate_email_rounded,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => _passFocus.requestFocus(),
                      ),
                      const SizedBox(height: 18),
                      // Password
                      _LineInput(
                        controller: _passCtrl,
                        focusNode: _passFocus,
                        label: 'Mot de passe',
                        hint: '••••••••',
                        icon: Icons.lock_outline_rounded,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        trailing: GestureDetector(
                          onTap: () => setState(() => _obscure = !_obscure),
                          child: Icon(
                            _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            size: 17, color: _subtle,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Forgot
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                          child: const Text('Mot de passe oublié ?', style: TextStyle(
                            fontSize: 12.5, color: _terra, fontWeight: FontWeight.w600,
                          )),
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (_error != null) ...[
                        _ErrorBanner(message: _error!),
                        const SizedBox(height: 14),
                      ],
                      const Spacer(),
                      // Se connecter
                      _PrimaryBtn(label: 'Se connecter', loading: _loading, onPressed: _submit),
                      const SizedBox(height: 10),
                      // QR
                      _GhostBtn(
                        label: 'Scanner mon QR code',
                        icon: Icons.qr_code_scanner_rounded,
                        onPressed: () => setState(() => _showQrScanner = true),
                      ),
                    ],
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MOBILE — flat white, CivicQuest style
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildMobile() {
    final size  = MediaQuery.sizeOf(context);
    final pad   = MediaQuery.paddingOf(context);
    final keyb  = MediaQuery.viewInsetsOf(context).bottom;

    return Stack(children: [
      // Full page background colour
      Positioned.fill(child: Container(color: _pageBg)),

      // Landscape illustration at bottom (hidden when keyboard opens)
      if (keyb < 100)
        Positioned(
          bottom: 0, left: 0, right: 0,
          height: size.height * 0.22,
          child: Image.asset(
            'assets/images/login_bg.webp',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            errorBuilder: (_, __, ___) => Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _forest.withOpacity(0.05),
                    _forest.withOpacity(0.25),
                  ],
                ),
              ),
            ),
          ),
        ),

      // Gradient fade over illustration top
      if (keyb < 100)
        Positioned(
          bottom: 0, left: 0, right: 0,
          height: size.height * 0.30,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_pageBg, _pageBg.withOpacity(0.0)],
              ),
            ),
          ),
        ),

      // Scrollable content — NO card, flat
      Positioned.fill(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.only(
            left: 28, right: 28,
            top: pad.top + 40,
            bottom: (keyb > 0 ? keyb : size.height * 0.24) + 16,
          ),
          child: SlideTransition(
            position: _slideAnim,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Logo
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset('assets/images/logo.png', width: 64, height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_terra, Color(0xFFD35400)],
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(child: Text('S', style: TextStyle(
                          color: _white, fontSize: 28, fontWeight: FontWeight.w900,
                        ))),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Gold sparkle + tagline
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Text('✦', style: TextStyle(fontSize: 10, color: _gold)),
                    const SizedBox(width: 6),
                    Text('Plateforme scolaire africaine',
                        style: TextStyle(fontSize: 11.5, color: _muted, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 6),
                    const Text('✦', style: TextStyle(fontSize: 10, color: _gold)),
                  ]),
                  const SizedBox(height: 20),

                  // Title — 3 taps = demo
                  GestureDetector(
                    onTap: _onTitleTap,
                    behavior: HitTestBehavior.opaque,
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: const TextSpan(
                        style: TextStyle(fontFamily: 'Roboto', height: 1.15),
                        children: [
                          TextSpan(text: 'Bon retour,\n', style: TextStyle(
                            fontSize: 30, fontWeight: FontWeight.w800,
                            color: _ink, letterSpacing: -0.7,
                          )),
                          TextSpan(text: 'Bienvenue.', style: TextStyle(
                            fontSize: 30, fontWeight: FontWeight.w800,
                            color: _terra, letterSpacing: -0.7,
                          )),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Connectez-vous à votre espace Scolaris.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: _muted, height: 1.5),
                  ),
                  const SizedBox(height: 32),

                  // Email
                  _RoundedInput(
                    controller: _emailCtrl,
                    focusNode: _emailFocus,
                    hint: 'Adresse e-mail',
                    icon: Icons.alternate_email_rounded,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _passFocus.requestFocus(),
                  ),
                  const SizedBox(height: 12),

                  // Password
                  _RoundedInput(
                    controller: _passCtrl,
                    focusNode: _passFocus,
                    hint: 'Mot de passe',
                    icon: Icons.lock_outline_rounded,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    trailing: GestureDetector(
                      onTap: () => setState(() => _obscure = !_obscure),
                      child: Icon(
                        _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        size: 17, color: _subtle,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Mot de passe oublié — MÊME page
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                      child: const Text('Mot de passe oublié ?', style: TextStyle(
                        fontSize: 13, color: _terra, fontWeight: FontWeight.w600,
                      )),
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (_error != null) ...[
                    _ErrorBanner(message: _error!),
                    const SizedBox(height: 16),
                  ],

                  // Se connecter
                  _PrimaryBtn(label: 'Se connecter', loading: _loading, onPressed: _submit),
                  const SizedBox(height: 12),

                  // QR bouton secondaire
                  _GhostBtn(
                    label: 'Connexion par QR code',
                    icon: Icons.qr_code_scanner_rounded,
                    onPressed: () => setState(() => _showQrScanner = true),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _LineInput — desktop underline style (comme la référence)
// ══════════════════════════════════════════════════════════════════════════════
class _LineInput extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Widget? trailing;

  const _LineInput({
    required this.controller, required this.focusNode,
    required this.label, required this.hint, required this.icon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted, this.trailing,
  });

  @override
  State<_LineInput> createState() => _LineInputState();
}

class _LineInputState extends State<_LineInput> {
  bool _focused = false;
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(() {
      if (mounted) setState(() => _focused = widget.focusNode.hasFocus);
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = _focused ? _terra : const Color(0xFFCBD5E1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: TextStyle(
          fontSize: 11.5, fontWeight: FontWeight.w600,
          color: _focused ? _terra : _muted, letterSpacing: 0.2,
        )),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(widget.icon, size: 15, color: _focused ? _terra : _subtle),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                obscureText: widget.obscureText,
                keyboardType: widget.keyboardType,
                textInputAction: widget.textInputAction,
                onSubmitted: widget.onSubmitted,
                style: const TextStyle(fontSize: 14, color: _ink, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: TextStyle(color: _subtle.withOpacity(0.6), fontSize: 13),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  suffixIcon: widget.trailing,
                ),
              ),
            ),
          ],
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: _focused ? 1.5 : 1.0,
          color: color,
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _RoundedInput — mobile rounded border style (CivicQuest)
// ══════════════════════════════════════════════════════════════════════════════
class _RoundedInput extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Widget? trailing;

  const _RoundedInput({
    required this.controller, required this.focusNode,
    required this.hint, required this.icon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted, this.trailing,
  });

  @override
  State<_RoundedInput> createState() => _RoundedInputState();
}

class _RoundedInputState extends State<_RoundedInput> {
  bool _focused = false;
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(() {
      if (mounted) setState(() => _focused = widget.focusNode.hasFocus);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _focused ? _terra.withOpacity(0.55) : _border,
          width: _focused ? 1.5 : 1.0,
        ),
        boxShadow: _focused ? [
          BoxShadow(color: _terra.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 3)),
        ] : [],
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        onSubmitted: widget.onSubmitted,
        style: const TextStyle(fontSize: 14.5, color: _ink, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: TextStyle(color: _subtle.withOpacity(0.7), fontSize: 14),
          prefixIcon: Icon(widget.icon, size: 18, color: _focused ? _terra : _subtle),
          suffixIcon: widget.trailing != null
              ? Padding(padding: const EdgeInsets.only(right: 4), child: widget.trailing)
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          isDense: true,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _PrimaryBtn
// ══════════════════════════════════════════════════════════════════════════════
class _PrimaryBtn extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onPressed;
  const _PrimaryBtn({required this.label, required this.loading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: _terra,
          foregroundColor: _white,
          disabledBackgroundColor: _terra.withOpacity(0.40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
        child: loading
            ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: _white))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label, style: const TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.w700, letterSpacing: 0.1,
                  )),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 17),
                ],
              ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _GhostBtn — bouton secondaire outline
// ══════════════════════════════════════════════════════════════════════════════
class _GhostBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  const _GhostBtn({required this.label, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 17),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: _ink,
          side: const BorderSide(color: _border, width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _ErrorBanner
// ══════════════════════════════════════════════════════════════════════════════
class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded, size: 15, color: Color(0xFFDC2626)),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: const TextStyle(
          fontSize: 12.5, color: Color(0xFFDC2626), fontWeight: FontWeight.w500,
        ))),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _DemoSheet — hidden bottom sheet (3-tap secret)
// ══════════════════════════════════════════════════════════════════════════════
class _DemoSheet extends StatefulWidget {
  final String selectedRole;
  final String? selectedSubtype;
  final List<(String, IconData, String)> roles;
  final Map<String, List<(String, String, IconData)>> subTypeMap;
  final void Function(String role, String? sub) onConfirm;
  const _DemoSheet({
    required this.selectedRole, required this.selectedSubtype,
    required this.roles, required this.subTypeMap, required this.onConfirm,
  });
  @override
  State<_DemoSheet> createState() => _DemoSheetState();
}

class _DemoSheetState extends State<_DemoSheet> {
  late String  _role;
  late String? _sub;
  @override
  void initState() {
    super.initState();
    _role = widget.selectedRole;
    _sub  = widget.selectedSubtype;
  }

  @override
  Widget build(BuildContext context) {
    final subs = widget.subTypeMap[_role] ?? [];
    return Container(
      decoration: const BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 8,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            width: 36, height: 4,
            decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2)),
          )),
          const Text('🔑  Compte de démonstration',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _ink)),
          const SizedBox(height: 4),
          const Text('Sélectionnez un profil pour tester.',
              style: TextStyle(fontSize: 12.5, color: _muted)),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: widget.roles.map((r) {
            final active = _role == r.$1;
            return GestureDetector(
              onTap: () => setState(() {
                _role = r.$1;
                _sub  = widget.subTypeMap[_role]?.firstOrNull?.$1;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? _terra : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: active ? _terra : _border),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(r.$2, size: 14, color: active ? _white : _muted),
                  const SizedBox(width: 6),
                  Text(r.$3, style: TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w600,
                    color: active ? _white : _ink,
                  )),
                ]),
              ),
            );
          }).toList()),
          if (subs.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Sous-type', style: TextStyle(
              fontSize: 11.5, fontWeight: FontWeight.w700, color: _muted,
            )),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: subs.map((s) {
              final active = _sub == s.$1;
              return GestureDetector(
                onTap: () => setState(() => _sub = s.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: active ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: active ? _forest : _border),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(s.$3, size: 13, color: active ? _forest : _muted),
                    const SizedBox(width: 5),
                    Text(s.$2, style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: active ? _forest : _ink,
                    )),
                  ]),
                ),
              );
            }).toList()),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => widget.onConfirm(_role, _sub),
            style: FilledButton.styleFrom(
              backgroundColor: _terra,
              foregroundColor: _white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Utiliser ce compte',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Dot pattern — desktop background
// ══════════════════════════════════════════════════════════════════════════════
class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withOpacity(0.03)..style = PaintingStyle.fill;
    const step = 32.0, r = 1.5;
    for (double x = step; x < size.width; x += step) {
      for (double y = step; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), r, p);
      }
    }
  }
  @override
  bool shouldRepaint(_) => false;
}

// ══════════════════════════════════════════════════════════════════════════════
// QR Scanner Overlay
// ══════════════════════════════════════════════════════════════════════════════
class _QrScannerOverlay extends StatelessWidget {
  final Function(BarcodeCapture) onDetect;
  final VoidCallback onClose;
  const _QrScannerOverlay({required this.onDetect, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        MobileScanner(onDetect: onDetect),
        Positioned.fill(child: CustomPaint(painter: _ScannerFramePainter())),
        Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            color: Colors.black87,
            padding: EdgeInsets.only(
              top: MediaQuery.paddingOf(context).top + 8,
              bottom: 12, left: 16, right: 16,
            ),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: _white),
                onPressed: onClose,
              ),
              const Expanded(
                child: Text('Scanner votre QR code Scolaris',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _white, fontWeight: FontWeight.w700, fontSize: 15)),
              ),
              const SizedBox(width: 48),
            ]),
          ),
        ),
        Positioned(
          bottom: 60, left: 0, right: 0,
          child: Text('Pointez la caméra vers le QR code de votre carte',
              textAlign: TextAlign.center,
              style: TextStyle(color: _white.withOpacity(0.75), fontSize: 13)),
        ),
      ]),
    );
  }
}

class _ScannerFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const box = 220.0, r = 16.0;
    final cx = size.width / 2, cy = size.height / 2;
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: box, height: box),
      const Radius.circular(r),
    );
    canvas.drawPath(
      Path.combine(PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRRect(rect),
      ),
      Paint()..color = Colors.black54,
    );
    final lp = Paint()..color = _white..strokeWidth = 3..strokeCap = StrokeCap.round;
    const arm = 28.0;
    final l = cx - box / 2, t = cy - box / 2;
    final rr = cx + box / 2, b = cy + box / 2;
    for (final (ox, oy, dx, dy) in [
      (l + r, t,    1.0,  0.0), (l, t + r,    0.0,  1.0),
      (rr - r, t,  -1.0,  0.0), (rr, t + r,   0.0,  1.0),
      (l + r, b,    1.0,  0.0), (l, b - r,    0.0, -1.0),
      (rr - r, b,  -1.0,  0.0), (rr, b - r,   0.0, -1.0),
    ]) {
      canvas.drawLine(Offset(ox, oy), Offset(ox + dx * arm, oy + dy * arm), lp);
    }
  }
  @override
  bool shouldRepaint(_) => false;
}
