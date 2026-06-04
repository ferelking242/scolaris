import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _terra  = Color(0xFF8B1A00);
const _orange = Color(0xFFD4540A);
const _gold   = Color(0xFFC17F24);
const _green  = Color(0xFF1B5E20);
const _cream  = Color(0xFFFDF6EE);
const _white  = Color(0xFFFFFFFF);
const _ink    = Color(0xFF1A0A00);
const _muted  = Color(0xFF8A7060);
const _border = Color(0xFFE8DDD4);
const _red    = Color(0xFFDC2626);
const _subtle = Color(0xFFF5EDE4);

// ── School types ──────────────────────────────────────────────────────────────
class _SchoolTypeInfo {
  final String id, label, sub, emoji;
  final IconData icon;
  const _SchoolTypeInfo(this.id, this.label, this.sub, this.emoji, this.icon);
}

const _kSchoolTypes = [
  _SchoolTypeInfo('garderie',   'Garderie',        '0-6 ans',         '👶', Icons.child_care_outlined),
  _SchoolTypeInfo('primaire',   'Primaire',         'CP → CM2',        '📖', Icons.menu_book_outlined),
  _SchoolTypeInfo('college',    'Collège',          '6e → 3e',         '🏫', Icons.school_outlined),
  _SchoolTypeInfo('lycee',      'Lycée',            '2nde → Terminale','🎓', Icons.account_balance_outlined),
  _SchoolTypeInfo('universite', 'Université',       'Licence→Doctorat','🏛️', Icons.corporate_fare_outlined),
  _SchoolTypeInfo('technique',  'Formation Pro.',   'CAP, BEP, BTS…',  '⚙️', Icons.engineering_outlined),
  _SchoolTypeInfo('superieur',  'Grandes Écoles',   'CPGE, Écoles…',   '🔬', Icons.science_outlined),
  _SchoolTypeInfo('special',    'Éducation Spéc.',  'Besoins spéciaux','♿', Icons.accessibility_new_outlined),
];

// ── Dial codes ────────────────────────────────────────────────────────────────
class _DialCode {
  final String flag, code, country;
  const _DialCode(this.flag, this.code, this.country);
}

const _kDialCodes = [
  _DialCode('🇨🇬', '+242', 'Congo'), _DialCode('🇨🇩', '+243', 'RDC'),
  _DialCode('🇨🇲', '+237', 'Cameroun'), _DialCode('🇸🇳', '+221', 'Sénégal'),
  _DialCode('🇨🇮', '+225', 'Côte d\'Ivoire'), _DialCode('🇬🇦', '+241', 'Gabon'),
  _DialCode('🇧🇯', '+229', 'Bénin'), _DialCode('🇧🇫', '+226', 'Burkina Faso'),
  _DialCode('🇲🇱', '+223', 'Mali'), _DialCode('🇬🇳', '+224', 'Guinée'),
  _DialCode('🇹🇬', '+228', 'Togo'), _DialCode('🇳🇪', '+227', 'Niger'),
  _DialCode('🇲🇬', '+261', 'Madagascar'), _DialCode('🇧🇮', '+257', 'Burundi'),
  _DialCode('🇷🇼', '+250', 'Rwanda'), _DialCode('🇩🇿', '+213', 'Algérie'),
  _DialCode('🇲🇦', '+212', 'Maroc'), _DialCode('🇹🇳', '+216', 'Tunisie'),
  _DialCode('🇳🇬', '+234', 'Nigeria'), _DialCode('🇬🇭', '+233', 'Ghana'),
  _DialCode('🇰🇪', '+254', 'Kenya'), _DialCode('🇹🇿', '+255', 'Tanzanie'),
  _DialCode('🇫🇷', '+33', 'France'), _DialCode('🇧🇪', '+32', 'Belgique'),
  _DialCode('🇨🇭', '+41', 'Suisse'), _DialCode('🇺🇸', '+1', 'USA'),
  _DialCode('🇬🇧', '+44', 'Royaume-Uni'),
];

// ── Education systems ─────────────────────────────────────────────────────────
class _SysInfo {
  final String id, title, flag, origin, countries, language;
  final List<String> structure, diplomas;
  final List<String> compatibleTypes; // school type ids
  const _SysInfo({
    required this.id, required this.title, required this.flag,
    required this.origin, required this.countries, required this.language,
    required this.structure, required this.diplomas, required this.compatibleTypes,
  });
}

const _kSystems = [
  _SysInfo(
    id: 'francophone', title: 'Francophone', flag: '🇫🇷',
    origin: 'Héritage du système éducatif français, adapté par les pays d\'Afrique francophone depuis l\'indépendance.',
    countries: 'Congo, Cameroun, Côte d\'Ivoire, Sénégal, Gabon, RDC, Madagascar, Mali, Burkina Faso, Bénin, Togo, Niger, Guinée…',
    language: 'Français',
    structure: [
      'Garderie / Maternelle (3 ans): PS → MS → GS',
      'Primaire (6 ans): CP → CE1 → CE2 → CM1 → CM2',
      'Collège (4 ans): 6e → 5e → 4e → 3e',
      'Lycée (3 ans): 2nde → 1re → Terminale',
      'Université: Classique ou LMD',
    ],
    diplomas: ['CEPD (Fin Primaire)', 'BEPC (Fin Collège)', 'BAC : A, C, D, F, G, TI…'],
    compatibleTypes: ['garderie','primaire','college','lycee','superieur'],
  ),
  _SysInfo(
    id: 'anglophone', title: 'Anglophone', flag: '🇬🇧',
    origin: 'Héritage du système britannique, adopté par les pays anglophones et certaines régions bilingues.',
    countries: 'Nigeria, Ghana, Kenya, Tanzanie, Cameroun (NW/SW), Ouganda, Zimbabwe…',
    language: 'Anglais',
    structure: [
      'Nursery / Kindergarten (2-3 ans)',
      'Primary (6 ans): Primary 1 → 6',
      'Junior Secondary (3 ans): JSS 1 → 3',
      'Senior Secondary (3 ans): SSS 1 → 3',
      'University: Bachelor → Master → PhD',
    ],
    diplomas: ['FSLC (Primaire)', 'BECE/JSCE (Collège)', 'GCE O-Level, A-Level, WAEC, NECO'],
    compatibleTypes: ['garderie','primaire','college','lycee','superieur'],
  ),
  _SysInfo(
    id: 'lmd', title: 'Système LMD', flag: '🎓',
    origin: 'Processus de Bologne (Europe, 1999). Adopté progressivement par les universités africaines pour harmoniser les diplômes.',
    countries: 'Europe + Maroc, Algérie, Tunisie, Sénégal, Cameroun, Congo, RDC…',
    language: 'Français ou Anglais',
    structure: [
      'Licence (3 ans): L1 → L2 → L3 (Bac+3)',
      'Master (2 ans): M1 → M2 (Bac+5)',
      'Doctorat (3 ans min): D1 → D2 → D3 (Bac+8)',
    ],
    diplomas: ['Licence (Bac+3)', 'Master Recherche / Pro (Bac+5)', 'Doctorat / PhD (Bac+8)'],
    compatibleTypes: ['universite','superieur'],
  ),
  _SysInfo(
    id: 'technique', title: 'Technique / Professionnel', flag: '⚙️',
    origin: 'Formation professionnelle orientée métier, reconnue internationalement. Axée sur l\'insertion directe dans le monde du travail.',
    countries: 'International — adapté localement dans chaque pays',
    language: 'Français ou Anglais',
    structure: [
      'CAP (2 ans): CAP 1 → CAP 2',
      'BEP (2 ans): BEP 1 → BEP 2',
      'BTS (2 ans): BTS 1 → BTS 2',
      'Licence Professionnelle (1 an après BTS)',
    ],
    diplomas: ['CAP', 'BEP', 'BTI', 'BTS', 'Licence Professionnelle'],
    compatibleTypes: ['lycee','technique','superieur'],
  ),
  _SysInfo(
    id: 'autre', title: 'Personnalisé', flag: '✨',
    origin: 'Système éducatif sur-mesure ou spécifique à votre contexte. Notre équipe vous accompagnera pour la configuration.',
    countries: 'Tout pays — configuration personnalisée',
    language: 'Au choix',
    structure: ['Structure 100% personnalisable selon vos besoins'],
    diplomas: ['Diplômes locaux ou reconnus par votre institution'],
    compatibleTypes: ['garderie','primaire','college','lycee','universite','technique','superieur','special'],
  ),
];

// ── Data models ───────────────────────────────────────────────────────────────
class SchoolBranch {
  String name;
  String countryFlag;
  String dialCode;
  String phone;
  String country;
  String city;
  String address;
  String googleMapsLink;

  SchoolBranch({
    this.name = '',
    this.countryFlag = '🇨🇬',
    this.dialCode = '+242',
    this.phone = '',
    this.country = '',
    this.city = '',
    this.address = '',
    this.googleMapsLink = '',
  });
}

class SchoolSeries {
  String name;
  String code;
  String description;
  bool isActive;
  List<String> classes;

  SchoolSeries({
    required this.name,
    required this.code,
    this.description = '',
    this.isActive = true,
    List<String>? classes,
  }) : classes = classes ?? [];
}

// ── Default series by system + types ─────────────────────────────────────────
List<SchoolSeries> _defaultSeries(String system, Set<String> types) {
  final hasPrimaire = types.contains('primaire') || types.contains('garderie');
  final hasCollege  = types.contains('college');
  final hasLycee    = types.contains('lycee');
  final hasUniv     = types.contains('universite') || types.contains('superieur');
  final hasTech     = types.contains('technique');

  final list = <SchoolSeries>[];

  if (system == 'francophone') {
    if (hasPrimaire) {
      list.addAll([
        SchoolSeries(name: 'Maternelle', code: 'MAT', description: 'PS, MS, GS',
            classes: ['PS', 'MS', 'GS']),
        SchoolSeries(name: 'Primaire', code: 'PRI', description: 'CP à CM2',
            classes: ['CP', 'CE1', 'CE2', 'CM1', 'CM2']),
      ]);
    }
    if (hasCollege) {
      list.add(SchoolSeries(name: 'Collège', code: 'COL', description: '6e à 3e',
          classes: ['6e', '5e', '4e', '3e']));
    }
    if (hasLycee) {
      list.addAll([
        SchoolSeries(name: 'Seconde', code: '2nde', description: 'Tronc commun',
            classes: ['2nde A', '2nde B']),
        SchoolSeries(name: 'Première', code: '1re', description: 'Séries A et C/D',
            classes: ['1re A', '1re C', '1re D']),
        SchoolSeries(name: 'Terminale', code: 'Tle', description: 'Baccalauréat',
            classes: ['Tle A', 'Tle C', 'Tle D', 'Tle F']),
      ]);
    }
  } else if (system == 'anglophone') {
    if (hasPrimaire) {
      list.add(SchoolSeries(name: 'Primary', code: 'PRI', description: 'Class 1 to 6',
          classes: ['Class 1', 'Class 2', 'Class 3', 'Class 4', 'Class 5', 'Class 6']));
    }
    if (hasCollege) {
      list.add(SchoolSeries(name: 'Junior Secondary', code: 'JSS', description: 'JSS 1 to 3',
          classes: ['JSS 1', 'JSS 2', 'JSS 3']));
    }
    if (hasLycee) {
      list.add(SchoolSeries(name: 'Senior Secondary', code: 'SSS', description: 'SSS 1 to 3',
          classes: ['SSS 1 Science', 'SSS 2 Science', 'SSS 3 Science',
                    'SSS 1 Arts', 'SSS 2 Arts', 'SSS 3 Arts']));
    }
  } else if (system == 'lmd' && hasUniv) {
    list.addAll([
      SchoolSeries(name: 'Licence', code: 'L', description: 'Bac+3',
          classes: ['L1', 'L2', 'L3']),
      SchoolSeries(name: 'Master', code: 'M', description: 'Bac+5',
          classes: ['M1', 'M2']),
      SchoolSeries(name: 'Doctorat', code: 'D', description: 'Bac+8',
          classes: ['D1', 'D2', 'D3']),
    ]);
  } else if (system == 'technique' || hasTech) {
    list.addAll([
      SchoolSeries(name: 'CAP', code: 'CAP', description: 'Certificat d\'Aptitude Pro',
          classes: ['CAP 1', 'CAP 2']),
      SchoolSeries(name: 'BEP', code: 'BEP', description: 'Brevet d\'Études Pro',
          classes: ['BEP 1', 'BEP 2']),
      SchoolSeries(name: 'BTS', code: 'BTS', description: 'Brevet de Technicien Sup.',
          classes: ['BTS 1', 'BTS 2']),
    ]);
  }

  if (list.isEmpty) {
    list.add(SchoolSeries(name: 'Classe générale', code: 'GEN', classes: ['Classe A']));
  }
  return list;
}

// ═════════════════════════════════════════════════════════════════════════════
// MAIN SCREEN
// ═════════════════════════════════════════════════════════════════════════════
class SchoolRegistrationScreen extends StatefulWidget {
  const SchoolRegistrationScreen({super.key});

  @override
  State<SchoolRegistrationScreen> createState() => _SchoolRegistrationScreenState();
}

class _SchoolRegistrationScreenState extends State<SchoolRegistrationScreen> {
  int _step = 0;
  bool _submitting = false;
  String? _globalError;

  // ── Step 1 — École ──────────────────────────────────────────────────────────
  final _s1Form    = GlobalKey<FormState>();
  final _s1Name    = TextEditingController();
  final _s1Motto   = TextEditingController();
  final _s1Year    = TextEditingController();
  final _s1Country = TextEditingController(text: 'Congo');
  final _s1City    = TextEditingController();
  final _s1Address = TextEditingController();
  final _s1MapLink = TextEditingController();
  final _s1Email   = TextEditingController();
  final _s1Website = TextEditingController();
  final _s1Phone   = TextEditingController();
  String _s1DialCode    = '+242';
  String _s1DialFlag    = '🇨🇬';
  Set<String> _types    = {'lycee'};
  List<SchoolBranch> _branches = [];

  // ── Step 2 — Admin ─────────────────────────────────────────────────────────
  final _s2Form    = GlobalKey<FormState>();
  final _s2Name    = TextEditingController();
  final _s2Title   = TextEditingController(text: 'Fondateur');
  final _s2Email   = TextEditingController();
  final _s2Phone   = TextEditingController();
  final _s2Pass    = TextEditingController();
  String _s2DialCode = '+242';
  String _s2DialFlag = '🇨🇬';
  bool   _s2Obscure  = true;
  int    _s2BannerIdx = 0;
  static const _bannerGradients = [
    [Color(0xFF3E1A00), Color(0xFF8B1A00)],
    [Color(0xFF050F08), Color(0xFF1B5E20)],
    [Color(0xFF0D2244), Color(0xFF1565C0)],
    [Color(0xFF1A0030), Color(0xFF6A0DAD)],
    [Color(0xFF1A1A00), Color(0xFF827717)],
  ];

  // ── Step 3 — Système ───────────────────────────────────────────────────────
  String _s3System = 'francophone';

  // ── Step 4 — Séries ────────────────────────────────────────────────────────
  List<SchoolSeries> _series = [];
  final _newSeriesNameCtrl = TextEditingController();
  final _newSeriesCodeCtrl = TextEditingController();
  final _newSeriesDescCtrl = TextEditingController();

  // ── Step 5 — Base de données ───────────────────────────────────────────────
  String _s5DbType       = 'scolaris';
  String _s5CustomDbType = 'supabase';
  final _s5Endpoint      = TextEditingController();
  final _s5ApiKey        = TextEditingController();
  bool   _s5Tested       = false;
  bool   _s5Testing      = false;
  String? _s5TestResult;

  // 6 steps — no design step
  static const _stepLabels = [
    'École', 'Administrateur', 'Système éducatif',
    'Structure & Séries', 'Base de données', 'Récapitulatif',
  ];

  @override
  void initState() {
    super.initState();
    _series = _defaultSeries(_s3System, _types);
  }

  @override
  void dispose() {
    for (final c in [
      _s1Name, _s1Motto, _s1Year, _s1Country, _s1City, _s1Address, _s1MapLink,
      _s1Email, _s1Website, _s1Phone,
      _s2Name, _s2Title, _s2Email, _s2Phone, _s2Pass,
      _s5Endpoint, _s5ApiKey,
      _newSeriesNameCtrl, _newSeriesCodeCtrl, _newSeriesDescCtrl,
    ]) { c.dispose(); }
    super.dispose();
  }

  bool _validateStep() {
    if (_step == 0) {
      if (_types.isEmpty) {
        setState(() => _globalError = 'Sélectionnez au moins un type d\'établissement.');
        return false;
      }
      return _s1Form.currentState?.validate() ?? false;
    }
    if (_step == 1) return _s2Form.currentState?.validate() ?? false;
    return true;
  }

  void _next() {
    setState(() => _globalError = null);
    if (!_validateStep()) return;
    if (_step == 2) {
      _series = _defaultSeries(_s3System, _types);
    }
    setState(() => _step = (_step + 1).clamp(0, 5));
  }

  void _prev() => setState(() { _step = (_step - 1).clamp(0, 5); _globalError = null; });

  Future<void> _submit() async {
    setState(() { _submitting = true; _globalError = null; });
    try {
      final supabase = Supabase.instance.client;
      final schoolId = const Uuid().v4();
      final slug = _s1Name.text.trim().toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-');

      await supabase.from('schools').insert({
        'id': schoolId,
        'name': _s1Name.text.trim(),
        'type': _types.join(','),
        'country': _s1Country.text.trim(),
        'city': _s1City.text.trim(),
        'address': _s1Address.text.trim(),
        'website': _s1Website.text.trim().isEmpty ? null : _s1Website.text.trim(),
        'email': _s1Email.text.trim().isEmpty ? null : _s1Email.text.trim(),
        'phone': '${_s1DialCode}${_s1Phone.text.trim()}',
        'educational_system': _s3System,
        'db_type': _s5DbType,
        'slug': slug,
        'status': 'active',
      });

      for (final b in _branches) {
        if (b.city.isNotEmpty || b.address.isNotEmpty) {
          await supabase.from('school_branches').insert({
            'school_id': schoolId,
            'name': b.name.isEmpty ? null : b.name,
            'country': b.country.isEmpty ? null : b.country,
            'city': b.city,
            'address': b.address,
            'phone': b.phone.isEmpty ? null : '${b.dialCode}${b.phone}',
          });
        }
      }

      await supabase.from('school_founders').insert({
        'school_id': schoolId,
        'full_name': _s2Name.text.trim(),
        'email': _s2Email.text.trim(),
        'phone': _s2Phone.text.trim().isEmpty ? null : '${_s2DialCode}${_s2Phone.text.trim()}',
        'role_label': _s2Title.text.trim().isEmpty ? 'Fondateur' : _s2Title.text.trim(),
      });

      for (final s in _series.where((s) => s.isActive)) {
        final sId = const Uuid().v4();
        await supabase.from('school_series').insert({
          'id': sId, 'school_id': schoolId,
          'name': s.name, 'code': s.code, 'is_active': true,
        });
        for (final cl in s.classes) {
          await supabase.from('school_classes').insert({
            'school_id': schoolId, 'series_id': sId, 'name': cl,
          });
        }
      }

      if (mounted) _showSuccess(schoolId);
    } catch (e) {
      setState(() => _globalError = 'Erreur : ${e.toString()}');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSuccess(String id) {
    showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(color: _green.withOpacity(.1), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded, color: _green, size: 48),
            ),
            const SizedBox(height: 20),
            const Text('École créée avec succès !', textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _ink)),
            const SizedBox(height: 8),
            Text('ID : ${id.substring(0, 8)}…', textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: _muted)),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity,
              child: _PrimaryBtn(
                label: 'Retour à la connexion',
                onTap: () { Navigator.pop(context); context.go('/login'); },
                loading: false,
              )),
          ]),
        ),
      ),
    );
  }

  Future<void> _testDbConn() async {
    setState(() { _s5Testing = true; _s5TestResult = null; });
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      _s5Testing = false; _s5Tested = true;
      _s5TestResult = (_s5Endpoint.text.isNotEmpty && _s5ApiKey.text.isNotEmpty)
          ? '✓ Connexion réussie' : '✗ Endpoint ou clé manquant(e)';
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width > 860;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _cream,
        body: isWide ? _buildWide() : _buildNarrow(),
      ),
    );
  }

  Widget _buildWide() {
    return Row(
      children: [
        // ── Sidebar ────────────────────────────────────────────────────────
        SizedBox(
          width: 268,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF050F08), Color(0xFF0D3B1E), Color(0xFF1B5E20)],
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
              ),
            ),
            child: Stack(children: [
              Positioned.fill(child: CustomPaint(painter: _SidebarPatternPainter())),
              Column(children: [
                const SizedBox(height: 40),
                _SidebarLogo(),
                const SizedBox(height: 28),
                _StepProgress(current: _step, total: _stepLabels.length),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _stepLabels.length,
                    itemBuilder: (_, i) => _SidebarStep(
                      index: i, label: _stepLabels[i],
                      current: _step, total: _stepLabels.length,
                      onTap: i <= _step ? () => setState(() { _step = i; _globalError = null; }) : null,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _white.withOpacity(.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _white.withOpacity(.1)),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.shield_outlined, size: 12, color: _gold.withOpacity(.7)),
                      const SizedBox(width: 6),
                      Text('Données sécurisées SSL',
                          style: TextStyle(color: _white.withOpacity(.45), fontSize: 10.5)),
                    ]),
                  ),
                ),
              ]),
            ]),
          ),
        ),
        // ── Content ────────────────────────────────────────────────────────
        Expanded(
          child: Column(children: [
            _TopBar(step: _step, total: _stepLabels.length,
                label: _stepLabels[_step],
                onBack: () => context.go('/login')),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
                child: _buildStepContent(),
              ),
            ),
            _BottomNav(
              step: _step, total: _stepLabels.length,
              onPrev: _step > 0 ? _prev : null,
              onNext: _step < 5 ? _next : null,
              onSubmit: _step == 5 ? _submit : null,
              submitting: _submitting, error: _globalError,
            ),
          ]),
        ),
      ],
    );
  }

  Widget _buildNarrow() {
    return Column(children: [
      _MobileHeader(step: _step, total: _stepLabels.length,
          label: _stepLabels[_step], onBack: () => context.go('/login')),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: _buildStepContent(),
        ),
      ),
      _BottomNav(
        step: _step, total: _stepLabels.length,
        onPrev: _step > 0 ? _prev : null,
        onNext: _step < 5 ? _next : null,
        onSubmit: _step == 5 ? _submit : null,
        submitting: _submitting, error: _globalError,
      ),
    ]);
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 0: return _buildStep1();
      case 1: return _buildStep2();
      case 2: return _buildStep3();
      case 3: return _buildStep4();
      case 4: return _buildStep5();
      case 5: return _buildStep6();
      default: return const SizedBox.shrink();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 1 — Informations École
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildStep1() {
    return Form(
      key: _s1Form,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _StepHeader(
          icon: Icons.business_outlined,
          title: 'Informations de l\'école',
          subtitle: 'Renseignez les informations principales de votre établissement scolaire.',
          lottie: 'assets/lottie/school_building.json',
        ),
        const SizedBox(height: 28),

        // ── School types ────────────────────────────────────────────────
        _FieldLabel('Type(s) d\'établissement', required: true),
        const SizedBox(height: 4),
        Text('Sélection multiple possible — ex : Collège + Lycée',
            style: TextStyle(fontSize: 11.5, color: _muted)),
        const SizedBox(height: 12),
        _SchoolTypeGrid(
          selected: _types,
          onToggle: (id) => setState(() {
            if (_types.contains(id)) {
              if (_types.length > 1) _types.remove(id);
            } else {
              _types.add(id);
            }
          }),
        ),
        const SizedBox(height: 24),

        // ── Name + country ───────────────────────────────────────────────
        _TwoCol(
          left: _SField(ctrl: _s1Name, label: 'Nom de l\'école', required: true,
              hint: 'Collège Saint-Joseph', icon: Icons.school_outlined,
              validator: (v) => (v?.isEmpty ?? true) ? 'Nom requis' : null),
          right: _SField(ctrl: _s1Country, label: 'Pays', required: true,
              hint: 'Congo', icon: Icons.public_outlined,
              validator: (v) => (v?.isEmpty ?? true) ? 'Pays requis' : null),
        ),
        const SizedBox(height: 16),

        // ── Motto + year ────────────────────────────────────────────────
        _TwoCol(
          left: _SField(ctrl: _s1Motto, label: 'Devise / Slogan',
              hint: 'Savoir, Héritage, Avenir', icon: Icons.format_quote_outlined),
          right: _SField(ctrl: _s1Year, label: 'Année de création',
              hint: '2005', icon: Icons.calendar_today_outlined,
              keyboard: TextInputType.number),
        ),
        const SizedBox(height: 16),

        // ── City + address ───────────────────────────────────────────────
        _TwoCol(
          left: _SField(ctrl: _s1City, label: 'Ville principale', required: true,
              hint: 'Brazzaville', icon: Icons.location_city_outlined,
              validator: (v) => (v?.isEmpty ?? true) ? 'Ville requise' : null),
          right: _SField(ctrl: _s1Address, label: 'Adresse postale', required: true,
              hint: 'Rue Pasteur, Quartier Moungali…', icon: Icons.map_outlined,
              validator: (v) => (v?.isEmpty ?? true) ? 'Adresse requise' : null),
        ),
        const SizedBox(height: 16),

        // ── Google Maps link ─────────────────────────────────────────────
        _SField(ctrl: _s1MapLink, label: 'Lien Google Maps (optionnel)',
            hint: 'https://maps.google.com/?q=…', icon: Icons.pin_drop_outlined,
            keyboard: TextInputType.url),
        const SizedBox(height: 16),

        // ── Phone + email ────────────────────────────────────────────────
        _TwoCol(
          left: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _FieldLabel('Téléphone principal'),
            const SizedBox(height: 6),
            _PhoneRow(
              flag: _s1DialFlag, dialCode: _s1DialCode, ctrl: _s1Phone,
              onDialTap: () => _pickDialCode(
                onPick: (f, c) => setState(() { _s1DialFlag = f; _s1DialCode = c; }),
              ),
            ),
          ]),
          right: _SField(ctrl: _s1Email, label: 'Email officiel',
              hint: 'contact@ecole.com', icon: Icons.mail_outline,
              keyboard: TextInputType.emailAddress),
        ),
        const SizedBox(height: 16),

        _SField(ctrl: _s1Website, label: 'Site web officiel',
            hint: 'https://ecole.com', icon: Icons.link_outlined,
            keyboard: TextInputType.url),
        const SizedBox(height: 28),

        // ── Branches ─────────────────────────────────────────────────────
        _SectionDivider(label: 'Filiales / Autres campus',
            icon: Icons.add_business_outlined,
            sub: 'Chaque filiale est la même école dans une autre ville avec ses propres coordonnées.'),
        const SizedBox(height: 14),
        ..._branches.asMap().entries.map((e) => _BranchCard(
          index: e.key, branch: e.value,
          onRemove: () => setState(() => _branches.removeAt(e.key)),
          onPickDial: () => _pickDialCode(
            onPick: (f, c) => setState(() {
              _branches[e.key].countryFlag = f;
              _branches[e.key].dialCode = c;
            }),
          ),
          onChange: () => setState(() {}),
        )),
        const SizedBox(height: 10),
        _OutlineBtn(
          label: '+ Ajouter une filiale',
          icon: Icons.add_business_outlined,
          onTap: () => setState(() => _branches.add(SchoolBranch())),
        ),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 2 — Compte Administrateur
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildStep2() {
    final initials = _s2Name.text.isNotEmpty
        ? _s2Name.text.trim().split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase()
        : 'AD';
    final bannerColors = _bannerGradients[_s2BannerIdx];

    return Form(
      key: _s2Form,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _StepHeader(
          icon: Icons.person_outline_rounded,
          title: 'Compte administrateur',
          subtitle: 'Ce compte recevra le rôle Fondateur avec accès total à la plateforme.',
          lottie: 'assets/lottie/admin.json',
        ),
        const SizedBox(height: 24),

        // ── Facebook-style profile header ─────────────────────────────
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Banner
              Container(
                width: double.infinity,
                height: 160,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: bannerColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(children: [
                  Positioned.fill(child: CustomPaint(painter: _SidebarPatternPainter())),
                  Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Image.asset('assets/images/logo_transparent.png', width: 36, height: 36,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.school_rounded, color: Colors.white54, size: 32)),
                    const SizedBox(height: 6),
                    Text('Scolaris', style: TextStyle(color: _white.withOpacity(.4),
                        fontSize: 14, fontWeight: FontWeight.w700)),
                  ])),
                  // Banner color picker button
                  Positioned(top: 10, right: 10,
                    child: GestureDetector(
                      onTap: _pickBannerColor,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.camera_alt_outlined, size: 13, color: _white),
                          const SizedBox(width: 4),
                          const Text('Bannière', style: TextStyle(color: _white, fontSize: 11,
                              fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),
                  ),
                ]),
              ),
              // Profile circle
              Positioned(
                left: 20,
                bottom: -44,
                child: Container(
                  width: 88, height: 88,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_terra, _orange],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: _cream, width: 4),
                    boxShadow: [BoxShadow(color: _terra.withOpacity(.3), blurRadius: 12)],
                  ),
                  child: Center(child: Text(initials,
                      style: const TextStyle(color: _white, fontSize: 28,
                          fontWeight: FontWeight.w900))),
                ),
              ),
              // Camera badge on profile
              Positioned(
                left: 70, bottom: -34,
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: _terra, shape: BoxShape.circle,
                    border: Border.all(color: _cream, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, size: 14, color: _white),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 52), // space for profile circle overflow

        _InfoBanner(
          icon: Icons.info_outline_rounded, color: _gold,
          text: 'Ce compte aura automatiquement le rôle "Fondateur" avec accès total. '
              'Vous pourrez modifier les permissions depuis le panneau d\'administration.',
        ),
        const SizedBox(height: 20),

        // ── Fields ────────────────────────────────────────────────────
        _TwoCol(
          left: _SField(ctrl: _s2Name, label: 'Nom complet', required: true,
              hint: 'Jean-Baptiste Ondo', icon: Icons.badge_outlined,
              validator: (v) => (v?.isEmpty ?? true) ? 'Nom requis' : null,
              onChanged: (_) => setState(() {})),
          right: _SField(ctrl: _s2Title, label: 'Titre / Fonction',
              hint: 'Directeur, Fondateur…', icon: Icons.work_outline_rounded),
        ),
        const SizedBox(height: 16),

        _TwoCol(
          left: _SField(ctrl: _s2Email, label: 'Email', required: true,
              hint: 'admin@ecole.com', icon: Icons.mail_outline,
              keyboard: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Email requis';
                if (!v.contains('@')) return 'Email invalide';
                return null;
              }),
          right: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _FieldLabel('Téléphone'),
            const SizedBox(height: 6),
            _PhoneRow(
              flag: _s2DialFlag, dialCode: _s2DialCode, ctrl: _s2Phone,
              onDialTap: () => _pickDialCode(
                onPick: (f, c) => setState(() { _s2DialFlag = f; _s2DialCode = c; }),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        _FieldLabel('Mot de passe', required: true),
        const SizedBox(height: 6),
        TextFormField(
          controller: _s2Pass, obscureText: _s2Obscure,
          validator: (v) => (v == null || v.length < 8) ? 'Minimum 8 caractères' : null,
          style: const TextStyle(fontSize: 14, color: _ink),
          decoration: _inputDeco(
            hint: '••••••••', icon: Icons.lock_outline_rounded,
            suffix: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              icon: Icon(_s2Obscure
                  ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 18, color: _muted),
              onPressed: () => setState(() => _s2Obscure = !_s2Obscure),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _PasswordStrength(password: _s2Pass.text),
      ]),
    );
  }

  void _pickBannerColor() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cream,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          const Text('Couleur de bannière', style: TextStyle(fontSize: 16,
              fontWeight: FontWeight.w800, color: _ink)),
          const SizedBox(height: 16),
          Row(children: List.generate(_bannerGradients.length, (i) => GestureDetector(
            onTap: () { setState(() => _s2BannerIdx = i); Navigator.pop(context); },
            child: Container(
              width: 52, height: 52,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: _bannerGradients[i],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(12),
                border: _s2BannerIdx == i
                    ? Border.all(color: _terra, width: 2.5) : null,
              ),
              child: _s2BannerIdx == i
                  ? const Icon(Icons.check_rounded, color: _white, size: 22) : null,
            ),
          ))),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 3 — Système éducatif
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildStep3() {
    // Filter systems by selected types
    final compatible = _kSystems.where((s) =>
        s.compatibleTypes.any((t) => _types.contains(t))).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _StepHeader(
        icon: Icons.menu_book_outlined,
        title: 'Système éducatif',
        subtitle: 'Choisissez le référentiel pédagogique de votre établissement.\nSystèmes filtrés selon vos types sélectionnés.',
        lottie: 'assets/lottie/school_register.json',
      ),
      const SizedBox(height: 24),

      if (compatible.isEmpty)
        _InfoBanner(icon: Icons.warning_amber_rounded, color: _orange,
            text: 'Aucun système compatible trouvé. Revenez à l\'étape 1 et sélectionnez vos types d\'établissement.')
      else ...[
        Text('${_types.length} type(s) sélectionné(s) : ${_types.map((t) {
          return _kSchoolTypes.firstWhere((st) => st.id == t).label;
        }).join(', ')}',
            style: TextStyle(fontSize: 12, color: _muted, fontStyle: FontStyle.italic)),
        const SizedBox(height: 16),
        ...compatible.map((sys) => _SystemCard(
          sys: sys,
          selected: _s3System == sys.id,
          onTap: () => setState(() => _s3System = sys.id),
          onInfo: () => _showSystemInfo(sys),
        )),
      ],

      if (_s3System == 'autre') ...[
        const SizedBox(height: 16),
        _InfoBanner(
          icon: Icons.support_agent_outlined, color: _terra,
          text: 'Votre système nécessite une configuration spécifique.\n'
              '📧 scolaris.dev@gmail.com\n📱 WhatsApp : +242 065 702 018',
        ),
      ],
    ]);
  }

  void _showSystemInfo(_SysInfo sys) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
          child: Column(children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF050F08), Color(0xFF1B5E20)]),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(children: [
                Text(sys.flag, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(sys.title, style: const TextStyle(color: _white,
                      fontSize: 18, fontWeight: FontWeight.w900)),
                  Text('Langue : ${sys.language}',
                      style: TextStyle(color: _white.withOpacity(.6), fontSize: 12)),
                ])),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(color: _white.withOpacity(.15), shape: BoxShape.circle),
                    child: const Icon(Icons.close_rounded, color: _white, size: 16),
                  ),
                ),
              ]),
            ),
            // Content
            Expanded(child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _InfoDialogSection(icon: Icons.history_edu_outlined, title: 'Origine', text: sys.origin),
                _InfoDialogSection(icon: Icons.public_outlined, title: 'Pays pratiquants', text: sys.countries),
                _InfoDialogSection(icon: Icons.account_tree_outlined, title: 'Structure',
                    list: sys.structure),
                _InfoDialogSection(icon: Icons.workspace_premium_outlined, title: 'Diplômes',
                    list: sys.diplomas),
              ]),
            )),
            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SizedBox(width: double.infinity,
                child: _PrimaryBtn(
                  label: 'Sélectionner ${sys.title}', loading: false,
                  onTap: () { setState(() => _s3System = sys.id); Navigator.pop(context); },
                )),
            ),
          ]),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 4 — Structure & Séries
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildStep4() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _StepHeader(
        icon: Icons.account_tree_outlined,
        title: 'Structure & Séries',
        subtitle: 'Configurez les filières, séries et classes de votre établissement.',
        lottie: 'assets/lottie/teacher.json',
      ),
      const SizedBox(height: 16),

      _InfoBanner(
        icon: Icons.auto_awesome_outlined, color: _green,
        text: 'Structure générée automatiquement selon votre système "${_kSystems.firstWhere((s) => s.id == _s3System).title}". '
            'Modifiez librement, activez/désactivez et ajoutez de nouvelles séries.',
      ),
      const SizedBox(height: 20),

      if (_series.isEmpty)
        _InfoBanner(icon: Icons.warning_amber_rounded, color: _orange,
            text: 'Aucune série. Utilisez le formulaire ci-dessous pour en créer.')
      else
        ..._series.asMap().entries.map((e) => _SeriesCard(
          series: e.value,
          onToggle: (v) => setState(() => _series[e.key].isActive = v),
          onRemove: () => setState(() => _series.removeAt(e.key)),
          onAddClass: (cls) => setState(() => _series[e.key].classes.add(cls)),
          onRemoveClass: (ci) => setState(() => _series[e.key].classes.removeAt(ci)),
          onChange: () => setState(() {}),
        )),

      const SizedBox(height: 20),
      _SectionDivider(label: 'Ajouter une nouvelle série', icon: Icons.add_circle_outline),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: Column(children: [
          _TwoCol(
            left: TextField(
              controller: _newSeriesNameCtrl,
              style: const TextStyle(fontSize: 14, color: _ink),
              decoration: _inputDeco(hint: 'Nom (ex: Terminale D)', icon: Icons.label_outline),
            ),
            right: TextField(
              controller: _newSeriesCodeCtrl,
              style: const TextStyle(fontSize: 14, color: _ink),
              decoration: _inputDeco(hint: 'Code (ex: TleD)', icon: Icons.tag_outlined),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _newSeriesDescCtrl,
            style: const TextStyle(fontSize: 14, color: _ink),
            decoration: _inputDeco(hint: 'Description (ex: Baccalauréat Série D)', icon: Icons.notes_outlined),
          ),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity,
            child: _PrimaryBtn(
              label: '+ Créer cette série',
              loading: false,
              icon: Icons.add_circle_outline,
              onTap: () {
                if (_newSeriesNameCtrl.text.isEmpty) return;
                setState(() {
                  _series.add(SchoolSeries(
                    name: _newSeriesNameCtrl.text.trim(),
                    code: _newSeriesCodeCtrl.text.trim().isNotEmpty
                        ? _newSeriesCodeCtrl.text.trim()
                        : _newSeriesNameCtrl.text.trim().substring(0, 1).toUpperCase(),
                    description: _newSeriesDescCtrl.text.trim(),
                    classes: [],
                  ));
                  _newSeriesNameCtrl.clear();
                  _newSeriesCodeCtrl.clear();
                  _newSeriesDescCtrl.clear();
                });
              },
            )),
        ]),
      ),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 5 — Base de données
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildStep5() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _StepHeader(
        icon: Icons.storage_outlined,
        title: 'Base de données',
        subtitle: 'Choisissez où stocker les données de votre établissement.',
        lottie: 'assets/lottie/loading.json',
      ),
      const SizedBox(height: 24),

      _DbOptionCard(
        id: 'scolaris',
        title: 'Base Scolaris (recommandé)',
        subtitle: 'Hébergée et maintenue par Scolaris — zéro configuration, sauvegardes automatiques.',
        icon: Icons.cloud_done_outlined, badge: 'RECOMMANDÉ',
        selected: _s5DbType == 'scolaris',
        onTap: () => setState(() => _s5DbType = 'scolaris'),
      ),
      const SizedBox(height: 12),
      _DbOptionCard(
        id: 'custom',
        title: 'Base personnalisée',
        subtitle: 'Connectez votre propre base (Supabase, PostgreSQL, Firebase, MongoDB).',
        icon: Icons.dns_outlined,
        selected: _s5DbType == 'custom',
        onTap: () => setState(() => _s5DbType = 'custom'),
      ),

      if (_s5DbType == 'custom') ...[
        const SizedBox(height: 20),
        _SectionDivider(label: 'Type de base', icon: Icons.storage_outlined),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: ['supabase', 'postgresql', 'firebase', 'mongodb'].map((t) => _TypeChip(
            label: t[0].toUpperCase() + t.substring(1),
            selected: _s5CustomDbType == t,
            onTap: () => setState(() => _s5CustomDbType = t),
          )).toList(),
        ),
        const SizedBox(height: 16),
        _SField(ctrl: _s5Endpoint, label: 'Endpoint / URL',
            hint: 'https://xxx.supabase.co', icon: Icons.link_outlined),
        const SizedBox(height: 12),
        _SField(ctrl: _s5ApiKey, label: 'API Key', hint: 'eyJhb…',
            icon: Icons.vpn_key_outlined, obscure: true),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity,
          child: _PrimaryBtn(
            label: _s5Testing ? 'Test en cours…' : 'Tester la connexion',
            onTap: _s5Testing ? null : _testDbConn,
            loading: _s5Testing,
            icon: Icons.wifi_tethering_outlined,
          )),
        if (_s5TestResult != null) ...[
          const SizedBox(height: 12),
          _InfoBanner(
            icon: _s5TestResult!.startsWith('✓') ? Icons.check_circle_outline : Icons.error_outline,
            color: _s5TestResult!.startsWith('✓') ? _green : _red,
            text: _s5TestResult!,
          ),
        ],
      ],
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 6 — Récapitulatif
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildStep6() {
    final sysName = _kSystems.firstWhere((s) => s.id == _s3System).title;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _StepHeader(
        icon: Icons.fact_check_outlined,
        title: 'Récapitulatif final',
        subtitle: 'Vérifiez toutes les informations avant de créer votre école.',
        lottie: 'assets/lottie/success.json',
      ),
      const SizedBox(height: 20),

      // Types
      _RecapCard(
        title: 'Types d\'établissement',
        icon: Icons.category_outlined, color: _terra,
        items: [('Types', _types.map((t) =>
            _kSchoolTypes.firstWhere((st) => st.id == t).label).join(' · '))],
      ),
      const SizedBox(height: 10),

      _RecapCard(
        title: 'Informations école',
        icon: Icons.business_outlined, color: _terra,
        items: [
          ('Nom', _s1Name.text.trim()),
          ('Pays / Ville', '${_s1Country.text.trim()} — ${_s1City.text.trim()}'),
          ('Adresse', _s1Address.text.trim()),
          if (_s1Email.text.isNotEmpty) ('Email', _s1Email.text.trim()),
          if (_s1Phone.text.isNotEmpty) ('Tél.', '${_s1DialCode} ${_s1Phone.text.trim()}'),
          if (_s1Website.text.isNotEmpty) ('Web', _s1Website.text.trim()),
          if (_branches.isNotEmpty) ('Filiales', '${_branches.length} filiale(s)'),
        ],
      ),
      const SizedBox(height: 10),

      _RecapCard(
        title: 'Administrateur',
        icon: Icons.person_outline_rounded, color: _orange,
        items: [
          ('Nom', _s2Name.text.trim()),
          ('Titre', _s2Title.text.trim().isEmpty ? 'Fondateur' : _s2Title.text.trim()),
          ('Email', _s2Email.text.trim()),
          ('Rôle', 'Fondateur — accès total'),
        ],
      ),
      const SizedBox(height: 10),

      _RecapCard(
        title: 'Système éducatif',
        icon: Icons.menu_book_outlined, color: _gold,
        items: [('Système', sysName)],
      ),
      const SizedBox(height: 10),

      _RecapCard(
        title: 'Séries actives (${_series.where((s) => s.isActive).length})',
        icon: Icons.account_tree_outlined, color: _green,
        items: _series.where((s) => s.isActive).map((s) =>
            (s.name, '${s.classes.length} classe(s)${s.classes.isNotEmpty ? " : ${s.classes.take(3).join(', ')}${s.classes.length > 3 ? '…' : ''}" : ''}')).toList(),
      ),
      const SizedBox(height: 10),

      _RecapCard(
        title: 'Base de données',
        icon: Icons.storage_outlined, color: _muted,
        items: [('Type', _s5DbType == 'scolaris' ? 'Base Scolaris (hébergée)' : 'Base personnalisée ($_s5CustomDbType)')],
      ),

      const SizedBox(height: 16),
      _InfoBanner(
        icon: Icons.info_outline_rounded, color: _green,
        text: 'En cliquant sur "Créer mon école", toutes vos données seront enregistrées '
            'et votre espace Scolaris sera initialisé immédiatement.',
      ),
    ]);
  }

  // ── Dial code picker ────────────────────────────────────────────────────────
  void _pickDialCode({required void Function(String flag, String code) onPick}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cream,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: .55,
        maxChildSize: .85,
        minChildSize: .3,
        expand: false,
        builder: (ctx, scroll) => Column(children: [
          Container(margin: const EdgeInsets.symmetric(vertical: 10),
              width: 36, height: 4,
              decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2))),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Text('Indicatif pays', style: TextStyle(fontSize: 16,
                fontWeight: FontWeight.w800, color: _ink)),
          ),
          Expanded(child: ListView.builder(
            controller: scroll,
            itemCount: _kDialCodes.length,
            itemBuilder: (_, i) {
              final d = _kDialCodes[i];
              return ListTile(
                leading: Text(d.flag, style: const TextStyle(fontSize: 22)),
                title: Text(d.country, style: const TextStyle(fontSize: 14, color: _ink)),
                trailing: Text(d.code, style: TextStyle(fontSize: 13, color: _muted)),
                onTap: () { onPick(d.flag, d.code); Navigator.pop(context); },
              );
            },
          )),
        ]),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// LAYOUT WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

class _SidebarLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        width: 64, height: 64,
        decoration: BoxDecoration(
          color: _white.withOpacity(.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _white.withOpacity(.12)),
        ),
        padding: const EdgeInsets.all(6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset('assets/images/logo.png', fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.school_rounded, color: _gold, size: 36)),
        ),
      ),
      const SizedBox(height: 8),
      const Text('Scolaris', style: TextStyle(color: _white, fontSize: 18,
          fontWeight: FontWeight.w900, letterSpacing: .3)),
      Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: _gold.withOpacity(.15), borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _gold.withOpacity(.25)),
        ),
        child: const Text('Inscription École', style: TextStyle(color: _gold, fontSize: 10.5,
            fontWeight: FontWeight.w600)),
      ),
    ]);
  }
}

class _SidebarStep extends StatelessWidget {
  final int index, current, total;
  final String label;
  final VoidCallback? onTap;
  const _SidebarStep({required this.index, required this.label,
      required this.current, required this.total, this.onTap});

  @override
  Widget build(BuildContext context) {
    final done   = index < current;
    final active = index == current;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
          decoration: BoxDecoration(
            color: active ? _white.withOpacity(.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: active ? Border.all(color: _white.withOpacity(.15)) : null,
          ),
          child: Row(children: [
            Column(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 26, height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? _gold : active ? _white : _white.withOpacity(.1),
                  boxShadow: active ? [BoxShadow(color: _white.withOpacity(.2), blurRadius: 6)] : [],
                ),
                child: Center(child: done
                    ? const Icon(Icons.check_rounded, size: 13, color: Color(0xFF0D3B1E))
                    : Text('${index + 1}', style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w800,
                        color: active ? _ink : _white.withOpacity(.4)))),
              ),
              if (index < total - 1)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 2, height: 22,
                  color: done ? _gold.withOpacity(.5) : _white.withOpacity(.08),
                ),
            ]),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(
                color: active ? _white : done ? _gold : _white.withOpacity(.38),
                fontSize: 12, fontWeight: active ? FontWeight.w700 : done ? FontWeight.w500 : FontWeight.w400,
              )),
              if (done && onTap != null)
                Text('Modifier', style: TextStyle(color: _gold.withOpacity(.5), fontSize: 9.5)),
            ])),
            if (done && onTap != null)
              Icon(Icons.edit_outlined, size: 12, color: _gold.withOpacity(.4)),
          ]),
        ),
      ),
    );
  }
}

class _StepProgress extends StatelessWidget {
  final int current, total;
  const _StepProgress({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = (current + 1) / total;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _white.withOpacity(.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _white.withOpacity(.1)),
      ),
      child: Row(children: [
        SizedBox(width: 34, height: 34,
          child: CustomPaint(painter: _RingPainter(pct),
            child: Center(child: Text('${current + 1}',
                style: const TextStyle(color: _white, fontSize: 12,
                    fontWeight: FontWeight.w900))))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Étape ${current + 1} sur $total',
              style: const TextStyle(color: _white, fontSize: 11.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: pct,
                backgroundColor: _white.withOpacity(.12),
                valueColor: const AlwaysStoppedAnimation(_gold), minHeight: 5),
          ),
        ])),
      ]),
    );
  }
}

class _TopBar extends StatelessWidget {
  final int step, total;
  final String label;
  final VoidCallback onBack;
  const _TopBar({required this.step, required this.total,
      required this.label, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final pct = (step + 1) / total;
    return Container(
      color: _white,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          GestureDetector(onTap: onBack,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: _terra.withOpacity(.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_rounded, color: _terra, size: 18),
            )),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Nouvelle école', style: TextStyle(fontSize: 16,
                fontWeight: FontWeight.w800, color: _ink)),
            Text(label, style: TextStyle(fontSize: 11.5, color: _muted)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _terra.withOpacity(.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('${step + 1} / $total',
                style: const TextStyle(color: _terra, fontSize: 12.5,
                    fontWeight: FontWeight.w800)),
          ),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(value: pct,
              backgroundColor: _border,
              valueColor: const AlwaysStoppedAnimation(_terra), minHeight: 6),
        ),
        const SizedBox(height: 0),
      ]),
    );
  }
}

class _MobileHeader extends StatelessWidget {
  final int step, total;
  final String label;
  final VoidCallback onBack;
  const _MobileHeader({required this.step, required this.total,
      required this.label, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final pct = (step + 1) / total;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D3B1E), Color(0xFF1B5E20)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 14, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          GestureDetector(onTap: onBack,
              child: const Icon(Icons.arrow_back_rounded, color: _white)),
          const SizedBox(width: 12),
          const Text('Inscription École', style: TextStyle(color: _white, fontSize: 16,
              fontWeight: FontWeight.w700)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _gold.withOpacity(.2), borderRadius: BorderRadius.circular(8),
            ),
            child: Text('${step + 1}/$total', style: const TextStyle(
                color: _gold, fontSize: 12, fontWeight: FontWeight.w800)),
          ),
        ]),
        const SizedBox(height: 10),
        Text(label, style: const TextStyle(color: _gold, fontSize: 13,
            fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: pct,
              backgroundColor: _white.withOpacity(.2),
              valueColor: const AlwaysStoppedAnimation(_gold), minHeight: 5),
        ),
      ]),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int step, total;
  final VoidCallback? onPrev, onNext, onSubmit;
  final bool submitting;
  final String? error;
  const _BottomNav({required this.step, required this.total,
      this.onPrev, this.onNext, this.onSubmit,
      required this.submitting, this.error});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: _white,
        boxShadow: [BoxShadow(color: _ink.withOpacity(.06), blurRadius: 12, offset: const Offset(0, -4))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (error != null) ...[
          Container(
            width: double.infinity, padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: _red.withOpacity(.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _red.withOpacity(.25)),
            ),
            child: Text(error!, style: const TextStyle(color: _red, fontSize: 12.5)),
          ),
        ],
        Row(children: [
          if (onPrev != null) ...[
            Expanded(child: _OutlineBtn(label: '← Retour', icon: null, onTap: onPrev!)),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 2,
            child: onSubmit != null
                ? _PrimaryBtn(
                    label: '🏫  Créer mon école', loading: submitting,
                    onTap: submitting ? null : onSubmit)
                : _PrimaryBtn(label: 'Continuer →', loading: false, onTap: onNext),
          ),
        ]),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// COMPONENT WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

class _StepHeader extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final String? lottie;
  const _StepHeader({required this.icon, required this.title,
      required this.subtitle, this.lottie});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF050F08), Color(0xFF0D3B1E)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: _gold.withOpacity(.15),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: _gold.withOpacity(.25)),
            ),
            child: Icon(icon, color: _gold, size: 23),
          ),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
              color: _white, height: 1.1)),
          const SizedBox(height: 7),
          Text(subtitle, style: TextStyle(fontSize: 12.5, color: _white.withOpacity(.6),
              height: 1.5)),
        ])),
        if (lottie != null) ...[
          const SizedBox(width: 10),
          SizedBox(
            width: 110, height: 110,
            child: Lottie.asset(lottie!, fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink()),
          ),
        ],
      ]),
    );
  }
}

// ── School Type Grid ──────────────────────────────────────────────────────────
class _SchoolTypeGrid extends StatelessWidget {
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  const _SchoolTypeGrid({required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final cols = w > 900 ? 4 : w > 540 ? 3 : 2;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols, mainAxisSpacing: 10, crossAxisSpacing: 10, mainAxisExtent: 96,
      ),
      itemCount: _kSchoolTypes.length,
      itemBuilder: (_, i) {
        final t = _kSchoolTypes[i];
        final isSelected = selected.contains(t.id);
        return GestureDetector(
          onTap: () => onToggle(t.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? _terra.withOpacity(.07) : _white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: isSelected ? _terra : _border,
                  width: isSelected ? 2 : 1),
              boxShadow: isSelected ? [BoxShadow(color: _terra.withOpacity(.1),
                  blurRadius: 8, offset: const Offset(0, 2))] : [],
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(t.emoji, style: const TextStyle(fontSize: 18)),
                if (isSelected)
                  Container(
                    width: 18, height: 18,
                    decoration: const BoxDecoration(color: _terra, shape: BoxShape.circle),
                    child: const Icon(Icons.check_rounded, size: 11, color: _white),
                  ),
              ]),
              const SizedBox(height: 6),
              Align(alignment: Alignment.centerLeft,
                child: Text(t.label, style: TextStyle(fontSize: 12.5,
                    color: isSelected ? _terra : _ink, fontWeight: FontWeight.w700))),
              Align(alignment: Alignment.centerLeft,
                child: Text(t.sub, style: TextStyle(fontSize: 10, color: _muted,
                    overflow: TextOverflow.ellipsis))),
            ]),
          ),
        );
      },
    );
  }
}

// ── Phone Row ─────────────────────────────────────────────────────────────────
class _PhoneRow extends StatelessWidget {
  final String flag, dialCode;
  final TextEditingController ctrl;
  final VoidCallback onDialTap;
  const _PhoneRow({required this.flag, required this.dialCode,
      required this.ctrl, required this.onDialTap});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      // Country code button
      GestureDetector(
        onTap: onDialTap,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF7F4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(flag, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 4),
            Text(dialCode, style: const TextStyle(fontSize: 12.5, color: _ink,
                fontWeight: FontWeight.w600)),
            const SizedBox(width: 2),
            const Icon(Icons.expand_more_rounded, size: 14, color: _muted),
          ]),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.phone,
        style: const TextStyle(fontSize: 14, color: _ink),
        decoration: _inputDeco(hint: '06 000 0000', icon: Icons.phone_outlined),
      )),
    ]);
  }
}

// ── System Card ───────────────────────────────────────────────────────────────
class _SystemCard extends StatelessWidget {
  final _SysInfo sys;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onInfo;
  const _SystemCard({required this.sys, required this.selected,
      required this.onTap, required this.onInfo});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? _terra.withOpacity(.06) : _white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? _terra : _border, width: selected ? 2 : 1),
          boxShadow: selected ? [BoxShadow(color: _terra.withOpacity(.08),
              blurRadius: 12, offset: const Offset(0, 3))] : [],
        ),
        child: Row(children: [
          Text(sys.flag, style: const TextStyle(fontSize: 30)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(sys.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                color: selected ? _terra : _ink)),
            const SizedBox(height: 2),
            Text(sys.countries.split(',').take(3).join(', ') + '…',
                style: const TextStyle(fontSize: 11.5, color: _muted),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text('Langue : ${sys.language}',
                style: TextStyle(fontSize: 11, color: _muted.withOpacity(.8))),
          ])),
          const SizedBox(width: 8),
          // Info button
          GestureDetector(
            onTap: onInfo,
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: _gold.withOpacity(.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _gold.withOpacity(.2)),
              ),
              child: const Icon(Icons.info_outline_rounded, size: 16, color: _gold),
            ),
          ),
          const SizedBox(width: 8),
          if (selected)
            const Icon(Icons.check_circle_rounded, color: _terra, size: 22),
        ]),
      ),
    );
  }
}

// ── Info Dialog Section ───────────────────────────────────────────────────────
class _InfoDialogSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? text;
  final List<String>? list;
  const _InfoDialogSection({required this.icon, required this.title, this.text, this.list});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 14, color: _terra),
          const SizedBox(width: 6),
          Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800,
              color: _ink, letterSpacing: 0.3)),
        ]),
        const SizedBox(height: 6),
        if (text != null)
          Text(text!, style: TextStyle(fontSize: 12.5, color: _muted, height: 1.55)),
        if (list != null)
          ...list!.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(margin: const EdgeInsets.only(top: 6),
                  width: 5, height: 5,
                  decoration: const BoxDecoration(color: _terra, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Text(item,
                  style: const TextStyle(fontSize: 12.5, color: _muted, height: 1.4))),
            ]),
          )),
      ]),
    );
  }
}

// ── Branch Card ───────────────────────────────────────────────────────────────
class _BranchCard extends StatelessWidget {
  final int index;
  final SchoolBranch branch;
  final VoidCallback onRemove, onChange, onPickDial;
  const _BranchCard({required this.index, required this.branch,
      required this.onRemove, required this.onChange, required this.onPickDial});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: _ink.withOpacity(.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          decoration: BoxDecoration(
            color: _terra.withOpacity(.04),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                  color: _terra.withOpacity(.12), borderRadius: BorderRadius.circular(8)),
              child: Center(child: Text('${index + 1}',
                  style: const TextStyle(color: _terra, fontSize: 13,
                      fontWeight: FontWeight.w900))),
            ),
            const SizedBox(width: 10),
            Text('Filiale ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w800,
                fontSize: 14, color: _ink)),
            const Spacer(),
            GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                    color: _red.withOpacity(.08), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.close_rounded, color: _red, size: 15),
              ),
            ),
          ]),
        ),
        // Body
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            TextField(
              style: const TextStyle(fontSize: 13, color: _ink),
              decoration: _inputDeco(hint: 'Nom de la filiale (ex: Campus Sud)', icon: Icons.label_outline),
              onChanged: (v) { branch.name = v; onChange(); },
            ),
            const SizedBox(height: 10),
            _TwoCol(
              left: TextField(
                style: const TextStyle(fontSize: 13, color: _ink),
                decoration: _inputDeco(hint: 'Pays *', icon: Icons.public_outlined),
                onChanged: (v) { branch.country = v; onChange(); },
              ),
              right: TextField(
                style: const TextStyle(fontSize: 13, color: _ink),
                decoration: _inputDeco(hint: 'Ville *', icon: Icons.location_city_outlined),
                onChanged: (v) { branch.city = v; onChange(); },
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              style: const TextStyle(fontSize: 13, color: _ink),
              decoration: _inputDeco(hint: 'Adresse complète *', icon: Icons.map_outlined),
              onChanged: (v) { branch.address = v; onChange(); },
            ),
            const SizedBox(height: 10),
            // Phone
            Row(children: [
              GestureDetector(
                onTap: onPickDial,
                child: Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF7F4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(branch.countryFlag, style: const TextStyle(fontSize: 15)),
                    const SizedBox(width: 4),
                    Text(branch.dialCode, style: const TextStyle(fontSize: 12,
                        color: _ink, fontWeight: FontWeight.w600)),
                    const Icon(Icons.expand_more_rounded, size: 13, color: _muted),
                  ]),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: TextField(
                keyboardType: TextInputType.phone,
                style: const TextStyle(fontSize: 13, color: _ink),
                decoration: _inputDeco(hint: 'Téléphone filiale', icon: Icons.phone_outlined),
                onChanged: (v) { branch.phone = v; onChange(); },
              )),
            ]),
            const SizedBox(height: 10),
            TextField(
              style: const TextStyle(fontSize: 13, color: _ink),
              decoration: _inputDeco(hint: 'Lien Google Maps (optionnel)', icon: Icons.pin_drop_outlined),
              onChanged: (v) { branch.googleMapsLink = v; onChange(); },
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── Series Card ───────────────────────────────────────────────────────────────
class _SeriesCard extends StatefulWidget {
  final SchoolSeries series;
  final ValueChanged<bool> onToggle;
  final VoidCallback onRemove, onChange;
  final ValueChanged<String> onAddClass;
  final ValueChanged<int> onRemoveClass;
  const _SeriesCard({required this.series, required this.onToggle,
      required this.onRemove, required this.onAddClass,
      required this.onRemoveClass, required this.onChange});

  @override
  State<_SeriesCard> createState() => _SeriesCardState();
}

class _SeriesCardState extends State<_SeriesCard> {
  bool _expanded = true;
  final _classCtrl = TextEditingController();

  @override
  void dispose() { _classCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final s = widget.series;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: s.isActive ? _white : _subtle,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: s.isActive ? _border : _border.withOpacity(.4)),
        boxShadow: s.isActive ? [BoxShadow(color: _ink.withOpacity(.04),
            blurRadius: 6, offset: const Offset(0, 2))] : [],
      ),
      child: Column(children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          child: Row(children: [
            // Color dot
            Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                color: s.isActive ? _terra : _border,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.name, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14,
                  color: s.isActive ? _ink : _muted)),
              if (s.code.isNotEmpty || s.description.isNotEmpty)
                Text('${s.code}${s.description.isNotEmpty ? "  ·  ${s.description}" : ""}',
                    style: const TextStyle(fontSize: 11, color: _muted)),
            ])),
            // Classes count
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _terra.withOpacity(.08), borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${s.classes.length} classe${s.classes.length != 1 ? "s" : ""}',
                  style: const TextStyle(fontSize: 11, color: _terra, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 8),
            Switch(value: s.isActive, onChanged: widget.onToggle,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                  color: _muted, size: 20),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: widget.onRemove,
              child: const Icon(Icons.delete_outline_rounded, color: _red, size: 17),
            ),
          ]),
        ),
        if (_expanded && s.isActive) ...[
          const Divider(height: 1, color: _border),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (s.classes.isEmpty)
                Text('Aucune classe — ajoutez-en ci-dessous',
                    style: TextStyle(fontSize: 11.5, color: _muted.withOpacity(.7)))
              else
                Wrap(spacing: 6, runSpacing: 6,
                  children: s.classes.asMap().entries.map((e) => _ClassChip(
                    label: e.value, onRemove: () => widget.onRemoveClass(e.key),
                  )).toList(),
                ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: SizedBox(height: 42,
                  child: TextField(
                    controller: _classCtrl,
                    style: const TextStyle(fontSize: 13, color: _ink),
                    decoration: _inputDeco(hint: 'Ajouter une classe…', icon: Icons.add_outlined),
                    onSubmitted: (v) {
                      if (v.isNotEmpty) { widget.onAddClass(v.trim()); _classCtrl.clear(); }
                    },
                  ),
                )),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    if (_classCtrl.text.isNotEmpty) {
                      widget.onAddClass(_classCtrl.text.trim());
                      _classCtrl.clear();
                    }
                  },
                  child: Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(color: _terra.withOpacity(.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.add_circle_outline, color: _terra, size: 20),
                  ),
                ),
              ]),
            ]),
          ),
        ],
      ]),
    );
  }
}

// ── DB Option Card ────────────────────────────────────────────────────────────
class _DbOptionCard extends StatelessWidget {
  final String id, title, subtitle;
  final IconData icon;
  final bool selected;
  final String? badge;
  final VoidCallback onTap;
  const _DbOptionCard({required this.id, required this.title, required this.subtitle,
      required this.icon, required this.selected, this.badge, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected ? _terra.withOpacity(.05) : _white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? _terra : _border, width: selected ? 2 : 1),
        ),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: selected ? _terra.withOpacity(.12) : _border.withOpacity(.5),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: selected ? _terra : _muted, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                  color: selected ? _terra : _ink)),
              if (badge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: _green.withOpacity(.12), borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(badge!, style: const TextStyle(fontSize: 9.5, color: _green,
                      fontWeight: FontWeight.w800)),
                ),
              ],
            ]),
            const SizedBox(height: 3),
            Text(subtitle, style: const TextStyle(fontSize: 12.5, color: _muted, height: 1.4)),
          ])),
          if (selected) const Icon(Icons.check_circle_rounded, color: _terra, size: 22),
        ]),
      ),
    );
  }
}

// ── Recap Card ────────────────────────────────────────────────────────────────
class _RecapCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<(String, String)> items;
  const _RecapCard({required this.title, required this.icon,
      required this.color, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: _ink.withOpacity(.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 30, height: 30,
            decoration: BoxDecoration(color: color.withOpacity(.1),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 15, color: color)),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800,
              fontSize: 14, color: _ink)),
        ]),
        const SizedBox(height: 10),
        const Divider(height: 1, color: _border),
        const SizedBox(height: 10),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 110,
              child: Text(item.$1, style: const TextStyle(fontSize: 12.5, color: _muted))),
            Expanded(child: Text(item.$2, style: const TextStyle(fontSize: 12.5,
                color: _ink, fontWeight: FontWeight.w600))),
          ]),
        )),
      ]),
    );
  }
}

// ── Password strength indicator ───────────────────────────────────────────────
class _PasswordStrength extends StatelessWidget {
  final String password;
  const _PasswordStrength({required this.password});

  int get _strength {
    int s = 0;
    if (password.length >= 8) s++;
    if (password.contains(RegExp(r'[A-Z]'))) s++;
    if (password.contains(RegExp(r'[0-9]'))) s++;
    if (password.contains(RegExp(r'[!@#\$&*~%^()]'))) s++;
    return s;
  }

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();
    final s = _strength;
    final color = s <= 1 ? _red : s == 2 ? _orange : s == 3 ? _gold : _green;
    final label = s <= 1 ? 'Faible' : s == 2 ? 'Moyen' : s == 3 ? 'Fort' : 'Très fort';
    return Row(children: [
      Expanded(child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: s / 4, backgroundColor: _border,
          valueColor: AlwaysStoppedAnimation(color), minHeight: 5,
        ),
      )),
      const SizedBox(width: 10),
      Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
    ]);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// UTILITY WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

class _FieldLabel extends StatelessWidget {
  final String text;
  final bool required;
  const _FieldLabel(this.text, {this.required = false});

  @override
  Widget build(BuildContext context) {
    if (!required) {
      return Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink));
    }
    return Text.rich(TextSpan(
      text: text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink),
      children: const [
        TextSpan(text: ' *', style: TextStyle(color: _red, fontWeight: FontWeight.w900)),
      ],
    ));
  }
}

class _SField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final IconData icon;
  final bool obscure, required;
  final TextInputType? keyboard;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  const _SField({required this.ctrl, required this.label, required this.hint,
      required this.icon, this.obscure = false, this.required = false,
      this.keyboard, this.validator, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _FieldLabel(label, required: required),
      const SizedBox(height: 6),
      TextFormField(
        controller: ctrl, obscureText: obscure, keyboardType: keyboard,
        validator: validator, onChanged: onChanged,
        style: const TextStyle(fontSize: 14, color: _ink),
        decoration: _inputDeco(hint: hint, icon: icon),
      ),
    ]);
  }
}

class _SectionDivider extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? sub;
  const _SectionDivider({required this.label, required this.icon, this.sub});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 36, height: 36,
        decoration: BoxDecoration(
            color: _terra.withOpacity(.08), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: _terra, size: 18)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 14, color: _ink, fontWeight: FontWeight.w800)),
        if (sub != null)
          Text(sub!, style: const TextStyle(fontSize: 11, color: _muted)),
      ])),
    ]);
  }
}

class _TwoCol extends StatelessWidget {
  final Widget left, right;
  const _TwoCol({required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w > 540) {
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: left), const SizedBox(width: 14), Expanded(child: right),
      ]);
    }
    return Column(children: [left, const SizedBox(height: 14), right]);
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TypeChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 36, padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? _terra : _white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? _terra : _border),
        ),
        child: Center(child: Text(label, style: TextStyle(
          color: selected ? _white : _ink, fontSize: 13, fontWeight: FontWeight.w600))),
      ),
    );
  }
}

class _ClassChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _ClassChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30, padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: _terra.withOpacity(.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _terra.withOpacity(.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: const TextStyle(fontSize: 12, color: _terra,
            fontWeight: FontWeight.w700)),
        const SizedBox(width: 5),
        GestureDetector(
          onTap: onRemove,
          child: const Icon(Icons.close_rounded, size: 13, color: _terra),
        ),
      ]),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _InfoBanner({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(.22)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(text,
            style: TextStyle(color: color, fontSize: 12.5, height: 1.5))),
      ]),
    );
  }
}

class _PrimaryBtn extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onTap;
  final IconData? icon;
  const _PrimaryBtn({required this.label, required this.onTap,
      required this.loading, this.icon});

  @override
  Widget build(BuildContext context) {
    final disabled = loading || onTap == null;
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 52, alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: disabled ? [_terra.withOpacity(.5), _orange.withOpacity(.5)]
                             : [_terra, _orange],
            begin: Alignment.centerLeft, end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: disabled ? [] : [
            BoxShadow(color: _terra.withOpacity(.3), blurRadius: 14, offset: const Offset(0, 5)),
          ],
        ),
        child: loading
            ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.2, color: _white))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (icon != null) ...[Icon(icon, color: _white, size: 18), const SizedBox(width: 8)],
                Text(label, style: const TextStyle(color: _white, fontSize: 15,
                    fontWeight: FontWeight.w700)),
              ]),
      ),
    );
  }
}

class _OutlineBtn extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  const _OutlineBtn({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52, alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _white, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border, width: 1.5),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (icon != null) ...[Icon(icon, size: 18, color: _terra), const SizedBox(width: 8)],
          Text(label, style: const TextStyle(color: _ink, fontSize: 14, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

// ── Painters ──────────────────────────────────────────────────────────────────
class _RingPainter extends CustomPainter {
  final double progress;
  const _RingPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = math.min(c.dx, c.dy) - 3;
    canvas.drawCircle(c, r, Paint()
      ..color = Colors.white.withOpacity(.1)
      ..strokeWidth = 3 ..style = PaintingStyle.stroke);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2,
        2 * math.pi * progress, false, Paint()
      ..color = _gold ..strokeWidth = 3
      ..style = PaintingStyle.stroke ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

class _SidebarPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withOpacity(.025)
      ..style = PaintingStyle.stroke ..strokeWidth = 0.8;
    const sp = 40.0;
    final cols = (size.width / sp).ceil() + 1;
    final rows = (size.height / sp).ceil() + 1;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final path = Path();
        for (int i = 0; i < 6; i++) {
          final a = (i * 60 - 30) * math.pi / 180;
          final x = c * sp + 14 * math.cos(a);
          final y = r * sp + 14 * math.sin(a);
          if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
        }
        path.close();
        canvas.drawPath(path, p);
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Input decoration ──────────────────────────────────────────────────────────
InputDecoration _inputDeco({required String hint, required IconData icon, Widget? suffix}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: _muted.withOpacity(.55), fontSize: 13.5),
    prefixIcon: Icon(icon, size: 18, color: _muted),
    prefixIconConstraints: const BoxConstraints.tightFor(width: 44),
    suffixIcon: suffix, isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 15),
    filled: true, fillColor: const Color(0xFFFAF7F4),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _border)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _terra, width: 1.8)),
    errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _red)),
    focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _red, width: 1.8)),
  );
}
