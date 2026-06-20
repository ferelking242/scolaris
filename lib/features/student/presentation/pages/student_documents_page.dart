import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/auth_providers.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/data/features_catalog.dart';
import '../../../../shared/widgets/plan_gate.dart';
import 'bulletin_page.dart';

const _terra  = ScolarisPalette.terracotta;
const _gold   = ScolarisPalette.gold;
const _green  = ScolarisPalette.forestGreen;
const _ink    = Color(0xFF1A0A00);
const _muted  = Color(0xFF7A5C44);
const _white  = Colors.white;
const _bg     = Color(0xFFEDD8BE);

enum DocType { certificat, bulletin, recu, attestation }
enum DocStatus { available, onRequest }

class _Document {
  final String titre, description;
  final String? date;
  final DocType type;
  final DocStatus status;
  final VoidCallback? onTap;
  const _Document({
    required this.titre, required this.description,
    this.date, required this.type, required this.status, this.onTap,
  });
}

class StudentDocumentsPage extends ConsumerWidget {
  const StudentDocumentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user        = ref.watch(authSessionProvider);
    final level       = ref.watch(studentSchoolLevelProvider).valueOrNull
        ?? SchoolLevel.lycee;
    final invoicesAsync = ref.watch(myInvoicesProvider);
    final hasBulletin = level == SchoolLevel.college || level == SchoolLevel.lycee;

    return Container(
      color: _bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
        child: PlanGate(
          minPlan: 'pro',
          featureLabel: 'Documents officiels',
          description: 'Certificats, attestations et reçus en un clic.',
          icon: Icons.folder_rounded,
          child: _Body(
            name: user?.fullName ?? 'Étudiant',
            hasBulletin: hasBulletin,
            paidInvoices: invoicesAsync.valueOrNull
                    ?.where((i) => i.status.toLowerCase() == 'paid')
                    .toList() ??
                const [],
            loadingReceipts: invoicesAsync.isLoading,
            onOpenBulletin: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BulletinPage())),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final String name;
  final bool hasBulletin;
  final List<SbInvoice> paidInvoices;
  final bool loadingReceipts;
  final VoidCallback onOpenBulletin;
  const _Body({
    required this.name,
    required this.hasBulletin,
    required this.paidInvoices,
    required this.loadingReceipts,
    required this.onOpenBulletin,
  });

  @override
  Widget build(BuildContext context) {
    // Documents officiels — délivrés sur demande (pas de fausse disponibilité).
    final official = <_Document>[
      const _Document(
        titre: 'Certificat de scolarité',
        description: 'Délivré par le secrétariat',
        type: DocType.certificat,
        status: DocStatus.onRequest,
      ),
      const _Document(
        titre: 'Attestation de scolarité',
        description: 'Sur demande au secrétariat',
        type: DocType.attestation,
        status: DocStatus.onRequest,
      ),
    ];

    // Reçus — dérivés des factures réellement payées.
    final receipts = paidInvoices.map((inv) => _Document(
          titre: 'Reçu — ${inv.description ?? inv.invoiceNumber ?? 'Paiement'}',
          description: '${_fmtMoney(inv.amount)} ${inv.currency}',
          date: _fmtDate(inv.dueDate),
          type: DocType.recu,
          status: DocStatus.available,
          onTap: () => _toast(context, 'Téléchargement du reçu…'),
        )).toList();

    final availableCount = receipts.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProfileHeader(name: name, availableCount: availableCount),
        const SizedBox(height: 24),

        _CategorySection(label: 'Certificats & Attestations', docs: official),
        const SizedBox(height: 20),

        if (hasBulletin) ...[
          _CategorySection(label: 'Bulletins scolaires', docs: [
            _Document(
              titre: 'Mes bulletins',
              description: 'Consulter et télécharger',
              type: DocType.bulletin,
              status: DocStatus.available,
              onTap: onOpenBulletin,
            ),
          ]),
          const SizedBox(height: 20),
        ],

        Row(children: [
          Container(width: 8, height: 8,
              decoration: const BoxDecoration(color: _gold, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          const Text('REÇUS DE PAIEMENT', style: TextStyle(
              color: _gold, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .5)),
        ]),
        const SizedBox(height: 8),
        if (loadingReceipts)
          const Padding(padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()))
        else if (receipts.isEmpty)
          _EmptyReceipts()
        else
          ...receipts.map((doc) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _DocCard(doc: doc),
              )),
        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _gold.withValues(alpha: .25)),
          ),
          child: Row(children: const [
            Icon(Icons.tips_and_updates_rounded, color: _gold, size: 18),
            SizedBox(width: 10),
            Expanded(child: Text(
              'Contactez le secrétariat pour demander un nouveau document ou pour toute rectification.',
              style: TextStyle(color: _muted, fontSize: 12, height: 1.5),
            )),
          ]),
        ),
      ],
    );
  }
}

void _toast(BuildContext context, String msg) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: _terra,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));

String _fmtMoney(double n) {
  final s = n.round().toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return buf.toString();
}

String _fmtDate(DateTime? d) {
  if (d == null) return '';
  const mois = [
    'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
    'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'
  ];
  return '${d.day} ${mois[d.month - 1]} ${d.year}';
}

// ── Profile Header ────────────────────────────────────────────────────────
class _ProfileHeader extends StatelessWidget {
  final String name;
  final int availableCount;
  const _ProfileHeader({required this.name, required this.availableCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A0500), Color(0xFF3E1A00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(children: [
        Container(
          width: 50, height: 50,
          decoration: BoxDecoration(
            color: _white.withValues(alpha: .12), shape: BoxShape.circle,
            border: Border.all(color: _gold.withValues(alpha: .4), width: 2),
          ),
          child: const Center(child: Icon(Icons.folder_rounded, color: _gold, size: 24)),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Mes Documents', style: TextStyle(
              color: _white, fontSize: 16, fontWeight: FontWeight.w800)),
          Text(name, style: TextStyle(color: _white.withValues(alpha: .65), fontSize: 12)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _gold.withValues(alpha: .3)),
          ),
          child: Text('$availableCount reçu(s)',
              style: const TextStyle(color: _gold, fontSize: 10, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

// ── Category Section ──────────────────────────────────────────────────────
class _CategorySection extends StatelessWidget {
  final String label;
  final List<_Document> docs;
  const _CategorySection({required this.label, required this.docs});

  Color get _catColor {
    if (label.contains('Certificat')) return _green;
    if (label.contains('Bulletin')) return _terra;
    if (label.contains('Reçu')) return _gold;
    return const Color(0xFF7C3AED);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: _catColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label.toUpperCase(), style: TextStyle(
              color: _catColor, fontSize: 12, fontWeight: FontWeight.w800,
              letterSpacing: .5)),
        ]),
        const SizedBox(height: 8),
        ...docs.map((doc) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _DocCard(doc: doc),
        )),
      ],
    );
  }
}

// ── Doc Card ──────────────────────────────────────────────────────────────
class _DocCard extends StatelessWidget {
  final _Document doc;
  const _DocCard({required this.doc});

  IconData get _icon {
    switch (doc.type) {
      case DocType.certificat:  return Icons.verified_outlined;
      case DocType.bulletin:    return Icons.grade_outlined;
      case DocType.recu:        return Icons.receipt_outlined;
      case DocType.attestation: return Icons.assignment_outlined;
    }
  }

  Color get _color {
    switch (doc.type) {
      case DocType.certificat:  return _green;
      case DocType.bulletin:    return _terra;
      case DocType.recu:        return _gold;
      case DocType.attestation: return const Color(0xFF7C3AED);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRequest = doc.status == DocStatus.onRequest;
    return GestureDetector(
      onTap: doc.onTap ??
          (isRequest ? () => _toast(context, 'Demande envoyée au secrétariat.') : null),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _color.withValues(alpha: .15)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .03), blurRadius: 6)],
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: _color.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Icon(_icon, color: _color, size: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(doc.titre, style: const TextStyle(
                color: _ink, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(doc.description, style: const TextStyle(color: _muted, fontSize: 11)),
            if (doc.date != null && doc.date!.isNotEmpty)
              Text(doc.date!, style: TextStyle(
                  color: _muted.withValues(alpha: .6), fontSize: 10)),
          ])),
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _color.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
                isRequest ? Icons.send_rounded
                : doc.type == DocType.bulletin ? Icons.chevron_right_rounded
                : Icons.download_rounded,
                color: _color, size: 18),
          ),
        ]),
      ),
    );
  }
}

class _EmptyReceipts extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEEE5D8)),
        ),
        child: const Column(children: [
          Icon(Icons.receipt_long_outlined, color: _muted, size: 32),
          SizedBox(height: 8),
          Text('Aucun reçu pour le moment',
              style: TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w700)),
          SizedBox(height: 2),
          Text('Tes reçus apparaîtront ici après chaque paiement.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 11.5)),
        ]),
      );
}
