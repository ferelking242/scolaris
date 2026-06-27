import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_theme.dart';
import '../../../presentation/providers/auth_providers.dart';
import 'forgot_password_screen.dart';

// ── Brand tokens ──────────────────────────────────────────────────────────────
const _terra  = ScolarisPalette.terracotta;   // #8B1A00
const _gold   = ScolarisPalette.gold;          // #C17F24
const _forest = ScolarisPalette.forestGreen;   // #1B5E20

// ── Shadcn neutral tokens ─────────────────────────────────────────────────────
const _ink    = Color(0xFF0F172A);
const _muted  = Color(0xFF64748B);
const _subtle = Color(0xFF94A3B8);
const _border = Color(0xFFE2E8F0);
const _bgPage = Color(0xFFFAFAF8);
const _white  = Colors.white;

// ── Hero gradient (desktop left panel) ───────────────────────────────────────
const _h1 = Color(0xFF1C0500);
const _h2 = Color(0xFF6B1200);
const _h3 = Color(0xFF3D1000);

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
  final _emailCtrl  = TextEditingController(text: 'student_lycee@scolaris.app');
  final _passCtrl   = TextEditingController(text: 'demo1234');
  final _emailFocus = FocusNode();
  final _passFocus  = FocusNode();

  bool    _loading       = false;
  bool    _obscure       = true;
  String? _error;
  bool    _showQrTab     = false;
  bool    _showQrScanner = false;
  int     _titleTaps     = 0;

  // Demo mode
  String  _selectedRole    = 'student';
  String? _selectedSubtype = 'lycee';

  late final AnimationController _fadeCtrl;
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
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    _fadeCtrl.dispose();
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
      if (mounted) setState(() => _error = (e.message as String).tr());
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
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _bgPage,
        resizeToAvoidBottomInset: false,
        body: FadeTransition(
          opacity: _fadeAnim,
          child: isDesktop ? _buildDesktop() : _buildMobile(),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DESKTOP — split hero | form
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildDesktop() {
    return Row(children: [
      const Expanded(flex: 44, child: _HeroPanel()),
      Expanded(
        flex: 56,
        child: Container(
          color: _white,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 52),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: _buildFormBody(isDesktop: true),
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MOBILE — landscape background + scrollable form
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildMobile() {
    final h           = MediaQuery.sizeOf(context).height;
    final landscapeH  = (h * 0.30).clamp(180.0, 280.0);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Stack(children: [
      // Landscape image fixed at bottom
      Positioned(
        bottom: 0, left: 0, right: 0,
        height: landscapeH,
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
                  _forest.withOpacity(0.3),
                ],
              ),
            ),
          ),
        ),
      ),
      // Scrollable form
      Positioned.fill(
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.only(
              bottom: (bottomInset > 0 ? bottomInset : landscapeH) + 24,
            ),
            child: _buildFormBody(isDesktop: false),
          ),
        ),
      ),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SHARED FORM BODY
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildFormBody({required bool isDesktop}) {
    final hPad = isDesktop ? 0.0 : 28.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(height: isDesktop ? 0 : 44),

        // Logo badge
        _LogoBadge(size: isDesktop ? 52 : 72),
        const SizedBox(height: 14),

        // Sparkle tag
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('✦', style: TextStyle(fontSize: 11, color: _gold)),
          const SizedBox(width: 7),
          Text(
            'Plateforme scolaire africaine',
            style: TextStyle(
              fontSize: 11.5, color: _muted,
              fontWeight: FontWeight.w500, letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 7),
          const Text('✦', style: TextStyle(fontSize: 11, color: _gold)),
        ]),
        const SizedBox(height: 18),

        // Title — 3 taps = demo mode
        GestureDetector(
          onTap: _onTitleTap,
          behavior: HitTestBehavior.opaque,
          child: RichText(
            textAlign: TextAlign.center,
            text: const TextSpan(
              style: TextStyle(fontFamily: 'Roboto', height: 1.2),
              children: [
                TextSpan(
                  text: 'Bon retour,\n',
                  style: TextStyle(
                    fontSize: 30, fontWeight: FontWeight.w800,
                    color: _ink, letterSpacing: -0.6,
                  ),
                ),
                TextSpan(
                  text: 'Bienvenue.',
                  style: TextStyle(
                    fontSize: 30, fontWeight: FontWeight.w800,
                    color: _terra, letterSpacing: -0.6,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Continuez vers votre espace Scolaris\net gérez votre établissement.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13, color: _muted, height: 1.55,
          ),
        ),
        SizedBox(height: isDesktop ? 36 : 30),

        // ── Tab bar ─────────────────────────────────────────────────────────
        Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad),
          child: _TabPicker(
            showQr: _showQrTab,
            onChanged: (v) => setState(() { _showQrTab = v; _error = null; }),
          ),
        ),
        const SizedBox(height: 28),

        // ── Tab content ──────────────────────────────────────────────────────
        Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
            child: _showQrTab
                ? _buildQrContent()
                : _buildEmailContent(),
          ),
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
                _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
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
        const SizedBox(height: 18),
        if (_error != null) ...[
          _ErrorBanner(message: _error!),
          const SizedBox(height: 14),
        ],
        _PrimaryButton(
          label: 'Se connecter',
          loading: _loading,
          onPressed: _submit,
        ),
        const SizedBox(height: 24),
        Center(
          child: Text('Scolaris · v0.1', style: TextStyle(
            fontSize: 10.5, color: _muted.withOpacity(0.35),
          )),
        ),
      ],
    );
  }

  // ── QR tab ─────────────────────────────────────────────────────────────────
  Widget _buildQrContent() {
    return Column(
      key: const ValueKey('qr'),
      children: [
        const SizedBox(height: 16),
        Container(
          width: 96, height: 96,
          decoration: BoxDecoration(
            color: _forest.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.qr_code_2_rounded, size: 48, color: _forest),
        ),
        const SizedBox(height: 20),
        const Text('Connexion par QR code', style: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w700, color: _ink,
        )),
        const SizedBox(height: 8),
        Text(
          'Pointez votre caméra vers le QR code\nde votre carte Scolaris.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: _muted, height: 1.6),
        ),
        const SizedBox(height: 28),
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
        const SizedBox(height: 24),
        Center(
          child: Text('Scolaris · v0.1', style: TextStyle(
            fontSize: 10.5, color: _muted.withOpacity(0.35),
          )),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _HeroPanel — desktop left dark panel
// ══════════════════════════════════════════════════════════════════════════════
class _HeroPanel extends StatelessWidget {
  const _HeroPanel();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_h1, _h2, _h3],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _DotPatternPainter()),
          Padding(
            padding: const EdgeInsets.fromLTRB(44, 52, 44, 44),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  _LogoBadge(size: 44, light: true),
                  const SizedBox(width: 12),
                  const Text('Scolaris', style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w900,
                    color: _white, letterSpacing: -0.8,
                  )),
                ]),
                const SizedBox(height: 36),
                const Text(
                  'La plateforme\nde gestion scolaire\nafricaine.',
                  style: TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w800,
                    color: _white, letterSpacing: -0.6, height: 1.25,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Élèves, notes, finances, emplois du temps\n— tout en un seul endroit.',
                  style: TextStyle(
                    fontSize: 13.5, color: _white.withOpacity(0.6),
                    height: 1.6,
                  ),
                ),
                const Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 300, maxHeight: 280),
                      child: _HeroLottie(),
                    ),
                  ),
                ),
                _FeaturePill(icon: Icons.groups_2_outlined,         label: 'Élèves, parents & enseignants'),
                _FeaturePill(icon: Icons.bar_chart_rounded,          label: 'Notes, bulletins & rapports'),
                _FeaturePill(icon: Icons.account_balance_outlined,   label: 'Finance & frais scolaires'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Lottie hero animation
// ══════════════════════════════════════════════════════════════════════════════
class _HeroLottie extends StatelessWidget {
  const _HeroLottie();

  @override
  Widget build(BuildContext context) {
    return Lottie.network(
      _lottieHero,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Lottie.asset(
        'assets/lottie/school_building.json',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(
          Icons.school_rounded,
          size: 100,
          color: _white.withOpacity(0.3),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Tab picker — Connexion | QR Code
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
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(children: [
        _Tab(
          label: 'Connexion',
          icon: Icons.mail_outline_rounded,
          selected: !showQr,
          onTap: () => onChanged(false),
        ),
        _Tab(
          label: 'QR Code',
          icon: Icons.qr_code_rounded,
          selected: showQr,
          onTap: () => onChanged(true),
        ),
      ]),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _Tab({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: selected ? _white : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            boxShadow: selected ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 4, offset: const Offset(0, 1),
              ),
            ] : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14,
                  color: selected ? _terra : _muted),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? _ink : _muted,
              )),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Demo bottom sheet — revealed by 3 taps on title
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
    final subtypes = widget.subTypeMap[_role] ?? [];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      decoration: const BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          const SizedBox(height: 12),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.play_circle_outline_rounded, size: 16, color: _gold),
              const SizedBox(width: 8),
              const Text('Mode démonstration', style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: _ink,
              )),
            ],
          ),
          const SizedBox(height: 6),
          Text('Choisissez un profil pour tester', style: TextStyle(
            fontSize: 13, color: _muted,
          )),
          const SizedBox(height: 24),
          // Roles
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8, runSpacing: 8,
              children: widget.roles.map((r) {
                final sel = r.$1 == _role;
                return GestureDetector(
                  onTap: () {
                    final subs = widget.subTypeMap[r.$1];
                    setState(() {
                      _role = r.$1;
                      _sub  = subs?.isNotEmpty == true ? subs!.first.$1 : null;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? _terra : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: sel ? _terra : _border),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(r.$2, size: 14, color: sel ? _white : _muted),
                      const SizedBox(width: 6),
                      Text(r.$3, style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: sel ? _white : _ink,
                      )),
                    ]),
                  ),
                );
              }).toList(),
            ),
          ),
          // Subtypes
          if (subtypes.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(color: Color(0xFFF1F5F9), height: 1),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8, runSpacing: 8,
                children: subtypes.map((s) {
                  final sel = s.$1 == _sub;
                  return GestureDetector(
                    onTap: () => setState(() => _sub = s.$1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: sel ? const Color(0xFFFEF3EE) : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: sel ? _terra.withOpacity(0.4) : _border,
                        ),
                      ),
                      child: Text(s.$2, style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                        color: sel ? _terra : _muted,
                      )),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          const SizedBox(height: 24),
          // Confirm button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _PrimaryButton(
              label: 'Utiliser ce profil',
              loading: false,
              onPressed: () => widget.onConfirm(_role, _sub),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Logo badge
// ══════════════════════════════════════════════════════════════════════════════
class _LogoBadge extends StatelessWidget {
  final double size;
  final bool light;
  const _LogoBadge({required this.size, this.light = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: light
              ? [_white.withOpacity(0.2), _white.withOpacity(0.08)]
              : [_terra, const Color(0xFFB52000)],
          radius: 1.2,
        ),
        shape: BoxShape.circle,
        boxShadow: light ? [] : [
          BoxShadow(
            color: _terra.withOpacity(0.28),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        'S',
        style: TextStyle(
          fontSize: size * 0.5,
          fontWeight: FontWeight.w900,
          color: _white,
          letterSpacing: -1,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Feature pill (hero panel)
// ══════════════════════════════════════════════════════════════════════════════
class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeaturePill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, size: 13, color: _white.withOpacity(0.85)),
        ),
        const SizedBox(width: 11),
        Text(label, style: TextStyle(
          fontSize: 13, color: _white.withOpacity(0.7),
          fontWeight: FontWeight.w500,
        )),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Shadcn-style input
// ══════════════════════════════════════════════════════════════════════════════
class _ShadcnInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String label;
  final String? hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffixIcon;

  const _ShadcnInput({
    required this.controller,
    this.focusNode,
    required this.label,
    this.hint,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(
        fontSize: 12.5, fontWeight: FontWeight.w600, color: _ink,
      )),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onFieldSubmitted: onSubmitted,
        style: const TextStyle(fontSize: 14, color: _ink),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: _subtle, fontSize: 13.5),
          prefixIcon: Icon(icon, size: 16, color: _subtle),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: _white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: _border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: _border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: _terra, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: Color(0xFFEF4444)),
          ),
        ),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Primary button — flat, no shadow
// ══════════════════════════════════════════════════════════════════════════════
class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onPressed;
  final IconData? icon;

  const _PrimaryButton({
    required this.label,
    required this.loading,
    required this.onPressed,
    this.icon,
  });

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
                    fontSize: 14.5, fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
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
// Error banner
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
// Dot pattern painter
// ══════════════════════════════════════════════════════════════════════════════
class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dot = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..style = PaintingStyle.fill;
    const step = 28.0, r = 1.2;
    for (double x = step; x < size.width; x += step) {
      for (double y = step; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), r, dot);
      }
    }
    final ring = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(Offset(size.width * 0.82, size.height * 0.1), 90, ring);
    canvas.drawCircle(Offset(size.width * 0.12, size.height * 0.88), 110, ring);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
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
