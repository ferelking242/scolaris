import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../presentation/providers/auth_providers.dart';

const _terra  = ScolarisPalette.terracotta;
const _orange = ScolarisPalette.orange;
const _gold   = ScolarisPalette.gold;
const _green  = ScolarisPalette.forestGreen;
const _ink    = Color(0xFF1A0A00);
const _muted  = Color(0xFF7A5C44);
const _white  = Colors.white;
const _bg     = Color(0xFFEDD8BE);

class StudentDocumentsPage extends ConsumerWidget {
  const StudentDocumentsPage({super.key});

  static const _documents = [
    _Document(
      titre: 'Certificat de scolarité',
      description: 'Année académique 2025-2026',
      type: DocType.certificat,
      date: '01 Sep 2025',
      disponible: true,
    ),
    _Document(
      titre: 'Bulletin du 1er Trimestre',
      description: 'Trimestre 1 — Terminale A',
      type: DocType.bulletin,
      date: '20 Déc 2025',
      disponible: true,
    ),
    _Document(
      titre: 'Bulletin du 2ème Trimestre',
      description: 'Trimestre 2 — Terminale A',
      type: DocType.bulletin,
      date: '14 Avr 2026',
      disponible: true,
    ),
    _Document(
      titre: 'Attestation de résultats',
      description: 'Examens blancs — Mars 2026',
      type: DocType.attestation,
      date: '01 Mar 2026',
      disponible: false,
    ),
    _Document(
      titre: 'Reçu de scolarité — Tranche 1',
      description: 'Paiement du 15 Sep 2025',
      type: DocType.recu,
      date: '15 Sep 2025',
      disponible: true,
    ),
    _Document(
      titre: 'Reçu de scolarité — Tranche 2',
      description: 'Paiement du 12 Jan 2026',
      type: DocType.recu,
      date: '12 Jan 2026',
      disponible: true,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authSessionProvider);

    final categories = {
      DocType.certificat:  'Certificats & Attestations',
      DocType.bulletin:    'Bulletins scolaires',
      DocType.recu:        'Reçus de paiement',
      DocType.attestation: 'Attestations diverses',
    };

    final grouped = <DocType, List<_Document>>{};
    for (final d in _documents) {
      grouped.putIfAbsent(d.type, () => []).add(d);
    }

    return Container(
      color: _bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── En-tête profil ────────────────────────────────────────
            _ProfileHeader(name: user?.fullName ?? 'Étudiant'),
            const SizedBox(height: 24),

            // ── Catégories ────────────────────────────────────────────
            for (final entry in grouped.entries) ...[
              _CategorySection(
                label: categories[entry.key] ?? entry.key.name,
                docs: entry.value,
              ),
              const SizedBox(height: 20),
            ],

            // ── Note bas de page ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _gold.withOpacity(.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _gold.withOpacity(.25)),
              ),
              child: Row(children: [
                Icon(Icons.tips_and_updates_rounded, color: _gold, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  'Contactez le secrétariat pour demander de nouveaux documents ou pour toute rectification.',
                  style: TextStyle(color: _muted, fontSize: 12, height: 1.5),
                )),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Enums & Data ──────────────────────────────────────────────────────────
enum DocType { certificat, bulletin, recu, attestation }

class _Document {
  final String titre, description, date;
  final DocType type;
  final bool disponible;
  const _Document({
    required this.titre, required this.description,
    required this.date, required this.type, required this.disponible,
  });
}

// ── Profile Header ────────────────────────────────────────────────────────
class _ProfileHeader extends StatelessWidget {
  final String name;
  const _ProfileHeader({required this.name});

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
            color: _white.withOpacity(.12), shape: BoxShape.circle,
            border: Border.all(color: _gold.withOpacity(.4), width: 2),
          ),
          child: const Center(child: Icon(Icons.folder_rounded, color: _gold, size: 24)),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Mes Documents', style: TextStyle(
              color: _white, fontSize: 16, fontWeight: FontWeight.w800)),
          Text(name, style: TextStyle(color: _white.withOpacity(.65), fontSize: 12)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _gold.withOpacity(.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _gold.withOpacity(.3)),
          ),
          child: Text('${StudentDocumentsPage._documents.where((d) => d.disponible).length} disponibles',
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
          Text(label, style: TextStyle(
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: doc.disponible
            ? _color.withOpacity(.15)
            : const Color(0xFFEEE5D8)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.03), blurRadius: 6)],
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: doc.disponible
                ? _color.withOpacity(.1)
                : const Color(0xFFF5EEE6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(child: Icon(_icon,
              color: doc.disponible ? _color : _muted.withOpacity(.5), size: 20)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(doc.titre, style: TextStyle(
              color: doc.disponible ? _ink : _muted,
              fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(doc.description, style: TextStyle(color: _muted, fontSize: 11)),
          Text(doc.date, style: TextStyle(
              color: _muted.withOpacity(.6), fontSize: 10)),
        ])),
        if (doc.disponible)
          GestureDetector(
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Téléchargement de "${doc.titre}"…'),
                backgroundColor: _terra,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: _color.withOpacity(.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.download_rounded, color: _color, size: 18),
            ),
          )
        else
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF5EEE6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.lock_outline_rounded, color: _muted.withOpacity(.4), size: 18),
          ),
      ]),
    );
  }
}
