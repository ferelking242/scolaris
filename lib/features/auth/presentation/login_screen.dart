import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/config/app_config.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
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
const _dark   = Color(0xFF0D1117);
const _bg0    = Color(0xFF0A2010);
const _bg1    = Color(0xFF1B5E20);

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController(text: 'student@scolaris.app');
  final _passCtrl  = TextEditingController(text: 'demo1234');
  final _form      = GlobalKey<FormState>();

  bool _loading  = false;
  bool _obscure  = true;
  String? _error;
  String _selectedRole    = 'student';
  String? _selectedSubtype = 'lycee';
  bool _showQrScanner  = false;

  late final TabController _tabCtrl;

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
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _tabCtrl.dispose();
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

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(signInUseCaseProvider)(
          _emailCtrl.text.trim(), _passCtrl.text);
    } on ArgumentError catch (e) {
      setState(() => _error = (e.message as String).tr());
    } catch (_) {
      setState(() => _error = 'auth.errors.failed'.tr());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleQrDetected(String rawValue) async {
    setState(() { _showQrScanner = false; _loading = true; _error = null; });
    try {
      await ref.read(signInWithQrUseCaseProvider)(rawValue);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'QR invalide ou carte non reconnue. Veuillez réessayer.';
          _loading = false;
        });
      }
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
    if (_showQrScanner) return _QrScanPanel(onDetected: _handleQrDetected,
        onClose: () => setState(() => _showQrScanner = false));

    return Container(
      color: const Color(0xFFFDFAF7),
      child: LayoutBuilder(builder: (ctx, constraints) {
        final hPad = constraints.maxWidth > 480 ? 32.0 : 22.0;
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showBrand) ...[
                _BrandMark(),
                const SizedBox(height: 24),
              ],

              const Text('Connexion', style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.w900, color: _ink, letterSpacing: -.3,
              )),
              const SizedBox(height: 3),
              Text('Accédez à votre espace Scolaris',
                  style: TextStyle(color: _muted, fontSize: 13)),
              const SizedBox(height: 20),

              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _border.withOpacity(.5)),
                  boxShadow: [BoxShadow(color: _ink.withOpacity(.05), blurRadius: 24, offset: const Offset(0, 6))],
                ),
                child: Column(children: [
                  _tabBar(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
                    child: SizedBox(
                      height: 370,
                      child: TabBarView(
                        controller: _tabCtrl,
                        children: [
                          _buildEmailForm(),
                          _buildQrTab(),
                        ],
                      ),
                    ),
                  ),
                ]),
              ),

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

              // ── Sous-profil ───────────────────────────────────────────────
              if (_subTypeMap.containsKey(_selectedRole)) ...[
                const SizedBox(height: 12),
                Row(children: [
                  const Icon(Icons.subdirectory_arrow_right_rounded,
                      size: 13, color: Color(0xFFB08060)),
                  const SizedBox(width: 4),
                  Text('Sous-profil',
                      style: const TextStyle(
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

              const SizedBox(height: 8),
              Center(
                child: Text('Mot de passe universel : demo1234',
                    style: TextStyle(color: _muted.withOpacity(.55), fontSize: 11)),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _tabBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0EC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: TabBar(
        controller: _tabCtrl,
        labelColor: _terra,
        unselectedLabelColor: _muted,
        indicator: BoxDecoration(
          color: _white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          border: Border(bottom: BorderSide(color: _terra, width: 2.5)),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        tabs: const [
          Tab(text: 'Connexion'),
          Tab(text: 'Scanner ID'),
        ],
      ),
    );
  }

  Widget _buildEmailForm() {
    return Form(
      key: _form,
      child: Column(
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
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'E-mail requis';
              if (!v.contains('@')) return 'E-mail invalide';
              return null;
            },
          ),
          const SizedBox(height: 16),
          Row(children: [
            _fieldLabel('Mot de passe'),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
              child: const Text('Mot de passe oublié ?',
                  style: TextStyle(color: _terra, fontSize: 12,
                      fontWeight: FontWeight.w600)),
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
            validator: (v) => (v == null || v.isEmpty) ? 'Mot de passe requis' : null,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _ErrorBanner(message: _error!),
          ],
          const SizedBox(height: 20),
          _PrimaryBtn(label: 'Se connecter', loading: _loading, onTap: _submit),
          const SizedBox(height: 16),
          _dividerSmall('ou'),
          const SizedBox(height: 16),
          _RegisterSchoolBtn(onTap: () => context.go(AppRoutes.registerSchool)),
        ],
      ),
    );
  }

  Widget _buildQrTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF0D3B1E).withOpacity(.06), _gold.withOpacity(.06)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _terra.withOpacity(.12)),
          ),
          child: Column(children: [
            SizedBox(
              height: 140,
              child: Lottie.asset(
                'assets/lottie/qr_scan.json',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(Icons.qr_code_rounded, size: 80, color: _terra.withOpacity(.4)),
              ),
            ),
            const SizedBox(height: 10),
            const Text('Connectez-vous avec votre\ncarte étudiante',
                textAlign: TextAlign.center,
                style: TextStyle(color: _ink, fontSize: 15,
                    fontWeight: FontWeight.w700, height: 1.4)),
            const SizedBox(height: 6),
            Text(
              'Scannez le QR code de votre carte étudiante pour vous connecter instantanément.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 12, height: 1.5),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        if (_error != null) ...[
          _ErrorBanner(message: _error!),
          const SizedBox(height: 12),
        ],
        _PrimaryBtn(
          label: 'Scanner ma carte étudiante',
          loading: _loading,
          icon: Icons.qr_code_scanner_rounded,
          onTap: () => setState(() { _showQrScanner = true; _error = null; }),
        ),
        const SizedBox(height: 12),
        _SecondaryBtn(
          label: 'Saisir mon code manuellement',
          icon: Icons.keyboard_outlined,
          onTap: () => _tabCtrl.animateTo(0),
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

  Widget _dividerSmall(String label) => Row(children: [
    const Expanded(child: Divider(color: _border, height: 1)),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(label, style: TextStyle(color: _muted.withOpacity(.6), fontSize: 12)),
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
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      child: Column(
        children: [
          Row(children: [
            _LogoImg(size: 40),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Scolaris',
                  style: TextStyle(color: _white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: .5)),
              Text(AppConfig.appTagline,
                  style: TextStyle(color: _gold.withOpacity(.85), fontSize: 10, fontStyle: FontStyle.italic)),
            ]),
          ]),
          const SizedBox(height: 16),
          const Text('Bienvenue sur Scolaris',
              style: TextStyle(color: _white, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text('Plateforme scolaire africaine de nouvelle génération',
              textAlign: TextAlign.center,
              style: TextStyle(color: _white.withOpacity(.68), fontSize: 12, height: 1.5)),
          const SizedBox(height: 14),
          Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: const [
            _FeaturePill(icon: Icons.people_rounded, label: '6 rôles'),
            _FeaturePill(icon: Icons.wifi_off_rounded, label: 'Hors-ligne'),
            _FeaturePill(icon: Icons.translate_rounded, label: '4 langues'),
          ]),
        ],
      ),
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

// ── QR Scanner Panel ──────────────────────────────────────────────────────
class _QrScanPanel extends StatefulWidget {
  final void Function(String) onDetected;
  final VoidCallback onClose;
  const _QrScanPanel({required this.onDetected, required this.onClose});

  @override
  State<_QrScanPanel> createState() => _QrScanPanelState();
}

class _QrScanPanelState extends State<_QrScanPanel> {
  final _ctrl = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    returnImage: false,
  );
  bool _scanned = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _dark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _ctrl,
            onDetect: (capture) {
              if (_scanned) return;
              final raw = capture.barcodes.firstOrNull?.rawValue;
              if (raw != null && raw.isNotEmpty) {
                _scanned = true;
                widget.onDetected(raw);
              }
            },
          ),

          CustomPaint(painter: _ScanFramePainter()),

          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(children: [
                  GestureDetector(
                    onTap: widget.onClose,
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: _white.withOpacity(.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, color: _white, size: 22),
                    ),
                  ),
                  const Spacer(),
                  const Text('Scanner carte étudiante',
                      style: TextStyle(color: _white, fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _ctrl.toggleTorch(),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: _white.withOpacity(.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.flashlight_on_rounded, color: _white, size: 20),
                    ),
                  ),
                ]),
              ),
            ),
          ),

          Positioned(
            bottom: 0, left: 0, right: 0,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _white.withOpacity(.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _white.withOpacity(.15)),
                ),
                child: Column(children: [
                  const Icon(Icons.credit_card_rounded, color: _gold, size: 28),
                  const SizedBox(height: 10),
                  const Text('Pointez votre caméra vers le QR code\nde votre carte étudiante',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _white, fontSize: 13,
                          fontWeight: FontWeight.w600, height: 1.5)),
                  const SizedBox(height: 6),
                  Text(
                    'Le QR code contient votre identifiant étudiant (ID, établissement, promo)',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _white.withOpacity(.6), fontSize: 11, height: 1.4),
                  ),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dim = size.width * 0.65;
    final left = (size.width - dim) / 2;
    final top  = (size.height - dim) / 2 - 40;

    final overlay = Paint()..color = Colors.black.withOpacity(.55);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, top), overlay);
    canvas.drawRect(Rect.fromLTWH(0, top + dim, size.width, size.height - top - dim), overlay);
    canvas.drawRect(Rect.fromLTWH(0, top, left, dim), overlay);
    canvas.drawRect(Rect.fromLTWH(left + dim, top, size.width - left - dim, dim), overlay);

    final corner = Paint()
      ..color = ScolarisPalette.gold
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const r = 12.0;
    final pts = [
      [Offset(left, top + r), Offset(left, top), Offset(left + r, top)],
      [Offset(left + dim - r, top), Offset(left + dim, top), Offset(left + dim, top + r)],
      [Offset(left + dim, top + dim - r), Offset(left + dim, top + dim), Offset(left + dim - r, top + dim)],
      [Offset(left, top + dim - r), Offset(left, top + dim), Offset(left + r, top + dim)],
    ];
    for (final p in pts) {
      final path = Path()
        ..moveTo(p[0].dx, p[0].dy)
        ..lineTo(p[1].dx, p[1].dy)
        ..lineTo(p[2].dx, p[2].dy);
      canvas.drawPath(path, corner);
    }

    final line = Paint()
      ..color = ScolarisPalette.gold.withOpacity(.7)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(left + 12, top + dim / 2), Offset(left + dim - 12, top + dim / 2), line);
  }

  @override
  bool shouldRepaint(_) => false;
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

// ── Feature Pill ──────────────────────────────────────────────────────────
class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeaturePill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _white.withOpacity(.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _white.withOpacity(.18)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: _gold),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: _white, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ── Form Widgets ──────────────────────────────────────────────────────────
class _STextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboard;
  final String? Function(String?)? validator;
  const _STextField({
    required this.controller, required this.hint, required this.icon,
    this.obscure = false, this.suffix, this.keyboard, this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      validator: validator,
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
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 54,
        alignment: Alignment.center,
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
    );
  }
}

class _SecondaryBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  const _SecondaryBtn({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border, width: 1.5),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 18, color: _terra),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: _ink, fontSize: 14,
              fontWeight: FontWeight.w600)),
        ]),
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
    return GestureDetector(
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
    return GestureDetector(
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
    );
  }
}

class _RegisterSchoolBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _RegisterSchoolBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFF071A0A), const Color(0xFF0D3B1E)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: const Color(0xFF1B5E20).withOpacity(.35),
                blurRadius: 16, offset: const Offset(0, 6)),
          ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: _gold.withOpacity(.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add_business_outlined, size: 16, color: _gold),
          ),
          const SizedBox(width: 10),
          const Text('Inscrire mon école',
              style: TextStyle(
                color: _white,
                fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: .3,
              )),
        ]),
      ),
    );
  }
}
