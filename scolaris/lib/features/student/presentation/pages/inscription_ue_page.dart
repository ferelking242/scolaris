import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/page_scaffold.dart';

const _terra  = ScolarisPalette.terracotta;
const _gold   = ScolarisPalette.gold;
const _green  = ScolarisPalette.forestGreen;
const _ink    = Color(0xFF1A0A00);
const _muted  = Color(0xFF7A5C44);
const _border = Color(0xFFDDCCBB);
const _white  = Colors.white;

class _ModuleDisponible {
  final String code;
  final String nom;
  final String prof;
  final int credits;
  final String horaire;
  final String salle;
  final String type; // 'obligatoire' | 'optionnel'
  final int places;
  final int inscrits;
  bool selectionne;

  _ModuleDisponible({
    required this.code, required this.nom, required this.prof,
    required this.credits, required this.horaire, required this.salle,
    required this.type, required this.places, required this.inscrits,
    this.selectionne = false,
  });

  bool get complet => inscrits >= places;
  double get remplissage => inscrits / places;
}

class InscriptionUEPage extends StatefulWidget {
  const InscriptionUEPage({super.key});
  @override
  State<InscriptionUEPage> createState() => _InscriptionUEPageState();
}

class _InscriptionUEPageState extends State<InscriptionUEPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  bool _inscriptionSoumise = false;

  final _modules = [
    // Obligatoires S3
    _ModuleDisponible(code: 'RES301', nom: 'Réseaux et systèmes', prof: 'M. Kinsounda',
        credits: 6, horaire: 'Lun/Mer 08h-10h', salle: 'Amphi A', type: 'obligatoire',
        places: 120, inscrits: 98, selectionne: true),
    _ModuleDisponible(code: 'WEB301', nom: 'Développement web avancé', prof: 'Mme Okoko',
        credits: 5, horaire: 'Mar/Jeu 10h-12h', salle: 'Labo Info', type: 'obligatoire',
        places: 60, inscrits: 55, selectionne: true),
    _ModuleDisponible(code: 'MAT301', nom: 'Mathématiques discrètes', prof: 'M. Ngoma',
        credits: 5, horaire: 'Lun/Ven 10h-12h', salle: 'Salle B2', type: 'obligatoire',
        places: 100, inscrits: 87, selectionne: true),
    // Optionnels
    _ModuleDisponible(code: 'IA301', nom: 'Introduction à l\'IA', prof: 'Dr. Mavoungou',
        credits: 3, horaire: 'Mer 14h-17h', salle: 'Amphi C', type: 'optionnel',
        places: 80, inscrits: 78),
    _ModuleDisponible(code: 'MOB301', nom: 'Développement mobile', prof: 'M. Biyela',
        credits: 3, horaire: 'Jeu 14h-17h', salle: 'Labo Info 2', type: 'optionnel',
        places: 40, inscrits: 38),
    _ModuleDisponible(code: 'SEC301', nom: 'Cybersécurité', prof: 'Mme Ntoko',
        credits: 3, horaire: 'Ven 08h-11h', salle: 'Salle A4', type: 'optionnel',
        places: 50, inscrits: 22),
    _ModuleDisponible(code: 'PRJ301', nom: 'Projet tutoré', prof: 'Tuteur assigné',
        credits: 4, horaire: 'Ven 14h-18h', salle: 'À définir', type: 'optionnel',
        places: 200, inscrits: 145),
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() {}));
  }
  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  List<_ModuleDisponible> get _obligatoires => _modules.where((m) => m.type == 'obligatoire').toList();
  List<_ModuleDisponible> get _optionnels => _modules.where((m) => m.type == 'optionnel').toList();
  int get _totalCredits => _modules.where((m) => m.selectionne).fold(0, (s, m) => s + m.credits);

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Inscription aux UE',
      subtitle: 'Semestre 3 — 2025-2026',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Banner statut ───────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _inscriptionSoumise
                  ? [const Color(0xFF0A3D1A), _green]
                  : [const Color(0xFF1A0A00), _terra],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: _white.withOpacity(.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _inscriptionSoumise ? Icons.check_circle_rounded : Icons.edit_calendar_rounded,
                color: _white, size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                _inscriptionSoumise ? 'Inscription confirmée !' : 'Inscription en cours',
                style: const TextStyle(color: _white, fontSize: 14, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                _inscriptionSoumise
                    ? '$_totalCredits ECTS — Validation définitive sous 48h'
                    : '$_totalCredits ECTS sélectionnés · Date limite : 15 Juil',
                style: TextStyle(color: _white.withOpacity(.75), fontSize: 11),
              ),
            ])),
            if (!_inscriptionSoumise)
              GestureDetector(
                onTap: () => _showConfirmation(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('Valider',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _terra)),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 14),

        // ── Tabs ─────────────────────────────────────────────────────────────
        Container(
          height: 42,
          decoration: BoxDecoration(
            color: _border.withOpacity(.3),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(4),
          child: TabBar(
            controller: _tab,
            indicator: BoxDecoration(
              color: _white,
              borderRadius: BorderRadius.circular(9),
              boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 4)],
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: _terra,
            unselectedLabelColor: _muted,
            labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            unselectedLabelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
            tabs: [
              Tab(text: 'Obligatoires (${_obligatoires.length})'),
              Tab(text: 'Optionnels (${_optionnels.length})'),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── Liste modules ────────────────────────────────────────────────────
        ...(_tab.index == 0 ? _obligatoires : _optionnels).map((m) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ModuleCard(
            module: m,
            locked: m.type == 'obligatoire',
            onToggle: (v) => setState(() => m.selectionne = v),
          ),
        )),
      ]),
    );
  }

  void _showConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Confirmer l\'inscription ?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
        content: Text(
          '$_totalCredits ECTS sélectionnés. Cette action sera transmise au service de scolarité pour validation.',
          style: const TextStyle(fontSize: 13, color: _muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: _muted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _terra,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
              setState(() => _inscriptionSoumise = true);
            },
            child: const Text('Confirmer', style: TextStyle(color: _white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ── Carte module ──────────────────────────────────────────────────────────────
class _ModuleCard extends StatelessWidget {
  final _ModuleDisponible module;
  final bool locked;
  final ValueChanged<bool> onToggle;
  const _ModuleCard({required this.module, required this.locked, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final sel = module.selectionne;
    final complet = module.complet && !sel;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: sel ? _terra.withOpacity(.04) : _white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: sel ? _terra.withOpacity(.4) : _border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: const Color(0xFFF5EEE6), borderRadius: BorderRadius.circular(4)),
                child: Text(module.code, style: const TextStyle(
                    fontSize: 9.5, fontWeight: FontWeight.w700, color: _muted)),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: _gold.withOpacity(.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('${module.credits} ECTS', style: const TextStyle(
                    fontSize: 9.5, fontWeight: FontWeight.w700, color: _gold)),
              ),
              if (module.type == 'obligatoire') ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: _green.withOpacity(.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('Obligatoire', style: TextStyle(
                      fontSize: 9.5, fontWeight: FontWeight.w700, color: _green)),
                ),
              ],
            ]),
            const SizedBox(height: 6),
            Text(module.nom, style: const TextStyle(
                fontSize: 13.5, fontWeight: FontWeight.w800, color: _ink)),
            const SizedBox(height: 3),
            Row(children: [
              Icon(Icons.person_outline_rounded, size: 11, color: _muted),
              const SizedBox(width: 3),
              Text(module.prof, style: const TextStyle(fontSize: 11, color: _muted)),
            ]),
          ])),
          const SizedBox(width: 8),
          // Toggle
          if (!locked)
            Switch(
              value: sel,
              onChanged: complet ? null : onToggle,
              activeColor: _terra,
              trackColor: WidgetStateProperty.resolveWith((s) =>
                s.contains(WidgetState.selected) ? _terra.withOpacity(.25) : _border),
            )
          else
            Icon(Icons.lock_rounded, size: 18, color: _muted.withOpacity(.5)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Icon(Icons.access_time_rounded, size: 11, color: _muted),
          const SizedBox(width: 4),
          Text(module.horaire, style: const TextStyle(fontSize: 11, color: _muted)),
          const SizedBox(width: 10),
          Icon(Icons.room_rounded, size: 11, color: _muted),
          const SizedBox(width: 4),
          Text(module.salle, style: const TextStyle(fontSize: 11, color: _muted)),
          const Spacer(),
          Text('${module.inscrits}/${module.places}',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: module.remplissage > 0.85 ? _terra : _muted)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: module.remplissage,
            backgroundColor: _border.withOpacity(.4),
            valueColor: AlwaysStoppedAnimation(
                module.remplissage > 0.85 ? _terra : _green),
            minHeight: 4,
          ),
        ),
      ]),
    );
  }
}
