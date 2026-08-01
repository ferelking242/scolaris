import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/sources/remote/supabase_auth_source.dart';
import '../../../presentation/providers/auth_providers.dart';
import 'forgot_password_screen.dart';

const _terra  = ScolarisPalette.terracotta;
const _orange = ScolarisPalette.orange;
const _gold   = ScolarisPalette.gold;
const _green  = ScolarisPalette.forestGreen;
const _cream  = ScolarisPalette.cream;
const _ink    = Color(0xFF1A0A00);
const _muted  = Color(0xFF7A5C44);
const _border = Color(0xFFDDCCBB);
const _white  = Colors.white;
const _bg0    = Color(0xFF0A2010);
const _bg1    = Color(0xFF1B5E20);

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController(text: 'admin@ead-bzv.cg');
  final _passCtrl  = TextEditingController(text: 'demo1234');
  bool _loading  = false;
  bool _obscure  = true;
  String? _error;
  String _selectedRole    = 'student';
  String? _selectedSubtype = 'lycee';
  int  _demoTapCount  = 0;

  static const _roles = [
    ('student',      Icons.school_outlined,               'Étudiant'),
    ('parent',       Icons.family_restroom_outlined,      'Parent'),
    ('teacher',      Icons.menu_book_outlined,            'Enseignant'),
    ('surveillance', Icons.shield_outlined,               'Surveillance'),
    ('finance',      Icons.payments_outlined,             'Finance'),
    ('admin',        Icons.admin_panel_settings_outlined, 'Admin'),
  ];

  static const _subTypeMap =
      <String, List<(String, String, IconData)>>{
    'student': [
      ('primaire',   'Primaire',     Icons.child_care_outlined),
      ('college',    'Collège',      Icons.school_outlined),
      ('lycee',      'Lycée',        Icons.account_balance_outlined),
      ('univ',       'Université',   Icons.science_outlined),
    ],
    'teacher': [
      ('primaire',   'Primaire',     Icons.child_care_outlined),
      ('secondaire', 'Secondaire',   Icons.school_outlined),
      ('univ',       'Université',   Icons.science_outlined),
    ],
    'parent': [
      ('primaire',   'Enf. Primaire',Icons.child_care_outlined),
      ('college',    'Enf. Collège', Icons.school_outlined),
      ('lycee',      'Enf. Lycée',   Icons.account_balance_outlined),
    ],
    'admin': [
      ('directeur',  'Directeur',    Icons.badge_outlined),
      ('secretaire', 'Secrétariat',  Icons.person_outlined),
      ('dg',         'Dir. Général', Icons.workspace_premium_outlined),
    ],
    'finance': [
      ('comptable',  'Comptable',    Icons.calculate_outlined),
      ('caissier',   'Caissier',     Icons.point_of_sale_outlined),
    ],
    'surveillance': [
      ('sg',         'Surv. Gén.',   Icons.security_outlined),
      ('aux',        'Auxiliaire',   Icons.shield_outlined),
    ],
  };


  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _selectRole(String role) {
    final subs = _subTypeMap[role];
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

  void _fillAndLogin(String email, String password) {
      setState(() {
        _emailCtrl.text = email;
        _passCtrl.text  = password;
        _error = null;
      });
      Future.microtask(_submit);
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
      await ref.read(signInUseCaseProvider)(
          _emailCtrl.text.trim(), _passCtrl.text);
    } on ArgumentError catch (e) {
      setState(() => _error = (e.message as String).tr());
    } on SchoolPendingValidationException catch (e) {
      setState(() => _error = e.schoolName.isEmpty
          ? 'Votre établissement est en cours de validation par notre équipe.'
          : '${e.schoolName} est en cours de validation par notre équipe — réessayez sous 24 h.');
    } catch (_) {
      setState(() => _error = 'auth.errors.failed'.tr());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isWide = size.width > 800;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _cream,
        body: isWide
            ? _buildWideLayout(context, size)
            : _buildMobileLayout(context, size),
      ),
    );
  }

  Widget _buildWideLayout(BuildContext context, Size size) {
    return Row(
      children: [
        Expanded(
          flex: 58,
          child: const _LeftPanel(),
        ),
        Expanded(
          flex: 42,
          child: _buildFormPanel(context, showBrand: true),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context, Size size) {
    return SafeArea(
      child: Column(
        children: [
          const _MobileHeader(),
          Expanded(child: _buildFormPanel(context, showBrand: false)),
        ],
      ),
    );
  }

  Widget _buildFormPanel(BuildContext context, {bool showBrand = true}) {
    return Container(
      color: const Color(0xFFFDFAF7),
      child: LayoutBuilder(builder: (ctx, constraints) {
        final hPad = constraints.maxWidth > 480 ? 32.0 : 22.0;
        final vPad = showBrand ? 28.0 : 16.0;
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showBrand) ...[
                _BrandMark(),
                const SizedBox(height: 24),
              ],

              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => setState(() {
                    _demoTapCount++;
                    if (_demoTapCount == 2) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('🔒 Encore une fois…'),
                        duration: Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ));
                    } else if (_demoTapCount == 3) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('🔓 Section développeur déverrouillée'),
                        duration: Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ));
                    }
                  }),
                  child: Text('Connexion', style: TextStyle(
                    fontSize: showBrand ? 28 : 22,
                    fontWeight: FontWeight.w900, color: _ink, letterSpacing: -.3,
                  )),
                ),
              ),
              if (showBrand) ...[
                const SizedBox(height: 3),
                Text('Accédez à votre espace Scolaris',
                    style: TextStyle(color: _muted, fontSize: 13)),
              ],
              SizedBox(height: showBrand ? 20 : 14),

              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _border.withOpacity(.5)),
                  boxShadow: [BoxShadow(color: _ink.withOpacity(.05), blurRadius: 24, offset: const Offset(0, 6))],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
                  child: _buildEmailForm(),
                ),
              ),

              if (_demoTapCount >= 3) ...[
                const SizedBox(height: 20),
                _divider('Comptes démo — accès rapide'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 7, runSpacing: 7,
                  children: [
                    for (final r in _roles)
                      _RoleChip(
                        label: r.$3, icon: r.$2,
                        selected: _selectedRole == r.$1,
                        onTap: () => _selectRole(r.$1),
                      ),
                  ],
                ),

                // ── Sous-profil ─────────────────────────────────────────────
                if (_subTypeMap.containsKey(_selectedRole)) ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    const Icon(Icons.subdirectory_arrow_right_rounded,
                        size: 13, color: Color(0xFFB08060)),
                    const SizedBox(width: 4),
                    const Text('Sous-profil',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700,
                            color: Color(0xFFB08060))),
                  ]),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6, runSpacing: 6,
                    children: [
                      for (final s in _subTypeMap[_selectedRole]!)
                        _SubTypeChip(
                          label: s.$2, icon: s.$3,
                          selected: _selectedSubtype == s.$1,
                          onTap: () => _selectSubtype(s.$1),
                        ),
                    ],
                  ),
                ],

                const SizedBox(height: 20),
                _divider('Écoles — Connexion rapide'),
                const SizedBox(height: 12),
                _SchoolsQuickLogin(onTap: _fillAndLogin),
                const SizedBox(height: 8),
                Center(
                  child: Text('Mot de passe universel : demo1234',
                      style: TextStyle(color: _muted.withOpacity(.55), fontSize: 11)),
                ),
              ],
            ],
          ),
        );
      }),
    );
  }

  Widget _buildEmailForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        _fieldLabel('Adresse e-mail'),
        const SizedBox(height: 6),
        _STextField(
          controller: _emailCtrl,
          hint: 'nom@ecole.com',
          icon: Icons.mail_outline_rounded,
          keyboard: TextInputType.emailAddress,
        ),
          const SizedBox(height: 16),
          Row(children: [
            _fieldLabel('Mot de passe'),
            const Spacer(),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                child: const Text('Mot de passe oublié ?',
                    style: TextStyle(color: _terra, fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          _STextField(
            controller: _passCtrl,
            hint: '••••••••',
            icon: Icons.lock_outline_rounded,
            obscure: _obscure,
            suffix: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              icon: Icon(_obscure
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
                  size: 18, color: _muted),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _ErrorBanner(message: _error!),
          ],
          const SizedBox(height: 20),
          _PrimaryBtn(label: 'Se connecter', loading: _loading, onTap: _submit),
          const SizedBox(height: 18),
          _divider('Connexion rapide (démo · demo1234)'),
          const SizedBox(height: 10),
          _demoQuickRow(),
        ],
    );
  }

  // Connexion rapide aux comptes démo (mot de passe demo1234).
  Widget _demoQuickRow() {
    // (label, email, icône, couleur, mot de passe)
    const accounts = <(String, String, IconData, Color, String)>[
      ('Super-Admin', 'kenganiboveldy@gmail.com',   Icons.shield_moon_outlined,          Color(0xFF0D3B1E), 'demo1234'),
      ('Admin·LSB',   'serge.bouya@lsb.cg',        Icons.admin_panel_settings_outlined, _terra,            'demo1234'),
      ('Prof·ELC',    'jean.ngoubili@elc.cg',       Icons.menu_book_outlined,            Color(0xFF0277BD), 'demo1234'),
      ('Élève·CSFS',  'ferel.ondongo@csfs.cg',      Icons.school_outlined,               _green,            'demo1234'),
      ('Admin·UDSN',  'alain.nzoussi@udsn.cg',      Icons.account_balance_outlined,      Color(0xFF7C3AED), 'demo1234'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final a in accounts)
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: _loading ? null : () => _fillAndLogin(a.$2, a.$5),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: a.$4.withOpacity(.07),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: a.$4.withOpacity(.30)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(a.$3, size: 15, color: a.$4),
                  const SizedBox(width: 6),
                  Text(a.$1, style: TextStyle(
                      color: a.$4, fontSize: 12.5, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ),
      ],
    );
  }

  Widget _fieldLabel(String s) => Text(s,
      style: const TextStyle(fontSize: 13, color: _ink, fontWeight: FontWeight.w600));

  Widget _divider(String label) => Row(children: [
    const Expanded(child: Divider(color: _border, height: 1)),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(label, style: const TextStyle(fontSize: 11, color: _muted)),
    ),
    const Expanded(child: Divider(color: _border, height: 1)),
  ]);

}

// ── Left Panel (African sidebar style + single Lottie) ─────────────────────
class _LeftPanel extends StatelessWidget {
  const _LeftPanel();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // African dark brown gradient — same as sidebar
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D0600), Color(0xFF1A0A00), Color(0xFF2E1100)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),

        // African hex/adinkra pattern overlay
        CustomPaint(painter: _AfricanPatternPainter()),

        // Gold top accent stripe
        Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            height: 4,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [_terra, _gold, _orange]),
            ),
          ),
        ),

        // Large centered Lottie — boy studying
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 110),
            child: Center(
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.70,
                width: double.infinity,
                child: Lottie.asset(
                  'assets/lottie/student_login.json',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Lottie.asset(
                    'assets/lottie/student.json',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Bottom gradient for readability
        Positioned(
          bottom: 0, left: 0, right: 0,
          height: 140,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  const Color(0xFF0D0600).withOpacity(.95),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),

        // Bottom logo + tagline
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(36, 0, 36, 28),
            child: Row(children: [
              _LogoImg(size: 40),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                const Text('Scolaris', style: TextStyle(
                  color: _white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: .4,
                )),
                Text(AppConfig.appTagline, style: TextStyle(
                  color: _gold.withOpacity(.72), fontSize: 10, fontStyle: FontStyle.italic,
                )),
              ]),
              const Spacer(),
              Text('© ${DateTime.now().year} Scolaris',
                  style: TextStyle(color: _white.withOpacity(.22), fontSize: 10)),
            ]),
          ),
        ),
      ],
    );
  }
}


// ── Logo Widget ────────────────────────────────────────────────────────────
class _LogoImg extends StatelessWidget {
  final double size;
  const _LogoImg({this.size = 48});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image.asset(
        'assets/images/logo.png',
        width: size, height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Image.asset(
          'assets/images/logo_transparent.png',
          width: size, height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: size, height: size,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_terra, _orange]),
              borderRadius: BorderRadius.circular(size * 0.22),
            ),
            child: Center(
              child: Text('S', style: TextStyle(
                color: _white, fontSize: size * 0.45, fontWeight: FontWeight.w900,
              )),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Mobile Header ──────────────────────────────────────────────────────────
class _MobileHeader extends StatelessWidget {
  const _MobileHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A0A00), Color(0xFF8B1A00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      child: Row(children: [
        _LogoImg(size: 34),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          const Text('Scolaris',
              style: TextStyle(color: _white, fontWeight: FontWeight.w900, fontSize: 17, letterSpacing: .5)),
          Text(AppConfig.appTagline,
              style: TextStyle(color: _gold.withOpacity(.85), fontSize: 10, fontStyle: FontStyle.italic)),
        ]),
      ]),
    );
  }
}

// ── Brand Mark (right panel top) ───────────────────────────────────────────
class _BrandMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _LogoImg(size: 52),
      const SizedBox(width: 14),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Scolaris',
            style: TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: .5)),
        Text(AppConfig.appTagline,
            style: TextStyle(color: _muted.withOpacity(.7), fontSize: 11,
                fontStyle: FontStyle.italic)),
      ]),
    ]);
  }
}

// ── African Pattern Painter ────────────────────────────────────────────────
class _AfricanPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p1 = Paint()
      ..color = _white.withOpacity(.03)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final p2 = Paint()
      ..color = _gold.withOpacity(.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    const spacing = 52.0;
    final cols = (size.width / spacing).ceil() + 1;
    final rows = (size.height / spacing).ceil() + 1;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final cx = c * spacing + (r.isOdd ? spacing / 2 : 0);
        final cy = r * spacing * 0.866;
        _drawHex(canvas, Offset(cx, cy), 18, p1);
        if ((r + c) % 3 == 0) _drawAdinkra(canvas, Offset(cx, cy), 6, p2);
      }
    }
  }

  void _drawHex(Canvas canvas, Offset center, double r, Paint p) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60 - 30) * math.pi / 180;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, p);
  }

  void _drawAdinkra(Canvas canvas, Offset c, double r, Paint p) {
    canvas.drawCircle(c, r, p);
    canvas.drawLine(c.translate(-r, 0), c.translate(r, 0), p);
    canvas.drawLine(c.translate(0, -r), c.translate(0, r), p);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Form Widgets ──────────────────────────────────────────────────────────
class _STextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboard;
  const _STextField({
    required this.controller, required this.hint, required this.icon,
    this.obscure = false, this.suffix, this.keyboard,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      style: const TextStyle(fontSize: 14, color: _ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: _muted.withOpacity(.55), fontSize: 14),
        prefixIcon: Icon(icon, size: 18, color: _muted),
        prefixIconConstraints: const BoxConstraints.tightFor(width: 44),
        suffixIcon: suffix,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 16),
        filled: true,
        fillColor: const Color(0xFFF9F5F1),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _terra, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.8),
        ),
      ),
    );
  }
}

class _PrimaryBtn extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onTap;
  final IconData? icon;
  const _PrimaryBtn({
    required this.label, required this.loading,
    required this.onTap, this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 54,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: loading
              ? [_terra.withOpacity(.6), _orange.withOpacity(.6)]
              : [_terra, _orange],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: loading ? [] : [
          BoxShadow(color: _terra.withOpacity(.4),
              blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: loading ? null : onTap,
          child: Center(
            child: loading
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.2, color: _white))
                : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    if (icon != null) ...[
                      Icon(icon, color: _white, size: 18),
                      const SizedBox(width: 8),
                    ],
                    Text(label, style: const TextStyle(color: _white, fontSize: 15,
                        fontWeight: FontWeight.w700, letterSpacing: .3)),
                  ]),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline, size: 16, color: Color(0xFFDC2626)),
        const SizedBox(width: 10),
        Expanded(child: Text(message,
            style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12.5))),
      ]),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _RoleChip({required this.label, required this.icon,
      required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [_terra, _orange],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: selected ? null : _white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? _terra : _border.withOpacity(.8),
              width: selected ? 0 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(color: _terra.withOpacity(.35),
                        blurRadius: 14, offset: const Offset(0, 5)),
                  ]
                : [
                    BoxShadow(color: _ink.withOpacity(.04),
                        blurRadius: 4, offset: const Offset(0, 2)),
                  ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                color: selected
                    ? _white.withOpacity(.2)
                    : _terra.withOpacity(.08),
                shape: BoxShape.circle,
              ),
              child: Center(child: Icon(icon, size: 12,
                  color: selected ? _white : _terra)),
            ),
            const SizedBox(width: 7),
            Text(label, style: TextStyle(
                color: selected ? _white : _ink,
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

class _SubTypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _SubTypeChip({required this.label, required this.icon,
      required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF3E1A00) : const Color(0xFFF0E8DF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: selected ? const Color(0xFF3E1A00) : _border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 12,
                color: selected ? _gold : const Color(0xFFB08060)),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(
                color: selected ? _gold : _ink,
                fontSize: 11.5, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}


  // ═══════════════════════════════════════════════════════════════════════════════
  // Écoles — Quick Login Widgets (Primaire · Collège · Lycée · Université)
  // ═══════════════════════════════════════════════════════════════════════════════

  class _SchoolUser {
    final String label, subtitle, email, school;
    final IconData icon;
    final Color color;
    const _SchoolUser({required this.label,required this.subtitle,required this.email,required this.icon,required this.color,required this.school});
  }

  const _demoPass = 'demo1234';

  const _schoolUsers = [
    // Primaire — École Lumière du Congo (ELC)
    _SchoolUser(label:'Thomas Mouyabi',subtitle:'Directeur · École Lumière du Congo',email:'thomas.mouyabi@elc.cg',icon:Icons.workspace_premium_rounded,color:Color(0xFF2E7D32),school:'Primaire'),
    _SchoolUser(label:'Jean Ngoubili',subtitle:'Enseignant · Primaire',email:'jean.ngoubili@elc.cg',icon:Icons.menu_book_rounded,color:Color(0xFF388E3C),school:'Primaire'),
    _SchoolUser(label:'Alice Moukoko',subtitle:'Élève · Primaire',email:'alice.moukoko@elc.cg',icon:Icons.child_care_rounded,color:Color(0xFF43A047),school:'Primaire'),
    _SchoolUser(label:'Rose Okemba',subtitle:'Secrétariat · École Lumière',email:'rose.okemba@elc.cg',icon:Icons.manage_accounts_rounded,color:Color(0xFF558B2F),school:'Primaire'),
    // ── Un compte par RÔLE (droits fins) — cf. 20260735 + 20260750_seed_role_demos.
    //    Tous à l'École Lumière, pour vérifier ce que chaque rôle peut/ne peut pas.
    _SchoolUser(label:'Gaston Milandou',subtitle:'Rôle Chef d\'établissement · accès total',email:'chef.elc@elc.cg',icon:Icons.gavel_rounded,color:Color(0xFF8B1A00),school:'Primaire'),
    _SchoolUser(label:'Firmin Loubota',subtitle:'Rôle Adjoint · pédagogie, notes, discipline',email:'adjoint.elc@elc.cg',icon:Icons.shield_moon_outlined,color:Color(0xFF7E3FF2),school:'Primaire'),
    _SchoolUser(label:'Clarisse Ndinga',subtitle:'Rôle Secrétaire · élèves, inscriptions',email:'secretaire.elc@elc.cg',icon:Icons.folder_shared_rounded,color:Color(0xFFD4540A),school:'Primaire'),
    // Comptable et Surveillant retirés : comptes jamais réellement créés en
    // base (ni public.users, ni auth.users) — la connexion échouait toujours.
    _SchoolUser(label:'Basile Kaya',subtitle:'Rôle Enseignant · notes & présences',email:'enseignant.elc@elc.cg',icon:Icons.school_rounded,color:Color(0xFFC17F24),school:'Primaire'),
    // Le seul compte PARENT de la démo (cf. 20260727_seed_parent_demo.sql).
    // Rattaché à Alice Moukoko via `parent_student` — sans ce lien, l'espace
    // parent serait vide, quel que soit le reste.
    _SchoolUser(label:'Pauline Moukoko',subtitle:'Parent · mère d\'Alice · Primaire',email:'parent.elc@elc.cg',icon:Icons.family_restroom_rounded,color:Color(0xFF00897B),school:'Primaire'),
    // Collège — Saint-François de Sales (CSFS)
    _SchoolUser(label:'Andrée Koumba',subtitle:'Directrice · Collège St-François',email:'andree.koumba@csfs.cg',icon:Icons.workspace_premium_rounded,color:Color(0xFF1565C0),school:'Collège'),
    _SchoolUser(label:'Céleste Ibara',subtitle:'Enseignante · Collège',email:'celeste.ibara@csfs.cg',icon:Icons.menu_book_rounded,color:Color(0xFF0277BD),school:'Collège'),
    _SchoolUser(label:'Ferel Ondongo',subtitle:'Élève · Collège',email:'ferel.ondongo@csfs.cg',icon:Icons.school_rounded,color:Color(0xFF0288D1),school:'Collège'),
    _SchoolUser(label:'Rémy Makosso',subtitle:'Secrétariat · Collège St-François',email:'remy.makosso@csfs.cg',icon:Icons.manage_accounts_rounded,color:Color(0xFF00838F),school:'Collège'),
    // Lycée — Savorgnan de Brazza (LSB)
    _SchoolUser(label:'Serge Bouya',subtitle:'Directeur · Lycée Savorgnan de Brazza',email:'serge.bouya@lsb.cg',icon:Icons.workspace_premium_rounded,color:Color(0xFF8B1A00),school:'Lycée'),
    _SchoolUser(label:'Pascal Nzoukou',subtitle:'Enseignant · Lycée',email:'pascal.nzoukou@lsb.cg',icon:Icons.menu_book_rounded,color:Color(0xFFC17F24),school:'Lycée'),
    _SchoolUser(label:'Bienvenu Makoumbou',subtitle:'Élève · Lycée',email:'bienvenu.makoumbou@lsb.cg',icon:Icons.account_balance_rounded,color:Color(0xFFD4540A),school:'Lycée'),
    _SchoolUser(label:'Christelle Niangou',subtitle:'Secrétariat · Lycée Savorgnan',email:'christelle.niangou@lsb.cg',icon:Icons.manage_accounts_rounded,color:Color(0xFF8B1A00),school:'Lycée'),
    // Université — Denis Sassou Nguesso (UDSN)
    _SchoolUser(label:'Pr. Alain Nzoussi',subtitle:'Recteur · Université DSN',email:'alain.nzoussi@udsn.cg',icon:Icons.workspace_premium_rounded,color:Color(0xFF6A1B9A),school:'Université'),
    _SchoolUser(label:'Dr. Henri Loemba',subtitle:'Enseignant · Université',email:'henri.loemba@udsn.cg',icon:Icons.menu_book_rounded,color:Color(0xFF7B1FA2),school:'Université'),
    _SchoolUser(label:'Gloire Mouamba',subtitle:'Étudiant · Université',email:'gloire.mouamba@udsn.cg',icon:Icons.science_rounded,color:Color(0xFF8E24AA),school:'Université'),
    _SchoolUser(label:'Patricia Etsiona',subtitle:'Secrétariat · Université DSN',email:'patricia.etsiona@udsn.cg',icon:Icons.manage_accounts_rounded,color:Color(0xFF6A1B9A),school:'Université'),
  ];

  class _SchoolsQuickLogin extends StatefulWidget {
    final void Function(String email, String password) onTap;
    const _SchoolsQuickLogin({required this.onTap});
    @override
    State<_SchoolsQuickLogin> createState() => _SchoolsQuickLoginState();
  }

  class _SchoolsQuickLoginState extends State<_SchoolsQuickLogin> {
    String _filter = 'Tous';

    @override
    Widget build(BuildContext context) {
      const tabs = ['Tous', 'Primaire', 'Collège', 'Lycée', 'Université'];
      final filtered = _filter == 'Tous' ? _schoolUsers : _schoolUsers.where((u) => u.school == _filter).toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: tabs.map((t) {
                final sel = _filter == t;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(t, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: sel ? Colors.white : _muted)),
                    selected: sel,
                    onSelected: (_) => setState(() => _filter = t),
                    backgroundColor: const Color(0xFFF5F0EC),
                    selectedColor: _terra,
                    checkmarkColor: Colors.white,
                    showCheckmark: false,
                    side: BorderSide(color: sel ? _terra : _border),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          ...filtered.map((u) => _SchoolUserTile(user: u, onTap: () => widget.onTap(u.email, _demoPass))),
        ],
      );
    }
  }

  class _SchoolUserTile extends StatelessWidget {
    final _SchoolUser user;
    final VoidCallback onTap;
    const _SchoolUserTile({required this.user, required this.onTap});

    @override
    Widget build(BuildContext context) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.only(bottom: 7),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: user.color.withOpacity(.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: user.color.withOpacity(.25)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(color: user.color.withOpacity(.15), borderRadius: BorderRadius.circular(10)),
                  child: Icon(user.icon, color: user.color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _ink)),
                      const SizedBox(height: 1),
                      Text(user.subtitle, style: const TextStyle(fontSize: 11, color: _muted)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(color: user.color.withOpacity(.12), borderRadius: BorderRadius.circular(6)),
                  child: Text(user.school, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: user.color)),
                ),
                const SizedBox(width: 6),
                Icon(Icons.login_rounded, color: user.color, size: 16),
              ],
            ),
          ),
        ),
      );
    }
  }
  