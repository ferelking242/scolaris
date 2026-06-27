import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_theme.dart';
import '../../../presentation/providers/auth_providers.dart';
import 'forgot_password_screen.dart';

// ── Brand tokens ──────────────────────────────────────────────────────────────
const _terra  = ScolarisPalette.terracotta;
const _gold   = ScolarisPalette.gold;
const _forest = ScolarisPalette.forestGreen;

// ── Neutral tokens ────────────────────────────────────────────────────────────
const _ink    = Color(0xFF0F172A);
const _muted  = Color(0xFF64748B);
const _subtle = Color(0xFF94A3B8);
const _border = Color(0xFFE2E8F0);
const _white  = Colors.white;

// ── LottieFiles CDN ───────────────────────────────────────────────────────────
const _lottieHero = 'https://lottie.host/4db68bbd-31f6-4cd8-84eb-189de081159a/krfYT2LQGW.json';

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
  bool    _showQrTab     = false;
  bool    _showQrScanner = false;
  int     _titleTaps     = 0;

  String  _selectedRole    = 'student';
  String? _selectedSubtype = 'lycee';

  late final AnimationController _slideCtrl;
  late final Animation<Offset>   _slideAnim;
  late final Animation<double>   _fadeAnim;

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
    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _fadeAnim = CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut);
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  // ── 3-tap secret demo reveal ───────────────────────────────────────────────
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
                ? '${role}_${sub}@scolaris.app'
                : '$role@scolaris.app';
            _passCtrl.text   = 'demo1234';
            _error           = null;
            _showQrTab       = false;
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

  // ── QR ─────────────────────────────────────────────────────────────────────
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
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0500),
        resizeToAvoidBottomInset: false,
        body: isDesktop ? _buildDesktop() : _buildMobile(),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DESKTOP — image left panel | form right
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildDesktop() {
    return Row(children: [
      // Left hero panel — 45%
      Expanded(
        flex: 45,
        child: Stack(fit: StackFit.expand, children: [
          // Background image
          Image.asset(
            'assets/images/login_bg.webp',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1C0500), Color(0xFF6B1200), Color(0xFF3D1000)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          // Dark overlay gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.55),
                  Colors.black.withOpacity(0.30),
                  Colors.black.withOpacity(0.70),
                ],
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(40, 48, 40, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo + name
                Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: _white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _white.withOpacity(0.20)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset('assets/images/logo.png', fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                          child: Text('S', style: TextStyle(
                            color: _white, fontSize: 20, fontWeight: FontWeight.w900,
                          )),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text('Scolaris', style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w900,
                    color: _white, letterSpacing: -0.5,
                  )),
                ]),
                const Spacer(),
                // Headline
                const Text(
                  'La plateforme\nde gestion scolaire\nafricaine.',
                  style: TextStyle(
                    fontSize: 36, fontWeight: FontWeight.w800,
                    color: _white, height: 1.15, letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Élèves, notes, finances, emplois du temps\n— tout en un seul endroit.',
                  style: TextStyle(
                    fontSize: 14, color: _white.withOpacity(0.65), height: 1.65,
                  ),
                ),
                const SizedBox(height: 32),
                // Feature pills
                ...[
                  (Icons.groups_2_outlined,        'Élèves, parents & enseignants'),
                  (Icons.bar_chart_rounded,         'Notes, bulletins & rapports'),
                  (Icons.account_balance_outlined,  'Finance & frais scolaires'),
                ].map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: _gold.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Icon(e.$1, size: 14, color: _gold),
                    ),
                    const SizedBox(width: 10),
                    Text(e.$2, style: TextStyle(
                      fontSize: 13, color: _white.withOpacity(0.80),
                      fontWeight: FontWeight.w500,
                    )),
                  ]),
                )),
              ],
            ),
          ),
        ]),
      ),
      // Right form panel — 55%
      Expanded(
        flex: 55,
        child: Container(
          color: _white,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 72, vertical: 52),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: _buildFormBody(isDesktop: true),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MOBILE — full-screen background + card bottom sheet style
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildMobile() {
    final size        = MediaQuery.sizeOf(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final cardTop     = size.height * 0.38;

    return Stack(children: [
      // Full-screen background
      Positioned.fill(
        child: Image.asset(
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
      ),
      // Dark overlay
      Positioned.fill(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.35, 0.65],
              colors: [
                Colors.black.withOpacity(0.50),
                Colors.black.withOpacity(0.15),
                Colors.black.withOpacity(0.10),
              ],
            ),
          ),
        ),
      ),
      // Top area — logo + tagline
      Positioned(
        top: MediaQuery.paddingOf(context).top + 28,
        left: 28,
        right: 28,
        child: Row(children: [
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
            fontSize: 18, fontWeight: FontWeight.w900,
            color: _white, letterSpacing: -0.3,
          )),
        ]),
      ),
      // White card — slides up from bottom
      Positioned(
        top: cardTop,
        left: 0, right: 0, bottom: 0,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Container(
              decoration: const BoxDecoration(
                color: _white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: EdgeInsets.only(
                  left: 28, right: 28, top: 8,
                  bottom: (bottomInset > 0 ? bottomInset : 28) + 16,
                ),
                child: _buildFormBody(isDesktop: false),
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SHARED FORM BODY
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildFormBody({required bool isDesktop}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (!isDesktop) ...[
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDE3EA),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 6),
        ] else
          const SizedBox(height: 8),

        // Title — 3 taps = demo mode
        GestureDetector(
          onTap: _onTitleTap,
          behavior: HitTestBehavior.opaque,
          child: Column(
            crossAxisAlignment: isDesktop
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              RichText(
                textAlign: isDesktop ? TextAlign.left : TextAlign.center,
                text: const TextSpan(
                  style: TextStyle(fontFamily: 'Roboto', height: 1.15),
                  children: [
                    TextSpan(
                      text: 'Bon retour, ',
                      style: TextStyle(
                        fontSize: 28, fontWeight: FontWeight.w800,
                        color: _ink, letterSpacing: -0.6,
                      ),
                    ),
                    TextSpan(
                      text: 'Bienvenue.',
                      style: TextStyle(
                        fontSize: 28, fontWeight: FontWeight.w800,
                        color: _terra, letterSpacing: -0.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Connectez-vous à votre espace Scolaris.',
                textAlign: isDesktop ? TextAlign.left : TextAlign.center,
                style: const TextStyle(
                  fontSize: 13, color: _muted, height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // ── Tab bar ─────────────────────────────────────────────────────────
        _TabPicker(
          showQr: _showQrTab,
          onChanged: (v) => setState(() { _showQrTab = v; _error = null; }),
        ),
        const SizedBox(height: 24),

        // ── Tab content ──────────────────────────────────────────────────────
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
          child: _showQrTab ? _buildQrContent() : _buildEmailContent(),
        ),
      ],
    );
  }

  // ── Email form ─────────────────────────────────────────────────────────────
  Widget _buildEmailContent() {
    return Column(
      key: const ValueKey('email'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ShadcnInput(
          controller: _emailCtrl,
          focusNode: _emailFocus,
          label: 'Adresse e-mail',
          hint: 'prenom.nom@ecole.com',
          icon: Icons.alternate_email_rounded,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _passFocus.requestFocus(),
        ),
        const SizedBox(height: 14),
        _ShadcnInput(
          controller: _passCtrl,
          focusNode: _passFocus,
          label: 'Mot de passe',
          hint: '••••••••',
          icon: Icons.lock_outline_rounded,
          obscureText: _obscure,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          suffixIcon: GestureDetector(
            onTap: () => setState(() => _obscure = !_obscure),
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(
                _obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 17, color: _subtle,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
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
        const SizedBox(height: 20),
        if (_error != null) ...[
          _ErrorBanner(message: _error!),
          const SizedBox(height: 16),
        ],
        _PrimaryButton(
          label: 'Se connecter',
          loading: _loading,
          onPressed: _submit,
        ),
        const SizedBox(height: 28),
        Center(child: Text('Scolaris · v0.1', style: TextStyle(
          fontSize: 10.5, color: _muted.withOpacity(0.35),
        ))),
      ],
    );
  }

  // ── QR tab ─────────────────────────────────────────────────────────────────
  Widget _buildQrContent() {
    return Column(
      key: const ValueKey('qr'),
      children: [
        const SizedBox(height: 12),
        Container(
          width: 88, height: 88,
          decoration: BoxDecoration(
            color: _forest.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.qr_code_2_rounded, size: 44, color: _forest),
        ),
        const SizedBox(height: 18),
        const Text('Connexion par QR code', style: TextStyle(
          fontSize: 17, fontWeight: FontWeight.w700, color: _ink,
        )),
        const SizedBox(height: 8),
        Text(
          'Pointez votre caméra vers le QR code\nde votre carte Scolaris.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: _muted, height: 1.6),
        ),
        const SizedBox(height: 24),
        if (_error != null) ...[
          _ErrorBanner(message: _error!),
          const SizedBox(height: 14),
        ],
        _PrimaryButton(
          label: 'Ouvrir le scanner',
          loading: false,
          onPressed: () => setState(() => _showQrScanner = true),
          icon: Icons.qr_code_scanner_rounded,
        ),
        const SizedBox(height: 28),
        Center(child: Text('Scolaris · v0.1', style: TextStyle(
          fontSize: 10.5, color: _muted.withOpacity(0.35),
        ))),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _TabPicker — Email | QR Code
// ══════════════════════════════════════════════════════════════════════════════
class _TabPicker extends StatelessWidget {
  final bool showQr;
  final ValueChanged<bool> onChanged;
  const _TabPicker({required this.showQr, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(children: [
        _Tab(
          label: 'E-mail',
          icon: Icons.email_outlined,
          active: !showQr,
          onTap: () => onChanged(false),
        ),
        _Tab(
          label: 'QR Code',
          icon: Icons.qr_code_rounded,
          active: showQr,
          onTap: () => onChanged(true),
        ),
      ]),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _Tab({required this.label, required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: active ? _white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: active ? [
              BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 8, offset: const Offset(0, 2)),
            ] : null,
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 14, color: active ? _terra : _muted),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: active ? _ink : _muted,
            )),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _ShadcnInput
// ══════════════════════════════════════════════════════════════════════════════
class _ShadcnInput extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffixIcon;

  const _ShadcnInput({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.suffixIcon,
  });

  @override
  State<_ShadcnInput> createState() => _ShadcnInputState();
}

class _ShadcnInputState extends State<_ShadcnInput> {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600, color: _ink,
        )),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _focused ? _terra.withOpacity(0.6) : _border,
              width: _focused ? 1.5 : 1,
            ),
          ),
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
              hintStyle: TextStyle(color: _subtle.withOpacity(0.7), fontSize: 13.5),
              prefixIcon: Icon(widget.icon, size: 17, color: _focused ? _terra : _subtle),
              suffixIcon: widget.suffixIcon,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _PrimaryButton
// ══════════════════════════════════════════════════════════════════════════════
class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onPressed;
  final IconData? icon;
  const _PrimaryButton({required this.label, required this.loading, required this.onPressed, this.icon});

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
          disabledBackgroundColor: _terra.withOpacity(0.42),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
        child: loading
            ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: _white))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18),
                    const SizedBox(width: 8),
                  ],
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
// _ErrorBanner
// ══════════════════════════════════════════════════════════════════════════════
class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFDC2626)),
        const SizedBox(width: 9),
        Expanded(child: Text(message, style: const TextStyle(
          fontSize: 12.5, color: Color(0xFFDC2626), fontWeight: FontWeight.w500,
        ))),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _DemoSheet — bottom sheet sélection compte démo (3 taps secret)
// ══════════════════════════════════════════════════════════════════════════════
class _DemoSheet extends StatefulWidget {
  final String selectedRole;
  final String? selectedSubtype;
  final List<(String, IconData, String)> roles;
  final Map<String, List<(String, String, IconData)>> subTypeMap;
  final void Function(String role, String? sub) onConfirm;

  const _DemoSheet({
    required this.selectedRole,
    required this.selectedSubtype,
    required this.roles,
    required this.subTypeMap,
    required this.onConfirm,
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
            decoration: BoxDecoration(
              color: const Color(0xFFDDE3EA),
              borderRadius: BorderRadius.circular(2),
            ),
          )),
          const Text('🔑  Compte de démonstration',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _ink)),
          const SizedBox(height: 4),
          const Text('Sélectionnez un profil pour tester l\'application.',
              style: TextStyle(fontSize: 12.5, color: _muted)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: widget.roles.map((r) {
              final active = _role == r.$1;
              return GestureDetector(
                onTap: () => setState(() {
                  _role = r.$1;
                  _sub  = widget.subTypeMap[_role]?.firstOrNull?.$1;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
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
            }).toList(),
          ),
          if (subs.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Sous-type', style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: _muted,
            )),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: subs.map((s) {
                final active = _sub == s.$1;
                return GestureDetector(
                  onTap: () => setState(() => _sub = s.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
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
              }).toList(),
            ),
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
            child: const Text('Utiliser ce compte', style: TextStyle(
              fontWeight: FontWeight.w700, fontSize: 14,
            )),
          ),
        ],
      ),
    );
  }
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
    final rr = cx + box / 2, b  = cy + box / 2;
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
  bool shouldRepaint(covariant CustomPainter _) => false;
}
