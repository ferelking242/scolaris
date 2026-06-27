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
const _terra  = ScolarisPalette.terracotta;
const _gold   = ScolarisPalette.gold;

// ── Shadcn design tokens ──────────────────────────────────────────────────────
const _ink    = Color(0xFF0F172A);
const _muted  = Color(0xFF64748B);
const _subtle = Color(0xFF94A3B8);
const _border = Color(0xFFE2E8F0);
const _bg     = Color(0xFFF8FAFC);
const _white  = Colors.white;

// Hero gradient
const _h1 = Color(0xFF1C0500);
const _h2 = Color(0xFF6B1200);
const _h3 = Color(0xFF3D1000);

// ── LottieFiles CDN ───────────────────────────────────────────────────────────
const _lottieHero = 'https://lottie.host/4db68bbd-31f6-4cd8-84eb-189de081159a/krfYT2LQGW.json';

// ═════════════════════════════════════════════════════════════════════════════
// LoginScreen
// ═════════════════════════════════════════════════════════════════════════════
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
  String  _selectedRole    = 'student';
  String? _selectedSubtype = 'lycee';
  bool    _showQrScanner   = false;

  late final AnimationController _fadeCtrl;
  late final Animation<double>   _fadeAnim;
  late final AnimationController _slideCtrl;
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
      ('primaire',   'Primaire',   Icons.child_care_outlined),
      ('college',    'Collège',    Icons.school_outlined),
      ('lycee',      'Lycée',      Icons.account_balance_outlined),
    ],
    'admin': [
      ('directeur',  'Directeur',  Icons.badge_outlined),
      ('secretaire', 'Secrétariat',Icons.person_outlined),
      ('dg',         'Dir. Gén.',  Icons.workspace_premium_outlined),
    ],
    'finance': [
      ('comptable',  'Comptable',  Icons.calculate_outlined),
      ('caissier',   'Caissier',   Icons.point_of_sale_outlined),
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
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
    _fadeCtrl.forward();
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) _slideCtrl.forward();
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  void _selectRole(String role) {
    final subs     = _subTypeMap[role];
    final firstSub = subs?.isNotEmpty == true ? subs!.first.$1 : null;
    setState(() {
      _selectedRole    = role;
      _selectedSubtype = firstSub;
      _emailCtrl.text  = firstSub != null
          ? '${role}_${firstSub}@scolaris.app'
          : '$role@scolaris.app';
      _passCtrl.text   = 'demo1234';
      _error           = null;
    });
  }

  void _selectSubtype(String sub) {
    setState(() {
      _selectedSubtype = sub;
      _emailCtrl.text  = '${_selectedRole}_${sub}@scolaris.app';
      _error           = null;
    });
  }

  Future<void> _submit() async {
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
      if (mounted) setState(() => _error = 'auth.errors.failed'.tr());
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
    final isTablet  = w >= 600 && w < 900;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: isDesktop ? _bg : _white,
        body: FadeTransition(
          opacity: _fadeAnim,
          child: isDesktop
              ? _DesktopLayout(state: this)
              : _MobileLayout(state: this, isTablet: isTablet),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Desktop — split hero | form
// ═════════════════════════════════════════════════════════════════════════════
class _DesktopLayout extends StatelessWidget {
  final _LoginScreenState state;
  const _DesktopLayout({required this.state});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(flex: 44, child: _HeroPanel()),
        Expanded(
          flex: 56,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 52),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: SlideTransition(
                  position: state._slideAnim,
                  child: _FormContent(state: state, isDesktop: true),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Mobile / Tablet layout
// ═════════════════════════════════════════════════════════════════════════════
class _MobileLayout extends StatelessWidget {
  final _LoginScreenState state;
  final bool isTablet;
  const _MobileLayout({required this.state, required this.isTablet});

  @override
  Widget build(BuildContext context) {
    final h    = MediaQuery.sizeOf(context).height;
    final topH = isTablet ? h * 0.28 : h * 0.24;

    return Stack(
      children: [
        // Gradient strip at top
        Positioned(
          top: 0, left: 0, right: 0,
          height: topH + 30,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_h1, _h2, _h3],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        // Lottie in top area
        Positioned(
          top: 0, left: 0, right: 0,
          height: topH,
          child: const _HeroLottie(compact: true),
        ),
        // White card from bottom
        Positioned(
          top: topH - 18,
          left: 0, right: 0, bottom: 0,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: _white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                top: 26,
                left: isTablet ? 48 : 22,
                right: isTablet ? 48 : 22,
                bottom: MediaQuery.viewInsetsOf(context).bottom + 40,
              ),
              child: isTablet
                  ? Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: _FormContent(state: state, isDesktop: false),
                      ),
                    )
                  : _FormContent(state: state, isDesktop: false),
            ),
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Hero Panel — desktop left side
// ═════════════════════════════════════════════════════════════════════════════
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
                // Logo + name
                Row(children: [
                  _LogoBadge(size: 44, light: true),
                  const SizedBox(width: 12),
                  const Text('Scolaris', style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w900,
                    color: _white, letterSpacing: -0.8,
                  )),
                ]),
                const SizedBox(height: 32),
                const Text('La plateforme de\ngestion scolaire\nafricaine.', style: TextStyle(
                  fontSize: 30, fontWeight: FontWeight.w800,
                  color: _white, letterSpacing: -0.8,
                  height: 1.25,
                )),
                const SizedBox(height: 12),
                Text(
                  'Gérez élèves, notes, finances\net emplois du temps en un seul endroit.',
                  style: TextStyle(
                    fontSize: 13.5, color: _white.withOpacity(0.6),
                    height: 1.65,
                  ),
                ),
                // Lottie animation — fills remaining space
                const Expanded(
                  child: Center(child: _HeroLottie()),
                ),
                // Features
                _FeaturePill(
                  icon: Icons.groups_2_outlined,
                  label: 'Élèves, parents & enseignants',
                ),
                _FeaturePill(
                  icon: Icons.bar_chart_rounded,
                  label: 'Notes, bulletins & rapports',
                ),
                _FeaturePill(
                  icon: Icons.account_balance_outlined,
                  label: 'Finance & frais scolaires',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Lottie widget — LottieFiles CDN with local fallback
// ─────────────────────────────────────────────────────────────────────────────
class _HeroLottie extends StatelessWidget {
  final bool compact;
  const _HeroLottie({this.compact = false});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: compact ? 150 : 320,
        maxWidth: 320,
      ),
      child: Lottie.network(
        _lottieHero,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Lottie.asset(
          'assets/lottie/school_building.json',
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            Icons.school_rounded,
            size: compact ? 64 : 96,
            color: _white.withOpacity(0.35),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Feature pill for hero
// ─────────────────────────────────────────────────────────────────────────────
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
            color: _white.withOpacity(0.09),
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

// ═════════════════════════════════════════════════════════════════════════════
// Form Content — shared between desktop and mobile
// ═════════════════════════════════════════════════════════════════════════════
class _FormContent extends StatelessWidget {
  final _LoginScreenState state;
  final bool isDesktop;
  const _FormContent({required this.state, required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ────────────────────────────────────────────────────────────
        Row(children: [
          _LogoBadge(size: isDesktop ? 42 : 36, light: false),
          const SizedBox(width: 10),
          Text('Scolaris', style: TextStyle(
            fontSize: isDesktop ? 20 : 18,
            fontWeight: FontWeight.w900,
            color: _terra,
            letterSpacing: -0.4,
          )),
        ]),
        SizedBox(height: isDesktop ? 36 : 22),

        const Text('Bienvenue 👋', style: TextStyle(
          fontSize: 27, fontWeight: FontWeight.w800,
          color: _ink, letterSpacing: -0.6,
        )),
        const SizedBox(height: 4),
        const Text('Connectez-vous à votre espace Scolaris', style: TextStyle(
          fontSize: 13.5, color: _muted, fontWeight: FontWeight.w400,
        )),
        const SizedBox(height: 24),

        // ── Demo section ──────────────────────────────────────────────────────
        _DemoCard(
          selectedRole: state._selectedRole,
          selectedSubtype: state._selectedSubtype,
          roles: _LoginScreenState._roles,
          subTypeMap: _LoginScreenState._subTypeMap,
          onRoleSelected: state._selectRole,
          onSubtypeSelected: state._selectSubtype,
        ),
        const SizedBox(height: 22),

        // ── Email ─────────────────────────────────────────────────────────────
        _ShadcnInput(
          controller: state._emailCtrl,
          focusNode: state._emailFocus,
          label: 'Adresse e-mail',
          hint: 'prenom.nom@ecole.com',
          prefixIcon: Icons.alternate_email_rounded,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => state._passFocus.requestFocus(),
        ),
        const SizedBox(height: 14),

        // ── Password ──────────────────────────────────────────────────────────
        _ShadcnInput(
          controller: state._passCtrl,
          focusNode: state._passFocus,
          label: 'Mot de passe',
          hint: '••••••••',
          prefixIcon: Icons.lock_outline_rounded,
          obscureText: state._obscure,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => state._submit(),
          suffixIcon: GestureDetector(
            onTap: () => state.setState(() => state._obscure = !state._obscure),
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(
                state._obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 17,
                color: _subtle,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // ── Forgot password ───────────────────────────────────────────────────
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
            ),
            child: const Text('Mot de passe oublié ?', style: TextStyle(
              fontSize: 12.5, color: _terra, fontWeight: FontWeight.w600,
            )),
          ),
        ),
        const SizedBox(height: 18),

        // ── Error ─────────────────────────────────────────────────────────────
        if (state._error != null) ...[
          _ErrorBanner(message: state._error!),
          const SizedBox(height: 14),
        ],

        // ── Submit ────────────────────────────────────────────────────────────
        _ShadcnButton(
          label: 'Se connecter',
          loading: state._loading,
          onPressed: state._submit,
        ),
        const SizedBox(height: 18),

        // ── Divider ───────────────────────────────────────────────────────────
        Row(children: [
          const Expanded(child: Divider(color: _border, thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text('ou', style: TextStyle(
              fontSize: 11.5, color: _muted.withOpacity(0.65),
              fontWeight: FontWeight.w500,
            )),
          ),
          const Expanded(child: Divider(color: _border, thickness: 1)),
        ]),
        const SizedBox(height: 16),

        // ── QR button ─────────────────────────────────────────────────────────
        _OutlineButton(
          icon: Icons.qr_code_scanner_rounded,
          label: 'Scanner un QR code',
          onPressed: () => state.setState(() => state._showQrScanner = true),
        ),
        const SizedBox(height: 30),

        // ── Footer ────────────────────────────────────────────────────────────
        Center(
          child: Text('Scolaris · v0.1 · Démo', style: TextStyle(
            fontSize: 11, color: _muted.withOpacity(0.35),
          )),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Logo Badge
// ═════════════════════════════════════════════════════════════════════════════
class _LogoBadge extends StatelessWidget {
  final double size;
  final bool light;
  const _LogoBadge({required this.size, this.light = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: light
            ? _white.withOpacity(0.12)
            : _terra.withOpacity(0.08),
        borderRadius: BorderRadius.circular(size * 0.24),
        border: Border.all(
          color: light
              ? _white.withOpacity(0.22)
              : _terra.withOpacity(0.22),
          width: 1,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        'S',
        style: TextStyle(
          fontSize: size * 0.52,
          fontWeight: FontWeight.w900,
          color: light ? _white : _terra,
          letterSpacing: -1,
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Demo card — role + subtype picker
// ═════════════════════════════════════════════════════════════════════════════
class _DemoCard extends StatelessWidget {
  final String selectedRole;
  final String? selectedSubtype;
  final List<(String, IconData, String)> roles;
  final Map<String, List<(String, String, IconData)>> subTypeMap;
  final ValueChanged<String> onRoleSelected;
  final ValueChanged<String> onSubtypeSelected;

  const _DemoCard({
    required this.selectedRole,
    required this.selectedSubtype,
    required this.roles,
    required this.subTypeMap,
    required this.onRoleSelected,
    required this.onSubtypeSelected,
  });

  @override
  Widget build(BuildContext context) {
    final subtypes = subTypeMap[selectedRole] ?? [];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.play_circle_outline_rounded, size: 11, color: _gold),
          const SizedBox(width: 5),
          Text('Mode démo — choisissez un profil', style: TextStyle(
            fontSize: 10.5, fontWeight: FontWeight.w600,
            color: _muted.withOpacity(0.8),
          )),
        ]),
        const SizedBox(height: 9),
        // Roles
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: roles.map((r) {
              final sel = r.$1 == selectedRole;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => onRoleSelected(r.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: sel ? _terra : _white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: sel ? _terra : _border,
                      ),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(r.$2, size: 11,
                          color: sel ? _white : _muted),
                      const SizedBox(width: 4),
                      Text(r.$3, style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: sel ? _white : _ink,
                      )),
                    ]),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        // Subtypes
        if (subtypes.isNotEmpty) ...[
          const SizedBox(height: 7),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: subtypes.map((s) {
                final sel = s.$1 == selectedSubtype;
                return Padding(
                  padding: const EdgeInsets.only(right: 5),
                  child: GestureDetector(
                    onTap: () => onSubtypeSelected(s.$1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: sel ? const Color(0xFFFEF3EE) : Colors.transparent,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: sel
                              ? _terra.withOpacity(0.3)
                              : Colors.transparent,
                        ),
                      ),
                      child: Text(s.$2, style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                        color: sel ? _terra : _muted,
                      )),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Shadcn-style input field
// ═════════════════════════════════════════════════════════════════════════════
class _ShadcnInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String label;
  final String? hint;
  final IconData prefixIcon;
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
    required this.prefixIcon,
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
        style: const TextStyle(
          fontSize: 14, color: _ink, fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: _subtle, fontSize: 13.5),
          prefixIcon: Icon(prefixIcon, size: 16, color: _subtle),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: _white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 13,
          ),
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _terra, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFEF4444)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
          ),
        ),
      ),
    ]);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Shadcn primary button — flat, no shadow
// ═════════════════════════════════════════════════════════════════════════════
class _ShadcnButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onPressed;

  const _ShadcnButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: _terra,
          foregroundColor: _white,
          disabledBackgroundColor: _terra.withOpacity(0.42),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
        child: loading
            ? const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2, color: _white,
                ))
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Se connecter', style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  )),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Outline ghost button
// ═════════════════════════════════════════════════════════════════════════════
class _OutlineButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _OutlineButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 17),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: _ink,
          side: const BorderSide(color: _border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Error banner
// ═════════════════════════════════════════════════════════════════════════════
class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
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

// ═════════════════════════════════════════════════════════════════════════════
// Dot pattern painter for hero
// ═════════════════════════════════════════════════════════════════════════════
class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dot = Paint()
      ..color = Colors.white.withOpacity(0.045)
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
    canvas.drawCircle(Offset(size.width * 0.82, size.height * 0.1), 88, ring);
    canvas.drawCircle(Offset(size.width * 0.12, size.height * 0.88), 108, ring);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ═════════════════════════════════════════════════════════════════════════════
// QR Scanner Overlay
// ═════════════════════════════════════════════════════════════════════════════
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
                child: Text('Scanner le QR code Scolaris',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _white, fontWeight: FontWeight.w700, fontSize: 15,
                    )),
              ),
              const SizedBox(width: 48),
            ]),
          ),
        ),
        Positioned(
          bottom: 60, left: 0, right: 0,
          child: Text('Pointez la caméra vers le QR code de votre profil',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _white.withOpacity(0.75), fontSize: 13,
              )),
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
    final lp = Paint()
      ..color = _white
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
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
