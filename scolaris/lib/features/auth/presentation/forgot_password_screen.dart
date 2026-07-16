import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

import '../../../core/theme/app_theme.dart';

const _terra  = ScolarisPalette.terracotta;
const _orange = ScolarisPalette.orange;
const _gold   = ScolarisPalette.gold;
const _green  = ScolarisPalette.forestGreen;
const _cream  = ScolarisPalette.cream;
const _ink    = Color(0xFF1A0A00);
const _muted  = Color(0xFF7A5C44);
const _border = Color(0xFFDDCCBB);
const _white  = Colors.white;

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _form      = GlobalKey<FormState>();
  bool _loading    = false;
  bool _sent       = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() { _loading = false; _sent = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _cream,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                  child: _sent ? _buildSuccess() : _buildForm(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: _white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF5EEE6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_rounded, color: _ink, size: 20),
          ),
        ),
        const SizedBox(width: 14),
        const Text('Mot de passe oublié',
            style: TextStyle(color: _ink, fontSize: 17, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 220,
            child: Lottie.network(
              'https://assets9.lottiefiles.com/packages/lf20_pprxh53t.json',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.lock_reset_rounded, size: 80, color: _terra),
              ),
            ),
          ),
          const SizedBox(height: 8),

          const Text('Réinitialiser votre mot de passe',
              textAlign: TextAlign.center,
              style: TextStyle(color: _ink, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text(
            'Saisissez l\'adresse e-mail associée à votre compte Scolaris. '
            'Nous vous enverrons un lien pour réinitialiser votre mot de passe.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 13.5, height: 1.6),
          ),
          const SizedBox(height: 32),

          const _FieldLabel('Adresse e-mail'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(fontSize: 14, color: _ink),
            decoration: InputDecoration(
              hintText: 'votre@email.com',
              hintStyle: TextStyle(color: _muted.withOpacity(.6)),
              prefixIcon: const Icon(Icons.mail_outline_rounded, size: 20, color: _muted),
              filled: true,
              fillColor: _white,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
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
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'E-mail requis';
              if (!v.contains('@')) return 'E-mail invalide';
              return null;
            },
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline, size: 16, color: Color(0xFFDC2626)),
                const SizedBox(width: 10),
                Expanded(child: Text(_error!,
                    style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12.5))),
              ]),
            ),
          ],

          const SizedBox(height: 28),
          GestureDetector(
            onTap: _loading ? null : _submit,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _loading
                      ? [_terra.withOpacity(.6), _orange.withOpacity(.6)]
                      : [_terra, _orange],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: _loading ? [] : [
                  BoxShadow(color: _terra.withOpacity(.35),
                      blurRadius: 14, offset: const Offset(0, 5)),
                ],
              ),
              child: _loading
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: _white))
                  : const Text('Envoyer le lien de réinitialisation',
                      style: TextStyle(color: _white, fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),

          const SizedBox(height: 20),
          Center(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: RichText(
                text: const TextSpan(
                  text: 'Vous vous souvenez ? ',
                  style: TextStyle(color: _muted, fontSize: 13),
                  children: [
                    TextSpan(text: 'Retour à la connexion',
                        style: TextStyle(color: _terra, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),
          _HelpSection(),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        SizedBox(
          height: 200,
          child: Lottie.network(
            'https://assets2.lottiefiles.com/packages/lf20_jbrw3hcz.json',
            fit: BoxFit.contain,
            repeat: false,
            errorBuilder: (_, __, ___) => const Center(
              child: Icon(Icons.check_circle_rounded, size: 80, color: _green),
            ),
          ),
        ),
        const SizedBox(height: 24),

        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _green.withOpacity(.2)),
          ),
          child: Column(children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                color: _green.withOpacity(.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mark_email_read_rounded, color: _green, size: 30),
            ),
            const SizedBox(height: 16),
            const Text('Email envoyé !',
                style: TextStyle(color: _ink, fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text(
              'Un lien de réinitialisation a été envoyé à\n${_emailCtrl.text.trim()}\n\nVérifiez votre boîte mail et cliquez sur le lien pour créer un nouveau mot de passe.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 13.5, height: 1.6),
            ),
          ]),
        ),

        const SizedBox(height: 24),
        GestureDetector(
          onTap: () => setState(() { _sent = false; _emailCtrl.clear(); }),
          child: Container(
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border, width: 1.5),
            ),
            child: const Text('Renvoyer un email',
                style: TextStyle(color: _ink, fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_terra, _orange]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: _terra.withOpacity(.3),
                  blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: const Text('Retour à la connexion',
                style: TextStyle(color: _white, fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(fontSize: 13, color: _ink, fontWeight: FontWeight.w600));
  }
}

class _HelpSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _gold.withOpacity(.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _gold.withOpacity(.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.help_outline_rounded, color: _gold, size: 18),
          const SizedBox(width: 8),
          const Text('Besoin d\'aide ?',
              style: TextStyle(color: _ink, fontSize: 14, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 10),
        _HelpItem(
          icon: Icons.admin_panel_settings_outlined,
          text: 'Contactez votre administrateur scolaire si vous n\'avez pas accès à votre email.',
        ),
        const SizedBox(height: 8),
        _HelpItem(
          icon: Icons.qr_code_scanner_rounded,
          text: 'Vous pouvez aussi vous connecter avec le QR code de votre carte étudiante.',
        ),
        const SizedBox(height: 8),
        _HelpItem(
          icon: Icons.support_agent_rounded,
          text: 'Support : support@scolaris.app',
        ),
      ]),
    );
  }
}

class _HelpItem extends StatelessWidget {
  final IconData icon;
  final String text;
  const _HelpItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 15, color: _muted),
      const SizedBox(width: 8),
      Expanded(child: Text(text,
          style: const TextStyle(color: _muted, fontSize: 12.5, height: 1.5))),
    ]);
  }
}
