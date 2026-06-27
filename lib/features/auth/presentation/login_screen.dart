import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_theme.dart';
import '../../../presentation/providers/auth_providers.dart';
import 'forgot_password_screen.dart';

// ── Brand tokens ──────────────────────────────────────────────────────────────
const _terra  = ScolarisPalette.terracotta;
const _gold   = ScolarisPalette.gold;
const _forest = ScolarisPalette.forestGreen;

const _ink    = Color(0xFF0F172A);
const _muted  = Color(0xFF64748B);
const _subtle = Color(0xFF94A3B8);
const _border = Color(0xFFE2E8F0);
const _white  = Colors.white;
const _pageBg = Color(0xFFF7F8FA);

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

  late final AnimationController _enterCtrl;
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
      ('primaire',   'Primaire',   Icons.child_care_outlined),
      ('college',    'Collège',    Icons.school_outlined),
      ('lycee',      'Lycée',      Icons.account_balance_outlined),
      ('univ',       'Université', Icons.science_outlined),
    ],
    'teacher': [
      ('primaire',   'Primaire',   Icons.child_care_outlined),
      ('secondaire', 'Secondaire', Icons.school_outlined),
      ('univ',       'Université', Icons.science_outlined),
    ],
    'parent': [
      ('primaire', 'Primaire', Icons.child_care_outlined),
      ('college',  'Collège',  Icons.school_outlined),
      ('lycee',    'Lycée',    Icons.account_balance_outlined),
    ],
    'admin': [
      ('directeur',  'Directeur',   Icons.badge_outlined),
      ('secretaire', 'Secrétariat', Icons.person_outlined),
      ('dg',         'Dir. Gén.',   Icons.workspace_premium_outlined),
    ],
    'finance': [
      ('comptable', 'Comptable', Icons.calculate_outlined),
      ('caissier',  'Caissier',  Icons.point_of_sale_outlined),
    ],
    'surveillance': [
      ('sg',  'Surv. Gén.', Icons.security_outlined),
      ('aux', 'Auxiliaire', Icons.shield_outlined),
    ],
  };

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic));
    _enterCtrl.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose(); _passCtrl.dispose();
    _emailFocus.dispose(); _passFocus.dispose();
    _enterCtrl.dispose();
    super.dispose();
  }

  // ── 3-tap secret ──────────────────────────────────────────────────────────
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
            _emailCtrl.text  = sub != null
                ? '${role}_$sub@scolaris.app'
                : '$role@scolaris.app';
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

  // ── Root build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_showQrScanner) {
      return _QrScannerOverlay(
        onDetect: _handleQr,
        onClose: () => setState(() => _showQrScanner = false),
      );
    }

    final isDesktop = MediaQuery.sizeOf(context).width >= 900;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDesktop ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: isDesktop
            ? const Color(0xFF12061A)
            : _pageBg,
        resizeToAvoidBottomInset: false,
        body: isDesktop ? _buildDesktop() : _buildMobile(),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DESKTOP — full-page gradient + 2 boxes séparées
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildDesktop() {
    return Stack(fit: StackFit.expand, children: [
      // ── Fond gradient ────────────────────────────────────────────────────
      Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF12061A), Color(0xFF2D0D00), Color(0xFF12061A)],
            stops: [0.0, 0.55, 1.0],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      // Léger pattern de points
      Positioned.fill(child: CustomPaint(painter: _DotsBg())),

      // ── Les 2 boxes centrées ─────────────────────────────────────────────
      Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: LayoutBuilder(builder: (ctx, constraints) {
              final maxW = constraints.maxWidth.clamp(0.0, 1100.0);
              final maxH = constraints.maxHeight.clamp(0.0, 620.0);
              return SizedBox(
                width: maxW * 0.88,
                height: maxH * 0.86,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Box gauche — image + hero ────────────────────────
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: SizedBox(
                        width: maxW * 0.88 * 0.41,
                        child: Stack(fit: StackFit.expand, children: [
                          Image.asset(
                            'assets/images/login_bg.webp',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFF1C0500), Color(0xFF8B2200)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                            ),
                          ),
                          // Overlay gradient sombre
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withOpacity(0.48),
                                  Colors.black.withOpacity(0.20),
                                  Colors.black.withOpacity(0.72),
                                ],
                                stops: const [0.0, 0.45, 1.0],
                              ),
                            ),
                          ),
                          // Contenu
                          Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Logo
                                Row(children: [
                                  Container(
                                    width: 38, height: 38,
                                    decoration: BoxDecoration(
                                      color: _white.withOpacity(0.14),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: _white.withOpacity(0.22)),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.asset('assets/images/logo.png',
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Center(
                                            child: Text('S', style: TextStyle(
                                                color: _white, fontSize: 20,
                                                fontWeight: FontWeight.w900)),
                                          )),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Text('Scolaris', style: TextStyle(
                                    color: _white, fontSize: 20,
                                    fontWeight: FontWeight.w900, letterSpacing: -0.5,
                                  )),
                                ]),
                                const Spacer(),
                                const Text(
                                  'La plateforme\nscolaire africaine.',
                                  style: TextStyle(
                                    color: _white, fontSize: 30,
                                    fontWeight: FontWeight.w800,
                                    height: 1.18, letterSpacing: -0.8,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Élèves · Notes · Finance\nEmplois du temps',
                                  style: TextStyle(
                                    color: _white.withOpacity(0.58),
                                    fontSize: 13, height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  '© ${DateTime.now().year} Scolaris',
                                  style: TextStyle(
                                    color: _white.withOpacity(0.28), fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ]),
                      ),
                    ),

                    const SizedBox(width: 14),

                    // ── Box droite — formulaire ──────────────────────────
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          color: const Color(0xFFF6F8FC),
                          child: _DesktopForm(
                            emailCtrl: _emailCtrl,
                            passCtrl: _passCtrl,
                            emailFocus: _emailFocus,
                            passFocus: _passFocus,
                            loading: _loading,
                            obscure: _obscure,
                            error: _error,
                            onObscureToggle: () => setState(() => _obscure = !_obscure),
                            onSubmit: _submit,
                            onTitleTap: _onTitleTap,
                            onQr: () => setState(() => _showQrScanner = true),
                            onForgot: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MOBILE — flat white, no box, illustration en bas
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildMobile() {
    final size  = MediaQuery.sizeOf(context);
    final pad   = MediaQuery.paddingOf(context);
    final keyb  = MediaQuery.viewInsetsOf(context).bottom;

    return Stack(children: [
      // Fond
      Positioned.fill(child: Container(color: _pageBg)),

      // Illustration + fondu au bas
      if (keyb < 80) ...[
        Positioned(
          bottom: 0, left: 0, right: 0,
          height: size.height * 0.24,
          child: Image.asset(
            'assets/images/login_bg.webp',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            errorBuilder: (_, __, ___) => Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_forest.withOpacity(0.04), _forest.withOpacity(0.22)],
                ),
              ),
            ),
          ),
        ),
        // Fondu pour lisser la transition
        Positioned(
          bottom: size.height * 0.18,
          left: 0, right: 0,
          height: size.height * 0.10,
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
      ],

      // Contenu scrollable
      Positioned.fill(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.only(
                left: 30, right: 30,
                top: pad.top + 36,
                bottom: (keyb > 0 ? keyb : size.height * 0.25) + 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo centré
                  Center(
                    child: Container(
                      width: 70, height: 70,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: _terra.withOpacity(0.22),
                            blurRadius: 20, offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.asset('assets/images/logo.png',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [_terra, Color(0xFFD35400)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: const Center(child: Text('S', style: TextStyle(
                                color: _white, fontSize: 32, fontWeight: FontWeight.w900,
                              ))),
                            )),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Titre (3 taps secret)
                  GestureDetector(
                    onTap: _onTitleTap,
                    behavior: HitTestBehavior.opaque,
                    child: Column(children: [
                      RichText(
                        textAlign: TextAlign.center,
                        text: const TextSpan(
                          style: TextStyle(fontFamily: 'Roboto', height: 1.15),
                          children: [
                            TextSpan(
                              text: 'Bon retour,\n',
                              style: TextStyle(
                                fontSize: 31, fontWeight: FontWeight.w800,
                                color: _ink, letterSpacing: -0.8,
                              ),
                            ),
                            TextSpan(
                              text: 'Bienvenue.',
                              style: TextStyle(
                                fontSize: 31, fontWeight: FontWeight.w800,
                                color: _terra, letterSpacing: -0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Connectez-vous à votre espace Scolaris.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13.5, color: _muted, height: 1.5),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 34),

                  // Email
                  _MobileField(
                    controller: _emailCtrl,
                    focusNode: _emailFocus,
                    hint: 'Adresse e-mail',
                    icon: Icons.alternate_email_rounded,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _passFocus.requestFocus(),
                  ),
                  const SizedBox(height: 14),

                  // Mot de passe
                  _MobileField(
                    controller: _passCtrl,
                    focusNode: _passFocus,
                    hint: 'Mot de passe',
                    icon: Icons.lock_outline_rounded,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    suffix: GestureDetector(
                      onTap: () => setState(() => _obscure = !_obscure),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: Icon(
                          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          size: 19, color: _subtle,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Mot de passe oublié
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                      child: const Text('Mot de passe oublié ?', style: TextStyle(
                        fontSize: 13.5, color: _terra, fontWeight: FontWeight.w600,
                      )),
                    ),
                  ),
                  const SizedBox(height: 22),

                  if (_error != null) ...[
                    _ErrorBanner(message: _error!),
                    const SizedBox(height: 16),
                  ],

                  // Se connecter
                  _FilledBtn(
                    label: 'Se connecter',
                    loading: _loading,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 12),

                  // QR secondaire
                  _OutlineBtn(
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
// _DesktopForm — contenu de la box droite
// ══════════════════════════════════════════════════════════════════════════════
class _DesktopForm extends StatelessWidget {
  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;
  final FocusNode emailFocus;
  final FocusNode passFocus;
  final bool loading;
  final bool obscure;
  final String? error;
  final VoidCallback onObscureToggle;
  final AsyncCallback onSubmit;
  final VoidCallback onTitleTap;
  final VoidCallback onQr;
  final VoidCallback onForgot;

  const _DesktopForm({
    required this.emailCtrl, required this.passCtrl,
    required this.emailFocus, required this.passFocus,
    required this.loading, required this.obscure, required this.error,
    required this.onObscureToggle, required this.onSubmit,
    required this.onTitleTap, required this.onQr, required this.onForgot,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(44, 36, 44, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // En-tête
          GestureDetector(
            onTap: onTitleTap,
            behavior: HitTestBehavior.opaque,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Connexion', style: TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w800,
                  color: _ink, letterSpacing: -0.6,
                )),
                const SizedBox(height: 4),
                const Text('Bon retour sur Scolaris — accédez à votre espace.',
                    style: TextStyle(fontSize: 13, color: _muted, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Email
          _DeskField(
            controller: emailCtrl,
            focusNode: emailFocus,
            label: 'Adresse e-mail',
            hint: 'prenom.nom@ecole.com',
            icon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => passFocus.requestFocus(),
          ),
          const SizedBox(height: 22),

          // Mot de passe
          _DeskField(
            controller: passCtrl,
            focusNode: passFocus,
            label: 'Mot de passe',
            hint: '••••••••',
            icon: Icons.lock_outline_rounded,
            obscureText: obscure,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onSubmit(),
            trailing: GestureDetector(
              onTap: onObscureToggle,
              child: Icon(
                obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: 17, color: _subtle,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Mot de passe oublié
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: onForgot,
              child: const Text('Mot de passe oublié ?', style: TextStyle(
                fontSize: 12.5, color: _terra, fontWeight: FontWeight.w600,
              )),
            ),
          ),
          const SizedBox(height: 20),

          if (error != null) ...[
            _ErrorBanner(message: error!),
            const SizedBox(height: 14),
          ],

          const Spacer(),

          // Se connecter
          _FilledBtn(label: 'Se connecter', loading: loading, onPressed: onSubmit),
          const SizedBox(height: 10),

          // QR
          _OutlineBtn(
            label: 'Scanner mon QR code',
            icon: Icons.qr_code_scanner_rounded,
            onPressed: onQr,
          ),

          const SizedBox(height: 24),

          // Divider
          Container(height: 1, color: const Color(0xFFECF0F4)),
          const SizedBox(height: 18),

          // Réseaux sociaux
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (final icon in [
              Icons.linkedin,
              Icons.camera_alt_outlined,
              Icons.facebook,
              Icons.telegram_outlined,
            ]) ...[
              _SocialIcon(icon: icon),
              const SizedBox(width: 8),
            ],
          ]),
          const SizedBox(height: 12),

          // Contacts
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.phone_outlined, size: 13, color: _subtle),
              const SizedBox(width: 5),
              Text('+237 6 XX XX XX XX', style: TextStyle(
                fontSize: 11.5, color: _muted,
              )),
              const SizedBox(width: 16),
              Icon(Icons.mail_outline_rounded, size: 13, color: _subtle),
              const SizedBox(width: 5),
              Text('contact@scolaris.app', style: TextStyle(
                fontSize: 11.5, color: _muted,
              )),
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _DeskField — input desktop underline
// ══════════════════════════════════════════════════════════════════════════════
class _DeskField extends StatefulWidget {
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

  const _DeskField({
    required this.controller, required this.focusNode,
    required this.label, required this.hint, required this.icon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted, this.trailing,
  });

  @override
  State<_DeskField> createState() => _DeskFieldState();
}

class _DeskFieldState extends State<_DeskField> {
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
    final activeColor = _focused ? _terra : const Color(0xFFCBD5E1);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.label, style: TextStyle(
        fontSize: 11, fontWeight: FontWeight.w700,
        color: _focused ? _terra : _muted,
        letterSpacing: 0.5,
      )),
      const SizedBox(height: 6),
      Row(children: [
        Icon(widget.icon, size: 15, color: _focused ? _terra : _subtle),
        const SizedBox(width: 10),
        Expanded(
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
              hintStyle: TextStyle(color: _subtle.withOpacity(0.55), fontSize: 13.5),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              suffixIcon: widget.trailing,
            ),
          ),
        ),
      ]),
      AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: _focused ? 1.5 : 1,
        color: activeColor,
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _MobileField — input mobile avec bordure arrondie
// ══════════════════════════════════════════════════════════════════════════════
class _MobileField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;

  const _MobileField({
    required this.controller, required this.focusNode,
    required this.hint, required this.icon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted, this.suffix,
  });

  @override
  State<_MobileField> createState() => _MobileFieldState();
}

class _MobileFieldState extends State<_MobileField> {
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
          color: _focused ? _terra.withOpacity(0.6) : _border,
          width: _focused ? 1.5 : 1,
        ),
        boxShadow: _focused
            ? [BoxShadow(color: _terra.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))]
            : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        onSubmitted: widget.onSubmitted,
        style: const TextStyle(fontSize: 15, color: _ink, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: TextStyle(color: _subtle.withOpacity(0.65), fontSize: 14.5),
          prefixIcon: Icon(widget.icon, size: 19,
              color: _focused ? _terra : _subtle),
          suffixIcon: widget.suffix,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          isDense: true,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _FilledBtn
// ══════════════════════════════════════════════════════════════════════════════
class _FilledBtn extends StatelessWidget {
  final String label;
  final bool loading;
  final AsyncCallback onPressed;
  const _FilledBtn({required this.label, required this.loading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity, height: 52,
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
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(label, style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.1,
                )),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, size: 17),
              ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _OutlineBtn
// ══════════════════════════════════════════════════════════════════════════════
class _OutlineBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  const _OutlineBtn({required this.label, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity, height: 48,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 17),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: _ink,
          side: BorderSide(color: _border, width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _SocialIcon — icône réseau social desktop
// ══════════════════════════════════════════════════════════════════════════════
class _SocialIcon extends StatelessWidget {
  final IconData icon;
  const _SocialIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        shape: BoxShape.circle,
        border: Border.all(color: _border),
      ),
      child: Icon(icon, size: 15, color: _muted),
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
// _DemoSheet
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
            margin: const EdgeInsets.only(bottom: 16), width: 36, height: 4,
            decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2)),
          )),
          const Text('🔑  Compte démo',
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
              backgroundColor: _terra, foregroundColor: _white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
              elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14),
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
// _DotsBg — fond de points subtil (desktop)
// ══════════════════════════════════════════════════════════════════════════════
class _DotsBg extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withOpacity(0.025)..style = PaintingStyle.fill;
    const step = 36.0, r = 1.6;
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
        Positioned.fill(child: CustomPaint(painter: _ScannerFrame())),
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

class _ScannerFrame extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const box = 220.0, r = 16.0;
    final cx = size.width / 2, cy = size.height / 2;
    canvas.drawPath(
      Path.combine(PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRRect(RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, cy), width: box, height: box),
          const Radius.circular(r),
        )),
      ),
      Paint()..color = Colors.black54,
    );
    final lp = Paint()..color = _white..strokeWidth = 3..strokeCap = StrokeCap.round;
    const arm = 28.0;
    final l = cx - box / 2, t = cy - box / 2, rr = cx + box / 2, b = cy + box / 2;
    for (final (ox, oy, dx, dy) in [
      (l + r, t, 1.0, 0.0), (l, t + r, 0.0, 1.0),
      (rr - r, t, -1.0, 0.0), (rr, t + r, 0.0, 1.0),
      (l + r, b, 1.0, 0.0), (l, b - r, 0.0, -1.0),
      (rr - r, b, -1.0, 0.0), (rr, b - r, 0.0, -1.0),
    ]) {
      canvas.drawLine(Offset(ox, oy), Offset(ox + dx * arm, oy + dy * arm), lp);
    }
  }
  @override
  bool shouldRepaint(_) => false;
}
