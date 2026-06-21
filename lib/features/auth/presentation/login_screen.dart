import 'dart:math' as math;

  import 'package:easy_localization/easy_localization.dart';
  import 'package:flutter/material.dart';
  import 'package:flutter/services.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:go_router/go_router.dart';
  import 'package:mobile_scanner/mobile_scanner.dart';

    import '../../../core/routing/app_router.dart';
  import '../../../core/theme/app_theme.dart';
  import '../../../presentation/providers/auth_providers.dart';
  import 'forgot_password_screen.dart';

  // ── Brand constants ──────────────────────────────────────────────────────────
  const _terra  = ScolarisPalette.terracotta;
  const _gold   = ScolarisPalette.gold;
  const _forest = ScolarisPalette.forestGreen;
  const _cream  = ScolarisPalette.cream;

  // ════════════════════════════════════════════════════════════════════════════
  // LoginScreen
  // ════════════════════════════════════════════════════════════════════════════
  class LoginScreen extends ConsumerStatefulWidget {
    const LoginScreen({super.key});
    @override
    ConsumerState<LoginScreen> createState() => _LoginScreenState();
  }

  class _LoginScreenState extends ConsumerState<LoginScreen>
      with SingleTickerProviderStateMixin {
    final _emailCtrl  = TextEditingController(text: 'student@scolaris.app');
    final _passCtrl   = TextEditingController(text: 'demo1234');
    final _emailFocus = FocusNode();
    final _passFocus  = FocusNode();

    bool    _loading       = false;
    bool    _obscure       = true;
    String? _error;
    String  _selectedRole    = 'student';
    String? _selectedSubtype = 'lycee';
    bool    _showQrScanner = false;
    bool    _showQrTab     = false;
    int     _demoTapCount  = 0;

    late final AnimationController _heroCtrl;
    late final Animation<double>   _heroFade;

    static const _roles = [
      ('student',      Icons.school_outlined,               'Élève'),
      ('parent',       Icons.family_restroom_outlined,      'Parent'),
      ('teacher',      Icons.menu_book_outlined,            'Prof'),
      ('surveillance', Icons.shield_outlined,               'Surv.'),
      ('finance',      Icons.payments_outlined,             'Finance'),
      ('admin',        Icons.admin_panel_settings_outlined, 'Admin'),
    ];

    static const _subTypeMap = <String, List<(String, String, IconData)>>{
      'student':      [
        ('primaire',   'Primaire',     Icons.child_care_outlined),
        ('college',    'Collège',      Icons.school_outlined),
        ('lycee',      'Lycée',        Icons.account_balance_outlined),
        ('univ',       'Université',   Icons.science_outlined),
      ],
      'teacher':      [
        ('primaire',   'Primaire',     Icons.child_care_outlined),
        ('secondaire', 'Secondaire',   Icons.school_outlined),
        ('univ',       'Université',   Icons.science_outlined),
      ],
      'parent':       [
        ('primaire',   'Enf. Primaire', Icons.child_care_outlined),
        ('college',    'Enf. Collège',  Icons.school_outlined),
        ('lycee',      'Enf. Lycée',    Icons.account_balance_outlined),
      ],
      'admin':        [
        ('directeur',  'Directeur',    Icons.badge_outlined),
        ('secretaire', 'Secrétariat',  Icons.person_outlined),
        ('dg',         'Dir. Général', Icons.workspace_premium_outlined),
      ],
      'finance':      [
        ('comptable',  'Comptable',    Icons.calculate_outlined),
        ('caissier',   'Caissier',     Icons.point_of_sale_outlined),
      ],
      'surveillance': [
        ('sg',  'Surv. Gén.',  Icons.security_outlined),
        ('aux', 'Auxiliaire',  Icons.shield_outlined),
      ],
    };

    @override
    void initState() {
      super.initState();
      _heroCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
      _heroFade = CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOut);
      _heroCtrl.forward();
    }

    @override
    void dispose() {
      _emailCtrl.dispose(); _passCtrl.dispose();
      _emailFocus.dispose(); _passFocus.dispose();
      _heroCtrl.dispose();
      super.dispose();
    }

    // ── Demo helpers ────────────────────────────────────────────────────────────
    void _selectRole(String role) {
      final subs    = _subTypeMap[role];
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
        _error          = null;
      });
      Future.microtask(_submit);
    }

    // ── Auth ────────────────────────────────────────────────────────────────────
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

    // ── QR ──────────────────────────────────────────────────────────────────────
    Future<void> _handleQr(BarcodeCapture capture) async {
      final raw = capture.barcodes.firstOrNull?.rawValue;
      if (raw == null || !raw.startsWith('scolaris://')) return;
      final parts = raw.replaceFirst('scolaris://', '').split(':');
      if (parts.length < 2) return;
      setState(() => _showQrScanner = false);
      _fillAndLogin(Uri.decodeComponent(parts[0]), Uri.decodeComponent(parts[1]));
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Build
    // ─────────────────────────────────────────────────────────────────────────────
    @override
    Widget build(BuildContext context) {
      final sz   = MediaQuery.sizeOf(context);
      final wide = sz.width >= 800;

      if (_showQrScanner) return _QrScannerOverlay(onDetect: _handleQr, onClose: () => setState(() => _showQrScanner = false));

      return Scaffold(
        backgroundColor: wide ? const Color(0xFFF0EAE2) : Colors.white,
        body: wide ? _desktopLayout() : _mobileLayout(),
      );
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Desktop layout: hero left | form right
    // ─────────────────────────────────────────────────────────────────────────────
    Widget _desktopLayout() {
      return Row(children: [
        // ── Left hero panel ─────────────────────────────────────────────────────
        Expanded(
          flex: 45,
          child: FadeTransition(
            opacity: _heroFade,
            child: _HeroPanel(),
          ),
        ),
        // ── Right form panel ────────────────────────────────────────────────────
        Expanded(
          flex: 55,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 40),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: _FormCard(isDesktop: true, children: _formChildren()),
              ),
            ),
          ),
        ),
      ]);
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Mobile layout: hero top | form slides up
    // ─────────────────────────────────────────────────────────────────────────────
    Widget _mobileLayout() {
      final ht = MediaQuery.sizeOf(context).height;
      return Stack(children: [
        // ── Hero background (top 42%) ──────────────────────────────────────────
        Positioned(
          top: 0, left: 0, right: 0,
          height: ht * 0.42,
          child: FadeTransition(opacity: _heroFade, child: _HeroPanel()),
        ),
        // ── Form card slides from bottom ───────────────────────────────────────
        Positioned(
          top: ht * 0.34, left: 0, right: 0, bottom: 0,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: Container(
              color: Colors.white,
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  top: 28,
                  left: 24,
                  right: 24,
                  bottom: MediaQuery.viewInsetsOf(context).bottom + 32,
                ),
                child: _FormCard(isDesktop: false, children: _formChildren()),
              ),
            ),
          ),
        ),
      ]);
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Shared form children
    // ─────────────────────────────────────────────────────────────────────────────
    List<Widget> _formChildren() {
      final cs = Theme.of(context).colorScheme;

      return [
        // Title
        Text('Bienvenue', style: TextStyle(
          fontSize: 28, fontWeight: FontWeight.w900,
          color: const Color(0xFF1A0A00), letterSpacing: -0.5,
        )),
        const SizedBox(height: 4),
        Text('Connectez-vous à votre espace', style: TextStyle(
          fontSize: 14, color: const Color(0xFF7A5C44),
        )),
        const SizedBox(height: 24),

        // ── Demo mode role selector ─────────────────────────────────────────────
        if (true) ...[
          _DemoSection(
            selectedRole: _selectedRole,
            selectedSubtype: _selectedSubtype,
            roles: _roles,
            subTypeMap: _subTypeMap,
            onRoleSelected: _selectRole,
            onSubtypeSelected: _selectSubtype,
          ),
          const SizedBox(height: 20),
        ],

        // ── Email ───────────────────────────────────────────────────────────────
        _InputField(
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

        // ── Password ────────────────────────────────────────────────────────────
        _InputField(
          controller: _passCtrl,
          focusNode: _passFocus,
          label: 'Mot de passe',
          icon: Icons.lock_outline_rounded,
          obscureText: _obscure,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          suffixIcon: IconButton(
            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18),
            onPressed: () => setState(() => _obscure = !_obscure),
            splashRadius: 18,
          ),
        ),
        const SizedBox(height: 8),

        // ── Forgot password ─────────────────────────────────────────────────────
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
            style: TextButton.styleFrom(
              foregroundColor: _terra,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            ),
            child: const Text('Mot de passe oublié ?',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 4),

        // ── Error ───────────────────────────────────────────────────────────────
        if (_error != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFCE4EC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFEF9A9A)),
            ),
            child: Row(children: [
              const Icon(Icons.error_outline_rounded, size: 15, color: Color(0xFFC62828)),
              const SizedBox(width: 8),
              Expanded(child: Text(_error!, style: const TextStyle(
                fontSize: 12.5, color: Color(0xFFC62828), fontWeight: FontWeight.w500))),
            ]),
          ),
          const SizedBox(height: 14),
        ],

        // ── Sign in button ──────────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: _loading ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: _terra,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _terra.withOpacity(0.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: _loading
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Se connecter',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
          ),
        ),
        const SizedBox(height: 16),

        // ── Divider ─────────────────────────────────────────────────────────────
        Row(children: [
          Expanded(child: Divider(color: const Color(0xFFDDCCBB).withOpacity(0.8))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('ou', style: TextStyle(fontSize: 12, color: const Color(0xFF7A5C44))),
          ),
          Expanded(child: Divider(color: const Color(0xFFDDCCBB).withOpacity(0.8))),
        ]),
        const SizedBox(height: 14),

        // ── QR scan button ──────────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: () => setState(() => _showQrScanner = true),
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
            label: const Text('Connexion par QR code',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1A0A00),
              side: const BorderSide(color: Color(0xFFDDCCBB), width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),

        // ── Demo tap counter (hidden trigger) ───────────────────────────────────
        if (true) ...[
          const SizedBox(height: 20),
          Center(
            child: GestureDetector(
              onTap: () {
                setState(() => _demoTapCount++);
                if (_demoTapCount >= 5) {
                  setState(() { _demoTapCount = 0; _showQrTab = !_showQrTab; });
                }
              },
              child: Text('Scolaris · Démo',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: const Color(0xFF7A5C44).withOpacity(0.5),
                    fontWeight: FontWeight.w500,
                  )),
            ),
          ),
        ],
      ];
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // _HeroPanel — left/top gradient panel with branding
  // ════════════════════════════════════════════════════════════════════════════
  class _HeroPanel extends StatelessWidget {
    @override
    Widget build(BuildContext context) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF3B0D00), Color(0xFF8B1A00), Color(0xFF5A3200)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: Stack(children: [
          // ── Subtle geometric pattern ─────────────────────────────────────────
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),
          // ── Content ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo monogram
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                  ),
                  alignment: Alignment.center,
                  child: const Text('S',
                    style: TextStyle(
                      fontSize: 36, fontWeight: FontWeight.w900,
                      color: Colors.white, letterSpacing: -1,
                    )),
                ),
                const SizedBox(height: 24),
                const Text('Scolaris',
                  style: TextStyle(
                    fontSize: 38, fontWeight: FontWeight.w900,
                    color: Colors.white, letterSpacing: -1.5,
                  )),
                const SizedBox(height: 8),
                Text('La plateforme de gestion\nscolaire africaine.',
                  style: TextStyle(
                    fontSize: 15, color: Colors.white.withOpacity(0.75),
                    height: 1.55, fontWeight: FontWeight.w400,
                  )),
                const SizedBox(height: 48),
                // Feature pills
                ...[
                  (Icons.school_outlined, 'Élèves & Classes'),
                  (Icons.insert_chart_outlined, 'Notes & Bulletins'),
                  (Icons.payments_outlined, 'Finance & Frais'),
                ].map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(e.$1, size: 15, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Text(e.$2,
                      style: TextStyle(
                        fontSize: 13.5, color: Colors.white.withOpacity(0.85),
                        fontWeight: FontWeight.w500,
                      )),
                  ]),
                )),
              ],
            ),
          ),
        ]),
      );
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // _FormCard — wraps form content differently for mobile/desktop
  // ════════════════════════════════════════════════════════════════════════════
  class _FormCard extends StatelessWidget {
    final bool isDesktop;
    final List<Widget> children;
    const _FormCard({required this.isDesktop, required this.children});

    @override
    Widget build(BuildContext context) {
      if (!isDesktop) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
      return Container(
        padding: const EdgeInsets.all(36),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B1A00).withOpacity(0.06),
              blurRadius: 40, offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // _InputField — styled text field
  // ════════════════════════════════════════════════════════════════════════════
  class _InputField extends StatelessWidget {
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

    const _InputField({
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
          fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1A0A00),
        )),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onFieldSubmitted: onSubmitted,
          style: const TextStyle(fontSize: 14.5, color: Color(0xFF1A0A00)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFB09080), fontSize: 14),
            prefixIcon: Icon(icon, size: 17, color: const Color(0xFF7A5C44)),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: const Color(0xFFF8F4F0),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFDDCCBB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFDDCCBB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF8B1A00), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFC62828)),
            ),
          ),
        ),
      ]);
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // _DemoSection — role + subtype picker (demo mode only)
  // ════════════════════════════════════════════════════════════════════════════
  class _DemoSection extends StatelessWidget {
    final String selectedRole;
    final String? selectedSubtype;
    final List<(String, IconData, String)> roles;
    final Map<String, List<(String, String, IconData)>> subTypeMap;
    final ValueChanged<String> onRoleSelected;
    final ValueChanged<String> onSubtypeSelected;

    const _DemoSection({
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFDF5EC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFDDCCBB).withOpacity(0.6)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.play_circle_outline_rounded, size: 13, color: Color(0xFFC17F24)),
            const SizedBox(width: 5),
            const Text('Mode démo — choisir un profil',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF8A5A12))),
          ]),
          const SizedBox(height: 10),
          // Role chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: roles.map((r) {
                final sel = r.$1 == selectedRole;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => onRoleSelected(r.$1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: sel ? const Color(0xFF8B1A00) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: sel ? const Color(0xFF8B1A00) : const Color(0xFFDDCCBB),
                        ),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(r.$2, size: 12, color: sel ? Colors.white : const Color(0xFF7A5C44)),
                        const SizedBox(width: 4),
                        Text(r.$3, style: TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.w600,
                          color: sel ? Colors.white : const Color(0xFF1A0A00),
                        )),
                      ]),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          // Subtype chips
          if (subtypes.isNotEmpty) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: subtypes.map((s) {
                  final sel = s.$1 == selectedSubtype;
                  return Padding(
                    padding: const EdgeInsets.only(right: 5),
                    child: GestureDetector(
                      onTap: () => onSubtypeSelected(s.$1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: sel ? const Color(0xFFFCEDE5) : const Color(0xFFF5F0EB),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: sel ? const Color(0xFF8B1A00).withOpacity(0.4) : Colors.transparent,
                          ),
                        ),
                        child: Text(s.$2, style: TextStyle(
                          fontSize: 11, fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                          color: sel ? const Color(0xFF8B1A00) : const Color(0xFF7A5C44),
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

  // ════════════════════════════════════════════════════════════════════════════
  // _GridPainter — subtle decorative grid for hero panel
  // ════════════════════════════════════════════════════════════════════════════
  class _GridPainter extends CustomPainter {
    @override
    void paint(Canvas canvas, Size size) {
      final paint = Paint()
        ..color = Colors.white.withOpacity(0.04)
        ..strokeWidth = 0.8;
      const step = 48.0;
      for (double x = 0; x < size.width; x += step) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      }
      for (double y = 0; y < size.height; y += step) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
      // decorative circles
      final circlePaint = Paint()
        ..color = Colors.white.withOpacity(0.06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.15), 80, circlePaint);
      canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.85), 120, circlePaint);
    }

    @override
    bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
  }

  // ════════════════════════════════════════════════════════════════════════════
  // _QrScannerOverlay
  // ════════════════════════════════════════════════════════════════════════════
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
          // Semi-transparent overlay with hole
          Positioned.fill(
            child: CustomPaint(painter: _ScannerFramePainter()),
          ),
          // Top bar
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
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  onPressed: onClose,
                ),
                const Expanded(
                  child: Text('Scanner le QR code Scolaris',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                ),
                const SizedBox(width: 48),
              ]),
            ),
          ),
          // Instruction
          Positioned(
            bottom: 60, left: 0, right: 0,
            child: Text('Pointez la caméra vers le QR code affiché dans votre profil',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
          ),
        ]),
      );
    }
  }

  class _ScannerFramePainter extends CustomPainter {
    @override
    void paint(Canvas canvas, Size size) {
      final cx = size.width / 2, cy = size.height / 2;
      const boxSize = 220.0, r = 16.0;
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy), width: boxSize, height: boxSize),
        const Radius.circular(r),
      );
      final paint = Paint()..color = Colors.black54;
      canvas.drawPath(
        Path.combine(
          PathOperation.difference,
          Path()..addRect(Offset.zero & size),
          Path()..addRRect(rect),
        ),
        paint,
      );
      // Corner marks
      final linePaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      const armLen = 28.0;
      final l = cx - boxSize / 2, t = cy - boxSize / 2;
      final rr = cx + boxSize / 2, b = cy + boxSize / 2;
      for (final (ox, oy, dx, dy) in [
        (l + r, t,    1.0,  0.0), (l, t + r,    0.0,  1.0),
        (rr - r, t,  -1.0,  0.0), (rr, t + r,   0.0,  1.0),
        (l + r, b,    1.0,  0.0), (l, b - r,    0.0, -1.0),
        (rr - r, b,  -1.0,  0.0), (rr, b - r,   0.0, -1.0),
      ]) {
        canvas.drawLine(
          Offset(ox, oy),
          Offset(ox + dx * armLen, oy + dy * armLen),
          linePaint,
        );
      }
    }

    @override
    bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
  }
  