import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/app_config.dart';
import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/data/enrollment_config.dart';
import '../../../../shared/widgets/page_scaffold.dart';
import '../../../enrollment/data/prereg_store.dart';

const _terra = Color(0xFF8B1A00);
const _green = Color(0xFF2D6A4F);

/// Panneau admin « Lien de pré-inscription » : lien public + QR + partage +
/// interrupteur d'ouverture de la période. C'est ce que l'école diffuse aux
/// familles (WhatsApp, affiche au portail, réseaux…).
class PreRegistrationLinkPanel extends ConsumerStatefulWidget {
  const PreRegistrationLinkPanel({super.key});
  @override
  ConsumerState<PreRegistrationLinkPanel> createState() =>
      _PreRegistrationLinkPanelState();
}

class _PreRegistrationLinkPanelState
    extends ConsumerState<PreRegistrationLinkPanel> {
  bool _keyVisible = false;
  bool _regenerating = false;

  void _copy(String text, [String label = 'Lien']) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$label copié.'),
      behavior: SnackBarBehavior.floating,
      backgroundColor: _green,
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _regenerateKey(String schoolId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Régénérer la clé API ?'),
        content: const Text(
            'L\'ancienne clé cessera de fonctionner immédiatement. Si le site '
            'de l\'école l\'utilise déjà, il faudra y reporter la nouvelle '
            'clé, sinon ses pré-inscriptions échoueront.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: _terra),
              child: const Text('Régénérer')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _regenerating = true);
    try {
      await SupabaseDbSource.regenerateEnrollmentApiKey(schoolId);
      ref.invalidate(schoolEnrollmentStatusProvider);
      setState(() => _keyVisible = true);
    } finally {
      if (mounted) setState(() => _regenerating = false);
    }
  }

  Future<void> _shareWhatsApp(String link) async {
    final text = Uri.encodeComponent(
        'Pré-inscription en ligne — inscrivez votre enfant ici : $link');
    final uri = Uri.parse('https://wa.me/?text=$text');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Impossible d\'ouvrir WhatsApp.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _terra,
        ));
      }
    }
  }

  void _showQr(String link, String schoolName) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: context.cCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(schoolName,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    color: context.cInk,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Scannez pour vous pré-inscrire',
                style: TextStyle(fontSize: 11.5, color: context.cMuted)),
            const SizedBox(height: 16),
            // Le QR reste sur fond blanc (lisibilité au scan), volontairement.
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.cBorder),
              ),
              child: QrImageView(
                data: link,
                size: 200,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square, color: _terra),
                dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF1A0A00)),
              ),
            ),
            const SizedBox(height: 14),
            ActionButton(
              label: 'Fermer',
              onTap: () => Navigator.pop(context),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _setOpen(String schoolId, bool value) async {
    await SupabaseDbSource.setSchoolPreregistrationOpen(schoolId, value);
    ref.invalidate(schoolEnrollmentStatusProvider);
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = ref.watch(currentSchoolIdProvider);
    final schoolAsync = ref.watch(schoolProvider);
    final schoolName = schoolAsync.asData?.value?.name ?? 'Votre école';
    final statusAsync = ref.watch(schoolEnrollmentStatusProvider);
    final status = statusAsync.asData?.value;
    final slug = status?['slug'] as String?;
    final open = status?['preregistration_open'] == true;
    final link = slug == null ? null : PreRegStore.linkFor(slug);
    final apiKey = status?['enrollment_api_key'] as String?;
    final configAsync = ref.watch(enrollmentConfigProvider);
    final config = EnrollmentConfig.fromJson(configAsync.asData?.value ?? const {});

    return DataPanel(
      title: 'Lien de pré-inscription',
      headerActions: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _terra.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(99),
          ),
          child: const Text('Offre Pro',
              style: TextStyle(
                  fontSize: 10, color: _terra, fontWeight: FontWeight.w700)),
        ),
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          'Partagez ce lien (ou le QR) aux familles : elles se pré-inscrivent '
          'en ligne, puis vous validez les demandes reçues.',
          style: TextStyle(fontSize: 11.5, color: context.cMuted, height: 1.4),
        ),
        const SizedBox(height: 12),

        // Interrupteur d'ouverture de la période.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: context.cSubtle,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.cBorder),
          ),
          child: Row(children: [
            Icon(open ? Icons.lock_open_rounded : Icons.lock_rounded,
                size: 16, color: open ? _green : context.cMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(open ? 'Période ouverte' : 'Période fermée',
                    style: TextStyle(
                        fontSize: 12.5,
                        color: context.cInk,
                        fontWeight: FontWeight.w700)),
                Text(
                    open
                        ? 'Le lien accepte de nouvelles demandes.'
                        : 'Le lien refuse les nouvelles demandes.',
                    style: TextStyle(fontSize: 10.5, color: context.cMuted)),
              ]),
            ),
            Switch(
              value: open,
              activeColor: _green,
              onChanged: (schoolId == null || link == null)
                  ? null
                  : (v) => _setOpen(schoolId, v),
            ),
          ]),
        ),
        const SizedBox(height: 12),

        if (link == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(
                child: SizedBox(
                    height: 18, width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))),
          )
        else ...[
          // Lien + copier.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: context.cSubtle,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.cBorder),
            ),
            child: Row(children: [
              Icon(Icons.link_rounded, size: 16, color: context.cMuted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(link,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12.5,
                        color: context.cInk,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              _IconChip(
                  icon: Icons.copy_rounded, tooltip: 'Copier',
                  onTap: () => _copy(link)),
            ]),
          ),
          const SizedBox(height: 12),

          // Actions : QR + partager.
          Wrap(spacing: 8, runSpacing: 8, children: [
            ActionButton(
              label: 'Afficher le QR',
              icon: Icons.qr_code_2_rounded,
              onTap: () => _showQr(link, schoolName),
            ),
            ActionButton(
              label: 'Partager (WhatsApp)',
              icon: Icons.share_rounded,
              primary: true,
              onTap: () => _shareWhatsApp(link),
            ),
          ]),
          const SizedBox(height: 18),
          Divider(color: context.cBorder),
          const SizedBox(height: 14),
          _ApiSection(
            schoolId: schoolId,
            apiKey: apiKey,
            keyVisible: _keyVisible,
            regenerating: _regenerating,
            config: config,
            onToggleVisible: () => setState(() => _keyVisible = !_keyVisible),
            onCopyKey: (k) => _copy(k, 'Clé API'),
            onRegenerate: schoolId == null ? null : () => _regenerateKey(schoolId),
          ),
        ],
      ]),
    );
  }
}

/// Le pendant « site web de l'école » du lien de pré-inscription : la clé
/// API propre à cette école, l'endpoint à appeler, et le contrat de champs
/// (dérivé de la MÊME config que le formulaire intégré — un champ que
/// l'admin désactive ici disparaît aussi de cet exemple).
class _ApiSection extends StatelessWidget {
  final String? schoolId;
  final String? apiKey;
  final bool keyVisible;
  final bool regenerating;
  final EnrollmentConfig config;
  final VoidCallback onToggleVisible;
  final ValueChanged<String> onCopyKey;
  final VoidCallback? onRegenerate;

  const _ApiSection({
    required this.schoolId,
    required this.apiKey,
    required this.keyVisible,
    required this.regenerating,
    required this.config,
    required this.onToggleVisible,
    required this.onCopyKey,
    required this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    final fields = config.enabledFields;
    const endpoint = '${AppConfig.supabaseUrl}/rest/v1/enrollment_requests';
    final sampleFields = {
      for (final f in fields)
        f.id: f.type == FieldType.select && f.options.isNotEmpty
            ? f.options.first
            : '...',
    };
    final snippet = 'curl -X POST \'$endpoint\' \\\n'
        '  -H "apikey: ${AppConfig.supabaseAnonKey}" \\\n'
        '  -H "content-type: application/json" \\\n'
        "  -d '{\n"
        '    "school_id": "${schoolId ?? '<school_id>'}",\n'
        '    "api_key": "${apiKey ?? '<clé API>'}",\n'
        '    "payload": ${_prettyJson(sampleFields)}\n'
        "  }'";

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.api_rounded, size: 16, color: context.cMuted),
        const SizedBox(width: 8),
        Text('API pour le site de l\'école',
            style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w800, color: context.cInk)),
      ]),
      const SizedBox(height: 4),
      Text(
          'Pour recevoir les pré-inscriptions depuis un site qui n\'est pas '
          'fait avec Scolaris (WordPress, site vitrine…) : un simple appel '
          'HTTP vers l\'adresse ci-dessous, avec cette clé.',
          style: TextStyle(fontSize: 11.5, color: context.cMuted, height: 1.4)),
      const SizedBox(height: 12),

      // ── Clé API ──────────────────────────────────────────────────────────
      if (apiKey == null)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Center(
              child: SizedBox(
                  height: 18, width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))),
        )
      else ...[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: context.cSubtle,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.cBorder),
          ),
          child: Row(children: [
            Icon(Icons.vpn_key_rounded, size: 16, color: context.cMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                  keyVisible ? apiKey! : '•' * 20,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontFamily: 'monospace',
                      color: context.cInk,
                      fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 6),
            _IconChip(
                icon: keyVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                tooltip: keyVisible ? 'Masquer' : 'Afficher',
                onTap: onToggleVisible),
            const SizedBox(width: 6),
            _IconChip(
                icon: Icons.copy_rounded, tooltip: 'Copier',
                onTap: () => onCopyKey(apiKey!)),
          ]),
        ),
        const SizedBox(height: 10),
        ActionButton(
          label: regenerating ? 'Régénération…' : 'Régénérer la clé',
          icon: Icons.refresh_rounded,
          onTap: regenerating ? null : onRegenerate,
        ),
        const SizedBox(height: 14),

        // ── Champs attendus ──────────────────────────────────────────────
        Text('Champs (selon votre configuration actuelle du formulaire)',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: context.cMuted)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final f in fields)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: config.isRequired(f.id)
                    ? _terra.withValues(alpha: .08)
                    : context.cSubtle,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: config.isRequired(f.id)
                        ? _terra.withValues(alpha: .3)
                        : context.cBorder),
              ),
              child: Text(
                  config.isRequired(f.id) ? '${f.id} *' : f.id,
                  style: TextStyle(
                      fontSize: 10.5,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                      color: config.isRequired(f.id) ? _terra : context.cMuted)),
            ),
        ]),
        const SizedBox(height: 4),
        Text('* obligatoire — l\'envoi est refusé si absent.',
            style: TextStyle(fontSize: 10.5, color: context.cMuted)),
        const SizedBox(height: 14),

        // ── Exemple d'appel ──────────────────────────────────────────────
        Text('Exemple d\'appel',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: context.cMuted)),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.cInk.withValues(alpha: .04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.cBorder),
          ),
          child: SelectableText(snippet,
              style: TextStyle(
                  fontSize: 11, fontFamily: 'monospace', color: context.cInk, height: 1.5)),
        ),
        const SizedBox(height: 6),
        Text(
            'La réponse indique clairement le champ manquant ou une clé '
            'invalide plutôt qu\'une erreur générique — le site de l\'école '
            'peut afficher ce message à son visiteur.',
            style: TextStyle(fontSize: 10.5, color: context.cMuted, height: 1.4)),
      ],
    ]);
  }

  static String _prettyJson(Map<String, String> fields) {
    final buf = StringBuffer('{\n');
    final entries = fields.entries.toList();
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      buf.write('      "${e.key}": "${e.value}"');
      buf.writeln(i == entries.length - 1 ? '' : ',');
    }
    buf.write('    }');
    return buf.toString();
  }
}

class _IconChip extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _IconChip(
      {required this.icon, required this.tooltip, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.cCard,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.cBorder),
            ),
            child: Icon(icon, size: 15, color: context.cMuted),
          ),
        ),
      ),
    );
  }
}
