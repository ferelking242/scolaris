import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/sources/remote/supabase_db_source.dart';
import '../../../shared/data/enrollment_config.dart';
import '../../../shared/pages/enrollment_page.dart';

const _terra = Color(0xFF8B1A00);
const _orange = Color(0xFFD4540A);
const _gold = Color(0xFFC17F24);
const _ink = Color(0xFF1A0A00);
const _muted = Color(0xFF7A5C44);
const _bg = Color(0xFFF5EEE6);
const _border = Color(0xFFDDCCBB);

/// Formulaire de **pré-inscription publique** (sans compte), ouvert par le lien
/// ou le QR de l'école (`schoolCode` = `schools.slug`). Résout l'école depuis
/// la vue publique `public_schools` avant d'afficher le formulaire — une école
/// introuvable ou qui a fermé sa période affiche un état dédié plutôt qu'un
/// formulaire qui échouerait à l'envoi (la RLS le refuserait de toute façon).
class PublicEnrollmentScreen extends StatefulWidget {
  final String schoolCode;
  const PublicEnrollmentScreen({super.key, required this.schoolCode});

  @override
  State<PublicEnrollmentScreen> createState() =>
      _PublicEnrollmentScreenState();
}

class _PublicEnrollmentScreenState extends State<PublicEnrollmentScreen> {
  late final Future<Map<String, dynamic>?> _school =
      SupabaseDbSource.getPublicSchoolBySlug(widget.schoolCode.trim().toLowerCase());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>?>(
          future: _school,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(
                  child: CircularProgressIndicator(color: _terra));
            }
            final school = snap.data;
            final open = school?['preregistration_open'] == true;
            if (school == null || !open) {
              return _Unavailable(
                found: school != null,
                schoolName: school?['name'] as String?,
              );
            }

            final schoolId = school['id'] as String;
            final config = EnrollmentConfig(
              fields: EnrollmentConfig.defaults().fields,
              welcomeMessage:
                  'Pré-inscription en ligne à ${school['name']}. Des frais de '
                  'dossier peuvent être demandés (non remboursables). '
                  'L\'école étudiera votre dossier puis vous contactera pour '
                  'finaliser l\'inscription.',
            );
            return EnrollmentPage(
              config: config,
              isAdminMode: false,
              schoolId: schoolId,
              onSubmit: (data) async {
                final reference = await SupabaseDbSource.submitEnrollmentRequest(
                  schoolId: schoolId,
                  apiKey: school['enrollment_api_key'] as String,
                  payload: data,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                        'Numéro de suivi : $reference — gardez-le précieusement.'),
                    duration: const Duration(seconds: 10),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: _terra,
                  ));
                }
              },
            );
          },
        ),
      ),
    );
  }
}

/// École introuvable, ou qui n'accepte plus de nouvelles demandes.
class _Unavailable extends StatelessWidget {
  final bool found;
  final String? schoolName;
  const _Unavailable({required this.found, this.schoolName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(found ? Icons.lock_outline_rounded : Icons.search_off_rounded,
              size: 48, color: _muted),
          const SizedBox(height: 16),
          Text(
            found
                ? 'Pré-inscription fermée'
                : 'École introuvable',
            style: const TextStyle(
                fontSize: 18, color: _ink, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            found
                ? '${schoolName ?? 'Cette école'} n\'accepte plus de nouvelles '
                  'demandes de pré-inscription pour le moment.'
                : 'Vérifiez le lien ou le code fourni par l\'établissement.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: _muted, height: 1.5),
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () => context.go('/login'),
            child: const Text('Retour à la connexion',
                style: TextStyle(
                    color: _muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }
}

/// Écran d'entrée quand on arrive sans code d'école (ex. bouton « Nouvelle
/// inscription » de l'écran de connexion) : on demande le code de l'école.
class PreRegEntryScreen extends StatefulWidget {
  const PreRegEntryScreen({super.key});
  @override
  State<PreRegEntryScreen> createState() => _PreRegEntryScreenState();
}

class _PreRegEntryScreenState extends State<PreRegEntryScreen> {
  final _code = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _continue() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final code = _code.text.trim().toLowerCase();
    context.go('/inscription/$code');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // En-tête.
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [_terra, _orange],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.how_to_reg_rounded,
                      color: Colors.white, size: 30),
                ),
                const SizedBox(height: 16),
                const Text('Pré-inscription',
                    style: TextStyle(
                        fontSize: 22, color: _ink, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                const Text(
                  'Saisissez le code de votre école (fourni par l\'établissement '
                  'via son lien ou son QR code) pour commencer.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: _muted, height: 1.5),
                ),
                const SizedBox(height: 24),
                Form(
                  key: _formKey,
                  child: TextFormField(
                    controller: _code,
                    textInputAction: TextInputAction.go,
                    onFieldSubmitted: (_) => _continue(),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Entrez le code de l\'école'
                        : null,
                    style: const TextStyle(fontSize: 14, color: _ink),
                    decoration: InputDecoration(
                      hintText: 'ex. ead-brazzaville',
                      hintStyle: const TextStyle(fontSize: 13, color: _muted),
                      prefixIcon: const Icon(Icons.tag_rounded,
                          size: 18, color: _muted),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _terra, width: 1.6),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _terra),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: _continue,
                      child: Container(
                        height: 50,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [_terra, _orange],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text('Continuer',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Retour à la connexion',
                      style: TextStyle(
                          color: _muted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _gold.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _gold.withValues(alpha: .3)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.info_outline_rounded, size: 16, color: _gold),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pas de code ? Demandez son lien de pré-inscription à '
                        'votre école.',
                        style: TextStyle(fontSize: 11.5, color: _ink, height: 1.4),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
