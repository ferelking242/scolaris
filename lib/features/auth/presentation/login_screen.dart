import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
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
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _loading  = false;
  bool _obscure  = true;
  bool _remember = false;
  String? _error;
  int  _demoTapCount  = 0;

  // ── Sélecteur de design mobile (test A/B, à retirer une fois le choix fait) ──
  int _mobileDesign = 1; // 0 = classique, 1 = vague, 2 = carte, 3 = retour, 4 = diagonale
  static const _mobileDesignNames = ['Classique', 'Vague', 'Carte', 'Retour', 'Diagonale'];

  void _handleTitleTap(BuildContext context) {
    setState(() {
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
    });
  }

  void _pickMobileDesign(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text('Choisir un design de connexion',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _ink)),
              ),
              for (int i = 0; i < _mobileDesignNames.length; i++)
                ListTile(
                  leading: Icon(
                    _mobileDesign == i ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: _terra,
                  ),
                  title: Text(_mobileDesignNames[i]),
                  onTap: () {
                    setState(() => _mobileDesign = i);
                    Navigator.pop(ctx);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
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
    return Stack(
      children: [
        switch (_mobileDesign) {
          0 => _buildMobileClassic(context),
          2 => _buildMobileCard(context),
          3 => _buildMobileWelcomeBack(context),
          4 => _buildMobileDiagonal(context),
          _ => _buildMobileWave(context),
        },

        // Bouton flottant de test : bascule entre les designs de login
        Positioned(
          top: 8, right: 8,
          child: SafeArea(
            child: Material(
              color: Colors.black.withOpacity(.35),
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'Changer de design (${_mobileDesignNames[_mobileDesign]})',
                icon: const Icon(Icons.palette_outlined, color: Colors.white, size: 20),
                onPressed: () => _pickMobileDesign(context),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Design 1 : classique (en-tête bandeau + carte) ─────────────────────────
  Widget _buildMobileClassic(BuildContext context) {
    return Container(
      color: _cream,
      child: SafeArea(
        child: Column(
          children: [
            Container(
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
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Scolaris',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: _white, fontWeight: FontWeight.w900, fontSize: 17, letterSpacing: .5)),
                      Text(AppConfig.appTagline,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: _gold.withOpacity(.85), fontSize: 10, fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
              ]),
            ),
            Expanded(child: _buildFormPanel(context, showBrand: false)),
          ],
        ),
      ),
    );
  }

  // ── Design 2 : vague (fond dégradé + panneau blanc courbe) ──────────────────
  Widget _buildMobileWave(BuildContext context) {
    return Stack(
      children: [
        // Fond dégradé terracotta plein écran + motif africain discret
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A0A00), Color(0xFF8B1A00), Color(0xFFC17F24)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: CustomPaint(painter: _AfricanPatternPainter()),
          ),
        ),

        SafeArea(
          bottom: false,
          child: Column(
            children: [
              // En-tête : retour + logo + nom
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 20, 18),
                child: Row(
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(width: 34, height: 34),
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _white, size: 18),
                    ),
                    const Spacer(),
                    _LogoImg(size: 28),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text('Scolaris',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: _white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: .4)),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Bonjour 👋', style: TextStyle(
                        color: _white, fontSize: 26, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text('Connectez-vous à votre espace',
                        style: TextStyle(color: _white.withOpacity(.85), fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Vague blanche contenant le formulaire
              Expanded(
                child: ClipPath(
                  clipper: _WaveClipper(),
                  child: Container(
                    color: const Color(0xFFFDFAF7),
                    child: _buildFormPanel(context, showBrand: false),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Design 3 : carte flottante (dégradé + panneau blanc accroché) ──────────
  Widget _buildMobileCard(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_gold, _orange, _terra],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
                children: [
                  Positioned.fill(child: CustomPaint(painter: _BubblesPainter())),
                  Column(
                    children: [
                      const SizedBox(height: 30),
                      _LogoImg(size: 54),
                      const SizedBox(height: 10),
                      Text('Scolaris', style: TextStyle(
                          color: _white, fontWeight: FontWeight.w900, fontSize: 19, letterSpacing: .4)),
                      const SizedBox(height: 18),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                          ),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(26, 28, 26, 22),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => _handleTitleTap(context),
                                  child: const Text('Bonjour !', style: TextStyle(
                                      color: _terra, fontSize: 26, fontWeight: FontWeight.w900)),
                                ),
                                const SizedBox(height: 4),
                                Text('Connectez-vous à votre espace',
                                    style: TextStyle(color: _muted, fontSize: 13)),
                                const SizedBox(height: 22),
                                _PillField(
                                  controller: _emailCtrl,
                                  hint: 'Adresse e-mail',
                                  icon: Icons.mail_outline_rounded,
                                  keyboard: TextInputType.emailAddress,
                                ),
                                const SizedBox(height: 14),
                                _PillField(
                                  controller: _passCtrl,
                                  hint: 'Mot de passe',
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
                                const SizedBox(height: 22),
                                SizedBox(
                                  height: 54,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(colors: [_gold, _orange]),
                                      borderRadius: BorderRadius.circular(999),
                                      boxShadow: [
                                        BoxShadow(color: _orange.withOpacity(.4),
                                            blurRadius: 16, offset: const Offset(0, 6)),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(999),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(999),
                                        onTap: _loading ? null : _submit,
                                        child: Center(
                                          child: _loading
                                              ? const SizedBox(width: 22, height: 22,
                                                  child: CircularProgressIndicator(strokeWidth: 2.2, color: _white))
                                              : const Text('Se connecter', style: TextStyle(
                                                  color: _white, fontSize: 15,
                                                  fontWeight: FontWeight.w800, letterSpacing: .3)),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Center(
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: GestureDetector(
                                      onTap: () => Navigator.push(context,
                                          MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                                      child: const Text('Mot de passe oublié ?',
                                          style: TextStyle(color: _terra, fontSize: 12.5,
                                              fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                                ),
                                if (_demoTapCount >= 3) ...[
                                  const SizedBox(height: 20),
                                  _divider('Comptes démo — connexion rapide'),
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
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  // ── Design 4 : "Content de vous revoir" (illustration + carte plate) ───────
  Widget _buildMobileWelcomeBack(BuildContext context) {
    return Container(
      color: _cream,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 96, height: 96,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [_gold, _orange]),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: _orange.withOpacity(.30), blurRadius: 22, offset: const Offset(0, 10)),
                        ],
                      ),
                    ),
                    const Icon(Icons.lock_person_rounded, color: _white, size: 42),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _handleTitleTap(context),
                child: const Text('Content de vous revoir !',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _ink)),
              ),
              const SizedBox(height: 6),
              Text('Connectez-vous pour accéder à votre espace Scolaris',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: _muted)),
              const SizedBox(height: 26),
              Center(
                child: Text('CONNEXION', style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800, color: _muted, letterSpacing: 1.2)),
              ),
              const SizedBox(height: 14),
              _fieldLabel('Adresse e-mail'),
              const SizedBox(height: 6),
              _STextField(
                controller: _emailCtrl,
                hint: 'nom@ecole.com',
                icon: Icons.mail_outline_rounded,
                keyboard: TextInputType.emailAddress,
              ),
              const SizedBox(height: 14),
              _fieldLabel('Mot de passe'),
              const SizedBox(height: 6),
              _STextField(
                controller: _passCtrl,
                hint: '••••••••',
                icon: Icons.lock_outline_rounded,
                obscure: _obscure,
                suffix: IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                  icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 18, color: _muted),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                _ErrorBanner(message: _error!),
              ],
              const SizedBox(height: 10),
              Row(children: [
                SizedBox(
                  width: 22, height: 22,
                  child: Checkbox(
                    value: _remember,
                    activeColor: _terra,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (v) => setState(() => _remember = v ?? false),
                  ),
                ),
                const SizedBox(width: 8),
                Text('Se souvenir de moi', style: TextStyle(fontSize: 12, color: _muted)),
                const Spacer(),
                Flexible(
                  child: GestureDetector(
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                    child: const Text('Mot de passe oublié ?',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _terra, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
              const SizedBox(height: 18),
              _PrimaryBtn(label: 'Se connecter', loading: _loading, onTap: _submit),
              const SizedBox(height: 18),
              _divider('Ou se connecter avec'),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  _SocialCircle(icon: Icons.school_rounded, color: Color(0xFF8B1A00)),
                  SizedBox(width: 14),
                  _SocialCircle(icon: Icons.family_restroom_rounded, color: Color(0xFFC17F24)),
                  SizedBox(width: 14),
                  _SocialCircle(icon: Icons.menu_book_rounded, color: Color(0xFF1B5E20)),
                ],
              ),
              if (_demoTapCount >= 3) ...[
                const SizedBox(height: 22),
                _divider('Comptes démo — connexion rapide'),
                const SizedBox(height: 12),
                _SchoolsQuickLogin(onTap: _fillAndLogin),
                const SizedBox(height: 8),
                Center(
                  child: Text('Mot de passe universel : demo1234',
                      style: TextStyle(color: _muted.withOpacity(.55), fontSize: 11)),
                ),
              ],
              const SizedBox(height: 20),
              Center(
                child: Text.rich(TextSpan(
                  style: TextStyle(fontSize: 12.5, color: _muted),
                  children: [
                    const TextSpan(text: 'Pas encore de compte ? '),
                    TextSpan(
                      text: 'Créer un compte',
                      style: const TextStyle(color: _terra, fontWeight: FontWeight.w700),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {},
                    ),
                  ],
                )),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Design 5 : diagonale (dégradé + rayures + panneau blanc) ───────────────
  Widget _buildMobileDiagonal(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_terra, _orange, _gold],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
                children: [
                  Positioned.fill(child: CustomPaint(painter: _DiagonalStripesPainter())),
                  Column(
                    children: [
                      const SizedBox(height: 30),
                      _LogoImg(size: 54),
                      const SizedBox(height: 10),
                      Text('Scolaris', style: TextStyle(
                          color: _white, fontWeight: FontWeight.w900, fontSize: 19, letterSpacing: .4)),
                      const SizedBox(height: 18),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                          ),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(26, 28, 26, 22),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => _handleTitleTap(context),
                                  child: const Text('Bonjour !', style: TextStyle(
                                      color: _terra, fontSize: 26, fontWeight: FontWeight.w900)),
                                ),
                                const SizedBox(height: 4),
                                Text('Connectez-vous à votre espace',
                                    style: TextStyle(color: _muted, fontSize: 13)),
                                const SizedBox(height: 22),
                                _PillField(
                                  controller: _emailCtrl,
                                  hint: 'Adresse e-mail',
                                  icon: Icons.mail_outline_rounded,
                                  keyboard: TextInputType.emailAddress,
                                ),
                                const SizedBox(height: 14),
                                _PillField(
                                  controller: _passCtrl,
                                  hint: 'Mot de passe',
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
                                const SizedBox(height: 22),
                                SizedBox(
                                  height: 54,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(colors: [_terra, _orange]),
                                      borderRadius: BorderRadius.circular(999),
                                      boxShadow: [
                                        BoxShadow(color: _terra.withOpacity(.4),
                                            blurRadius: 16, offset: const Offset(0, 6)),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(999),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(999),
                                        onTap: _loading ? null : _submit,
                                        child: Center(
                                          child: _loading
                                              ? const SizedBox(width: 22, height: 22,
                                                  child: CircularProgressIndicator(strokeWidth: 2.2, color: _white))
                                              : const Text('Se connecter', style: TextStyle(
                                                  color: _white, fontSize: 15,
                                                  fontWeight: FontWeight.w800, letterSpacing: .3)),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Center(
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: GestureDetector(
                                      onTap: () => Navigator.push(context,
                                          MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                                      child: const Text('Mot de passe oublié ?',
                                          style: TextStyle(color: _terra, fontSize: 12.5,
                                              fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                                ),
                                if (_demoTapCount >= 3) ...[
                                  const SizedBox(height: 20),
                                  _divider('Comptes démo — connexion rapide'),
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
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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

              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _handleTitleTap(context),
                child: Text('Connexion', style: TextStyle(
                    fontSize: showBrand ? 28 : 22,
                    fontWeight: FontWeight.w900, color: _ink, letterSpacing: -.3,
                  )),
              ),
              if (showBrand) ...[
                const SizedBox(height: 3),
                Text('Accédez à votre espace Scolaris',
                    style: TextStyle(color: _muted, fontSize: 13)),
              ],
              SizedBox(height: showBrand ? 20 : 4),

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
                _divider('Comptes démo — connexion rapide'),
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
            Flexible(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                  child: const Text('Mot de passe oublié ?',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: _terra, fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
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
    // École Test Scolaris — seule école depuis le nettoyage du 2026-08-03
    // (cf. memory/reset-test-data-2026-08-03), 4 comptes avec un vrai login.
    const accounts = <(String, String, IconData, Color, String)>[
      ('Admin',   'kenganiboveldy@gmail.com', Icons.shield_moon_outlined, Color(0xFF0D3B1E), 'demo1234'),
      ('Prof',    'prof1@test.local',         Icons.menu_book_outlined,  Color(0xFF0277BD), 'demo1234'),
      ('Élève',   'eleve51@test.local',       Icons.school_outlined,     _green,            'demo1234'),
      ('Parent',  'parent1@test.local',       Icons.family_restroom_outlined, Color(0xFF7C3AED), 'demo1234'),
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

// ── Wave Clipper (forme incurvée façon maquette) ───────────────────────────
class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()
      ..lineTo(0, 40)
      ..quadraticBezierTo(size.width * 0.28, 0, size.width * 0.62, 18)
      ..quadraticBezierTo(size.width * 0.86, 32, size.width, 4)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(_) => false;
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

// ── Champ pilule (design "Carte") ──────────────────────────────────────────
class _PillField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboard;
  const _PillField({
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
        fillColor: const Color(0xFFF5F0EC),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: const BorderSide(color: _terra, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.8),
        ),
      ),
    );
  }
}

// ── Bulles décoratives (design "Carte") ─────────────────────────────────────
class _BubblesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    p.color = _white.withOpacity(.10);
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.16), 46, p);
    p.color = _white.withOpacity(.08);
    canvas.drawCircle(Offset(size.width * 0.14, size.height * 0.30), 30, p);
    p.color = _white.withOpacity(.14);
    canvas.drawCircle(Offset(size.width * 0.72, size.height * 0.32), 16, p);
    p.color = _white.withOpacity(.07);
    canvas.drawCircle(Offset(size.width * 0.05, size.height * 0.08), 20, p);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Rayures diagonales (design "Diagonale") ─────────────────────────────────
class _DiagonalStripesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _white.withOpacity(.08)
      ..strokeWidth = 2.2;
    for (double x = -size.height; x < size.width; x += 26) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Bouton "réseau social" décoratif (design "Retour") ──────────────────────
class _SocialCircle extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _SocialCircle({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44, height: 44,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Icon(icon, color: Colors.white, size: 20),
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

  // ═══════════════════════════════════════════════════════════════════════════════
  // Écoles — Quick Login Widgets (Primaire · Collège · Lycée)
  // ═══════════════════════════════════════════════════════════════════════════════

  class _SchoolUser {
    final String label, subtitle, email, school;
    final IconData icon;
    final Color color;
    const _SchoolUser({required this.label,required this.subtitle,required this.email,required this.icon,required this.color,required this.school});
  }

  const _demoPass = 'demo1234';

  // Une seule école de test depuis le grand nettoyage du 2026-08-03 (cf.
  // memory/reset-test-data-2026-08-03) : « École Test Scolaris », primaire
  // (CP1→CM2) + collège (6ème→3ème) + lycée (2nde/1ère/Terminale série C).
  // Seuls ces comptes ont un VRAI login (auth.users) — les autres profs/
  // élèves recréés sont de pures fiches de données, sans mot de passe.
  const _schoolUsers = [
    _SchoolUser(label:'Sylvie Kanga',subtitle:'Admin · École Test Scolaris',email:'admin1@test.local',icon:Icons.admin_panel_settings_rounded,color:Color(0xFF8B1A00),school:'Primaire'),
    _SchoolUser(label:'Boveldy Kengani',subtitle:'Super-admin · Console plateforme',email:'kenganiboveldy@gmail.com',icon:Icons.workspace_premium_rounded,color:Color(0xFF3E1A00),school:'Primaire'),
    _SchoolUser(label:'Georges Mombeki',subtitle:'Enseignant · École Test Scolaris',email:'prof1@test.local',icon:Icons.menu_book_rounded,color:Color(0xFF0277BD),school:'Primaire'),
    _SchoolUser(label:'Alice Moukoko',subtitle:'Élève · CM2',email:'eleve51@test.local',icon:Icons.school_rounded,color:Color(0xFF2E7D32),school:'Primaire'),
    _SchoolUser(label:'Pauline Moukoko',subtitle:'Parent · mère d\'Alice',email:'parent1@test.local',icon:Icons.family_restroom_rounded,color:Color(0xFF00897B),school:'Primaire'),
    _SchoolUser(label:'Alice Samba',subtitle:'Élève · 4ème',email:'eleve74@test.local',icon:Icons.school_rounded,color:Color(0xFF6D28D9),school:'Collège'),
    _SchoolUser(label:'Estelle Samba',subtitle:'Élève · Terminale C',email:'eleve106@test.local',icon:Icons.school_rounded,color:Color(0xFFB45309),school:'Lycée'),
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
      const tabs = ['Tous', 'Primaire', 'Collège', 'Lycée'];
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
  