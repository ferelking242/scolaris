import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/countries.dart';
import '../../shared/data/features_catalog.dart' show kAppModules;

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
const _g0     = Color(0xFF040D07);
const _g1     = Color(0xFF0D3B1E);
const _g2     = Color(0xFF1B5E20);

// ── Countries & Cities ────────────────────────────────────────────────────────
const _kCountries = [
  'Afghanistan','Afrique du Sud','Algérie','Angola','Arabie Saoudite','Argentine',
  'Australie','Bénin','Belgique','Bolivie','Botswana','Brésil','Burkina Faso',
  'Burundi','Cameroun','Canada','Cap-Vert','Centrafrique','Chili','Chine',
  'Comores','Congo','Côte d\'Ivoire','Djibouti','Égypte','Érythrée','Éthiopie',
  'France','Gabon','Gambie','Ghana','Guinée','Guinée-Bissau','Guinée équatoriale',
  'Inde','Indonésie','Irak','Iran','Israël','Italie','Japon','Jordanie','Kenya',
  'Lesotho','Libéria','Libye','Madagascar','Malawi','Mali','Maroc','Mauritanie',
  'Maurice','Mexique','Mozambique','Namibie','Niger','Nigéria','Norvège','Ouganda',
  'Pays-Bas','Portugal','Qatar','RDC','Rwanda','Sénégal','Sierra Leone','Somalie',
  'Soudan','Soudan du Sud','Suisse','Tanzanie','Tchad','Togo','Tunisie','Turquie',
  'USA','Zambie','Zimbabwe',
];

const _kCitiesByCountry = <String, List<String>>{
  'Congo': ['Brazzaville','Pointe-Noire','Dolisie','Nkayi','Impfondo','Ouesso','Makoua','Owando','Sibiti'],
  'RDC': ['Kinshasa','Lubumbashi','Mbuji-Mayi','Goma','Bukavu','Kisangani','Kolwezi','Kananga','Likasi'],
  'Cameroun': ['Yaoundé','Douala','Garoua','Bamenda','Bafoussam','Ngaoundéré','Maroua','Bertoua'],
  'Sénégal': ['Dakar','Touba','Thiès','Kaolack','Ziguinchor','Saint-Louis','Mbour','Diourbel'],
  'Côte d\'Ivoire': ['Abidjan','Yamoussoukro','Bouaké','Daloa','Korhogo','San Pedro','Man'],
  'Gabon': ['Libreville','Port-Gentil','Franceville','Oyem','Lambaréné','Moanda','Tchibanga'],
  'Algérie': ['Alger','Oran','Constantine','Annaba','Blida','Tlemcen','Sétif','Batna','Sidi Bel Abbès'],
  'Maroc': ['Casablanca','Rabat','Fès','Marrakech','Tanger','Agadir','Meknès','Oujda','Kénitra'],
  'Tunisie': ['Tunis','Sfax','Sousse','Bizerte','Gabès','Kairouan','Ariana','Monastir'],
  'Nigéria': ['Lagos','Abuja','Kano','Ibadan','Port Harcourt','Benin City','Kaduna','Jos'],
  'Ghana': ['Accra','Kumasi','Tamale','Cape Coast','Sekondi-Takoradi','Sunyani'],
  'Kenya': ['Nairobi','Mombasa','Kisumu','Nakuru','Eldoret','Thika','Malindi'],
  'Burkina Faso': ['Ouagadougou','Bobo-Dioulasso','Koudougou','Banfora','Ouahigouya'],
  'Mali': ['Bamako','Ségou','Mopti','Sikasso','Gao','Kayes','Tombouctou'],
  'Togo': ['Lomé','Sokodé','Kara','Palimé','Atakpamé','Dapaong'],
  'Bénin': ['Cotonou','Porto-Novo','Parakou','Abomey','Bohicon','Kandi'],
  'Niger': ['Niamey','Zinder','Maradi','Tahoua','Agadez','Dosso'],
  'Madagascar': ['Antananarivo','Toamasina','Antsirabe','Mahajanga','Fianarantsoa'],
  'France': ['Paris','Lyon','Marseille','Toulouse','Nice','Nantes','Bordeaux','Lille','Strasbourg','Rennes','Grenoble','Montpellier'],
  'Belgique': ['Bruxelles','Anvers','Gand','Liège','Bruges','Namur','Louvain'],
  'Suisse': ['Genève','Zurich','Berne','Bâle','Lausanne','Lugano'],
  'USA': ['New York','Los Angeles','Chicago','Houston','Phoenix','Philadelphia','San Antonio'],
  'Afrique du Sud': ['Johannesburg','Le Cap','Durban','Pretoria','Port Elizabeth','Bloemfontein'],
  'Éthiopie': ['Addis-Abeba','Dire Dawa','Mekele','Gondar','Bahir Dar','Hawassa'],
  'Égypte': ['Le Caire','Alexandrie','Gizeh','Charm el-Cheikh','Louxor','Assouan'],
  'Canada': ['Toronto','Montréal','Vancouver','Calgary','Ottawa','Edmonton','Québec'],
  'Brésil': ['São Paulo','Rio de Janeiro','Brasília','Salvador','Fortaleza','Belo Horizonte'],
};

// ── School types ──────────────────────────────────────────────────────────────
class _SchoolTypeInfo {
  final String id, label, sub;
  final IconData icon;
  final bool comingSoon;
  const _SchoolTypeInfo(this.id, this.label, this.sub, this.icon, {this.comingSoon = false});
}

const _kSchoolTypes = [
  _SchoolTypeInfo('garderie',   'Garderie',         '0-6 ans',           Icons.child_friendly_outlined),
  _SchoolTypeInfo('primaire',   'Primaire',          'CP → CM2',          Icons.auto_stories_outlined),
  _SchoolTypeInfo('college',    'Collège',           '6ème → 3ème',       Icons.school_outlined),
  _SchoolTypeInfo('lycee',      'Lycée',             '2nde → Terminale',  Icons.account_balance_outlined),
  _SchoolTypeInfo('universite', 'Université',        'Licence → Doctorat',Icons.domain_outlined,            comingSoon: true),
  _SchoolTypeInfo('technique',  'Formation Pro.',    'CAP, BEP, BTS…',    Icons.engineering_outlined,       comingSoon: true),
  _SchoolTypeInfo('superieur',  'Grandes Écoles',    'CPGE, Écoles…',     Icons.workspace_premium_outlined, comingSoon: true),
  _SchoolTypeInfo('special',    'Éducation Spéc.',   'Besoins spéciaux',  Icons.accessibility_new_outlined, comingSoon: true),
];

// ── Dial codes ────────────────────────────────────────────────────────────────
class _DialCode {
  final String flag, code, country;
  const _DialCode(this.flag, this.code, this.country);
}

const _kDialCodes = [
  _DialCode('🇨🇬','+242','Congo'), _DialCode('🇨🇩','+243','RDC'),
  _DialCode('🇨🇲','+237','Cameroun'), _DialCode('🇸🇳','+221','Sénégal'),
  _DialCode('🇨🇮','+225','Côte d\'Ivoire'), _DialCode('🇬🇦','+241','Gabon'),
  _DialCode('🇧🇯','+229','Bénin'), _DialCode('🇧🇫','+226','Burkina Faso'),
  _DialCode('🇲🇱','+223','Mali'), _DialCode('🇬🇳','+224','Guinée'),
  _DialCode('🇹🇬','+228','Togo'), _DialCode('🇳🇪','+227','Niger'),
  _DialCode('🇲🇬','+261','Madagascar'), _DialCode('🇧🇮','+257','Burundi'),
  _DialCode('🇷🇼','+250','Rwanda'), _DialCode('🇩🇿','+213','Algérie'),
  _DialCode('🇲🇦','+212','Maroc'), _DialCode('🇹🇳','+216','Tunisie'),
  _DialCode('🇳🇬','+234','Nigeria'), _DialCode('🇬🇭','+233','Ghana'),
  _DialCode('🇰🇪','+254','Kenya'), _DialCode('🇹🇿','+255','Tanzanie'),
  _DialCode('🇫🇷','+33','France'), _DialCode('🇧🇪','+32','Belgique'),
  _DialCode('🇨🇭','+41','Suisse'), _DialCode('🇺🇸','+1','USA'),
  _DialCode('🇬🇧','+44','Royaume-Uni'),
];

// ── Education systems ─────────────────────────────────────────────────────────
class _SysInfo {
  final String id, title, flag, origin, countries, language;
  final List<String> structure, diplomas;
  final List<String> compatibleTypes;
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
    structure: ['Garderie / Maternelle (3 ans): PS → MS → GS','Primaire (6 ans): CP → CE1 → CE2 → CM1 → CM2','Collège (4 ans): 6e → 5e → 4e → 3e','Lycée (3 ans): 2nde → 1re → Terminale','Université: Classique ou LMD'],
    diplomas: ['CEPD (Fin Primaire)', 'BEPC (Fin Collège)', 'BAC : A, C, D, F, G, TI…'],
    compatibleTypes: ['garderie','primaire','college','lycee','superieur'],
  ),
  _SysInfo(
    id: 'anglophone', title: 'Anglophone', flag: '🇬🇧',
    origin: 'Héritage du système britannique, adopté par les pays anglophones et certaines régions bilingues.',
    countries: 'Nigeria, Ghana, Kenya, Tanzanie, Cameroun (NW/SW), Ouganda, Zimbabwe…',
    language: 'Anglais',
    structure: ['Nursery / Kindergarten (2-3 ans)','Primary (6 ans): Primary 1 → 6','Junior Secondary (3 ans): JSS 1 → 3','Senior Secondary (3 ans): SSS 1 → 3','University: Bachelor → Master → PhD'],
    diplomas: ['FSLC (Primaire)', 'BECE/JSCE (Collège)', 'GCE O-Level, A-Level, WAEC, NECO'],
    compatibleTypes: ['garderie','primaire','college','lycee','superieur'],
  ),
  _SysInfo(
    id: 'lmd', title: 'Système LMD', flag: '🎓',
    origin: 'Processus de Bologne (Europe, 1999). Adopté progressivement par les universités africaines pour harmoniser les diplômes.',
    countries: 'Europe + Maroc, Algérie, Tunisie, Sénégal, Cameroun, Congo, RDC…',
    language: 'Français ou Anglais',
    structure: ['Licence (3 ans): L1 → L2 → L3 (Bac+3)','Master (2 ans): M1 → M2 (Bac+5)','Doctorat (3 ans min): D1 → D2 → D3 (Bac+8)'],
    diplomas: ['Licence (Bac+3)', 'Master Recherche / Pro (Bac+5)', 'Doctorat / PhD (Bac+8)'],
    compatibleTypes: ['universite','superieur'],
  ),
  _SysInfo(
    id: 'technique', title: 'Technique / Professionnel', flag: '⚙️',
    origin: 'Formation professionnelle orientée métier, reconnue internationalement.',
    countries: 'International — adapté localement dans chaque pays',
    language: 'Français ou Anglais',
    structure: ['CAP (2 ans): CAP 1 → CAP 2','BEP (2 ans): BEP 1 → BEP 2','BTS (2 ans): BTS 1 → BTS 2','Licence Professionnelle (1 an après BTS)'],
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
  String name, countryFlag, dialCode, phone, country, city, address, googleMapsLink;
  SchoolBranch({this.name='',this.countryFlag='🇨🇬',this.dialCode='+242',this.phone='',this.country='',this.city='',this.address='',this.googleMapsLink=''});
}

class SchoolSeries {
  String name, code, description;
  bool isActive;
  List<String> classes;
  SchoolSeries({required this.name, required this.code, this.description='', this.isActive=true, List<String>? classes}) : classes = classes ?? [];
}

// ── Predefined banner themes ──────────────────────────────────────────────────
const _kBannerThemes = [
  [Color(0xFF3E1A00), Color(0xFF8B1A00)],
  [Color(0xFF050F08), Color(0xFF1B5E20)],
  [Color(0xFF0D2244), Color(0xFF1565C0)],
  [Color(0xFF1A0030), Color(0xFF6A0DAD)],
  [Color(0xFF1A1A00), Color(0xFF827717)],
  [Color(0xFF002020), Color(0xFF00695C)],
];

// ── Predefined avatar colors ──────────────────────────────────────────────────
const _kAvatarColors = [
  [Color(0xFF8B1A00), Color(0xFFD4540A)],
  [Color(0xFF1B5E20), Color(0xFF43A047)],
  [Color(0xFF0D47A1), Color(0xFF1976D2)],
  [Color(0xFF4A148C), Color(0xFF7B1FA2)],
  [Color(0xFF004D40), Color(0xFF00796B)],
  [Color(0xFF263238), Color(0xFF455A64)],
];

// ── Default series by system + types ─────────────────────────────────────────
List<SchoolSeries> _defaultSeries(String system, Set<String> types) {
  final hasPrimaire = types.contains('primaire') || types.contains('garderie');
  final hasCollege  = types.contains('college');
  final hasLycee    = types.contains('lycee');
  final hasUniv     = types.contains('universite') || types.contains('superieur');
  final hasTech     = types.contains('technique');
  final list        = <SchoolSeries>[];

  if (system == 'francophone') {
    if (hasPrimaire) {
      list.addAll([
        SchoolSeries(name:'Maternelle',code:'MAT',description:'PS, MS, GS',classes:['PS','MS','GS']),
        SchoolSeries(name:'Primaire',code:'PRI',description:'CP à CM2',classes:['CP','CE1','CE2','CM1','CM2']),
      ]);
    }
    if (hasCollege) {
      list.add(SchoolSeries(name:'Collège',code:'COL',description:'6e à 3e',classes:['6e','5e','4e','3e']));
    }
    if (hasLycee) {
      list.addAll([
        SchoolSeries(name:'Seconde',code:'2nde',description:'Tronc commun',classes:['2nde A','2nde C']),
        SchoolSeries(name:'Première',code:'1re',description:'Séries A, C, D',classes:['1re A','1re C','1re D']),
        // F3/F4 (électrotechnique, électronique…) appartiennent aux lycées
        // techniques, pas au lycée général — retirées d'ici.
        SchoolSeries(name:'Terminale',code:'Tle',description:'Baccalauréat',classes:['Tle A','Tle C','Tle D']),
      ]);
    }
  } else if (system == 'anglophone') {
    if (hasPrimaire) {
      list.add(SchoolSeries(name:'Primary',code:'PRI',description:'Class 1 to 6',classes:['Class 1','Class 2','Class 3','Class 4','Class 5','Class 6']));
    }
    if (hasCollege) {
      list.add(SchoolSeries(name:'Junior Secondary',code:'JSS',description:'JSS 1 to 3',classes:['JSS 1','JSS 2','JSS 3']));
    }
    if (hasLycee) {
      list.add(SchoolSeries(name:'Senior Secondary',code:'SSS',description:'SSS 1 to 3',classes:['SSS 1 Science','SSS 2 Science','SSS 3 Science','SSS 1 Arts','SSS 2 Arts','SSS 3 Arts']));
    }
  } else if (system == 'lmd' && hasUniv) {
    list.addAll([
      SchoolSeries(name:'Licence',code:'L',description:'Bac+3',classes:['L1','L2','L3']),
      SchoolSeries(name:'Master',code:'M',description:'Bac+5',classes:['M1','M2']),
      SchoolSeries(name:'Doctorat',code:'D',description:'Bac+8',classes:['D1','D2','D3']),
    ]);
  } else if (system == 'technique' || hasTech) {
    list.addAll([
      SchoolSeries(name:'CAP',code:'CAP',description:'Certificat d\'Aptitude Pro',classes:['CAP 1','CAP 2']),
      SchoolSeries(name:'BEP',code:'BEP',description:'Brevet d\'Études Pro',classes:['BEP 1','BEP 2']),
      SchoolSeries(name:'BTS',code:'BTS',description:'Brevet de Technicien Sup.',classes:['BTS 1','BTS 2']),
    ]);
  }
  if (list.isEmpty) {
    list.add(SchoolSeries(name:'Classe générale',code:'GEN',classes:['Classe A']));
  }
  return list;
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class SchoolRegistrationScreen extends StatefulWidget {
  const SchoolRegistrationScreen({super.key});
  @override
  State<SchoolRegistrationScreen> createState() => _SchoolRegistrationScreenState();
}

class _SchoolRegistrationScreenState extends State<SchoolRegistrationScreen> {
  int _step = 0;
  bool _submitting = false;
  String? _globalError;
  bool _showRightPanel = true;

  // ── Step 1 — École ──
  final _s1Form    = GlobalKey<FormState>();
  final _s1Name    = TextEditingController();
  final _s1Country = TextEditingController(text: 'Congo');
  final _s1City    = TextEditingController();
  final _s1Address = TextEditingController();
  final _s1Email   = TextEditingController();
  final _s1Phone   = TextEditingController();
  String _s1DialCode = '+242', _s1DialFlag = '🇨🇬';
  Set<String> _types = {'lycee'};

  /// Modules choisis par l'école (cf. `kAppModules`) — décide ce qui apparaît
  /// dans son tableau de bord ensuite (`AdminHome`). Tout coché par défaut :
  /// c'est un DÉ-cochage, pas une découverte à l'aveugle.
  Set<String> _modules = kAppModules.map((m) => m.id).toSet();

  // ── Step 2 — Administrateur ──
  final _s2Form   = GlobalKey<FormState>();
  final _s2Name   = TextEditingController();
  final _s2Email  = TextEditingController();
  final _s2Phone  = TextEditingController();
  final _s2Pass   = TextEditingController();
  final _s2PassConfirm = TextEditingController();
  String _s2DialCode = '+242', _s2DialFlag = '🇨🇬';
  bool _s2Obscure = true;
  bool _s2ObscureConfirm = true;

  // Système éducatif et structure de classes ne sont plus des étapes : on
  // prend le défaut francophone et on génère les séries en silence à la
  // soumission (modifiables ensuite dans le dashboard) — l'inscription ne
  // doit pas demander des choix que l'école peut faire plus tard.
  static const _s3System = 'francophone';
  List<SchoolSeries> _series = [];

  static const _stepLabels = ['École', 'Administrateur', 'Récapitulatif'];

  @override
  void initState() { super.initState(); _series = _defaultSeries(_s3System, _types); }

  @override
  void dispose() {
    for (final c in [
      _s1Name,_s1Country,_s1City,_s1Address,_s1Email,_s1Phone,
      _s2Name,_s2Email,_s2Phone,_s2Pass,_s2PassConfirm,
    ]) { c.dispose(); }
    super.dispose();
  }

  bool _validateStep() {
    if (_step == 0) {
      if (_types.isEmpty) { setState(() => _globalError = 'Sélectionnez au moins un type d\'établissement.'); return false; }
      // Le pays doit être RECONNU : la devise, le système éducatif et le
      // catalogue des niveaux se calculent tous à partir de son code ISO. Un
      // nom non reconnu ferait échouer l'enregistrement en base
      // (contrainte schools_country_iso), avec un message incompréhensible.
      if (countryCodeOf(_s1Country.text) == null) {
        setState(() => _globalError =
            'Pays non reconnu : choisissez-le dans la liste proposée.');
        return false;
      }
      return _s1Form.currentState?.validate() ?? false;
    }
    if (_step == 1) {
      if (!(_s2Form.currentState?.validate() ?? false)) return false;
      if (_s2Pass.text != _s2PassConfirm.text) {
        setState(() => _globalError = 'Les mots de passe ne correspondent pas.');
        return false;
      }
      return true;
    }
    return true;
  }

  void _next() {
    setState(() => _globalError = null);
    if (!_validateStep()) return;
    if (_step == 1) _series = _defaultSeries(_s3System, _types);
    setState(() => _step = (_step + 1).clamp(0, 2));
  }

  void _prev() => setState(() { _step = (_step - 1).clamp(0, 2); _globalError = null; });

  // Remplissage rapide pour les tests manuels (debug uniquement).
  void _fillTestData() {
    final n = DateTime.now().millisecondsSinceEpoch % 100000;
    setState(() {
      _types = {'lycee'};
      _s1Name.text    = 'École Test $n';
      _s1Country.text = 'Congo';
      _s1City.text    = 'Brazzaville';
      _s1Address.text = 'Avenue de la Paix, $n';
      _s1Email.text   = 'contact.test$n@scolaris.dev';
      _s1Phone.text   = '0600000$n'.substring(0, 9);

      _s2Name.text  = 'Fondateur Test $n';
      _s2Email.text = 'admin.test$n@scolaris.dev';
      _s2Phone.text = '0611111$n'.substring(0, 9);
      _s2Pass.text  = 'Test1234!';
      _s2PassConfirm.text = 'Test1234!';

      _series = _defaultSeries(_s3System, _types);
    });
  }

  Future<void> _submit() async {
    setState(() { _submitting = true; _globalError = null; });
    final sb       = Supabase.instance.client;
    final schoolId = const Uuid().v4();
    var schoolCreated = false;
    try {
      // Le nom seul ne garantit pas l'unicité (plusieurs écoles peuvent
      // partager le même nom) — on suffixe avec un fragment de l'id pour
      // éviter toute collision sur schools_code_key / schools_slug_key.
      final baseSlug = _s1Name.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
      final slug     = '$baseSlug-${schoolId.substring(0, 8)}';

      await sb.from('schools').insert({
        'id'          : schoolId,
        'name'        : _s1Name.text.trim(),
        'code'        : slug,
        'slug'        : slug,
        // La base impose un code ISO (schools_country_iso). Le champ propose
        // les NOMS — bonne ergonomie —, on convertit à l'enregistrement.
        'country'     : countryCodeOf(_s1Country.text),
        'city'        : _s1City.text.trim(),
        'address'     : _s1Address.text.trim(),
        'contact_email': _s1Email.text.trim().isEmpty ? null : _s1Email.text.trim(),
        'contact_phone': _s1Phone.text.trim().isEmpty ? null : '$_s1DialCode${_s1Phone.text.trim()}',
        // Une école auto-inscrite depuis le site vitrine reste inactive tant
        // que l'équipe Scolaris ne l'a pas validée (cf. platform_schools_page,
        // onglet « À valider ») — le compte du fondateur existe déjà mais ne
        // peut pas se connecter avant (SupabaseAuthSource._fetchProfile).
        'is_active'   : false,
        'plan_type'   : 'free', // legacy, non utilisé par l'app (voir subscriptions.plan_code)
        'db_mode'     : 'central',
        'metadata'    : {
          'types'              : _types.toList(),
          'educational_system' : _s3System,
          // Modules complémentaires choisis à l'inscription (Finances/
          // Présences/Inscriptions) — décide ce qui apparaît dans le tableau
          // de bord de l'école (cf. AdminHome, filtrage par module).
          // 'academic' est toujours ajouté : socle du produit, jamais un
          // choix, mais conservé dans la liste pour compat avec les écrans
          // élève/enseignant/parent qui testent encore sa présence.
          'modules'            : ['academic', ..._modules],
        },
      });
      schoolCreated = true;

      // Compte de connexion du fondateur (admin de l'école).
      // L'école existe déjà ci-dessus → le trigger handle_new_user peut créer
      // users + profiles (FK school_id satisfaite) à partir des métadonnées.
      // Le trigger trg_new_school_trial (DB) crée automatiquement la ligne
      // subscriptions (essai 14j), sur l'offre déduite de metadata.modules —
      // cf. _planForModuleCount() ci-dessus, même calcul que le bandeau de
      // prix affiché à l'écran précédent.
      await sb.auth.signUp(
        email: _s2Email.text.trim(),
        password: _s2Pass.text,
        data: {
          'full_name' : _s2Name.text.trim(),
          'role'      : 'admin',
          'school_id' : schoolId,
        },
      );

      await sb.from('school_founders').insert({
        'school_id' : schoolId,
        'full_name' : _s2Name.text.trim(),
        'email'     : _s2Email.text.trim(),
        'phone'     : _s2Phone.text.trim().isEmpty ? null : '$_s2DialCode${_s2Phone.text.trim()}',
        'role_label': 'Fondateur',
      });

      for (final s in _series.where((s) => s.isActive)) {
        final sId = const Uuid().v4();
        await sb.from('school_series').insert({
          'id'       : sId,
          'school_id': schoolId,
          'name'     : s.name,
          'code'     : s.code,
          'is_active': true,
        });
        for (final cl in s.classes) {
          await sb.from('school_classes').insert({
            'school_id': schoolId,
            'name'     : cl,
            'level'    : s.name,
          });
        }
      }

      if (mounted) _showSuccess(schoolId);
    } catch (e) {
      if (schoolCreated) {
        // Étape ultérieure échouée (email déjà utilisé, réseau, RLS…) :
        // on retire l'école pour ne pas laisser d'enregistrement orphelin
        // sans compte admin / structure associée.
        try {
          await sb.from('schools').delete().eq('id', schoolId);
        } catch (_) {
          // best-effort : si le rollback échoue aussi, on laisse l'erreur
          // d'origine remonter — pas de nouvelle tentative silencieuse.
        }
      }
      setState(() => _globalError = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _friendlyError(Object e) {
    if (e is AuthException) {
      final m = e.message.toLowerCase();
      if (m.contains('already registered') || m.contains('already exists')) {
        return 'Cet email administrateur est déjà utilisé par un autre compte.';
      }
      return 'Erreur de création du compte administrateur : ${e.message}';
    }
    if (e is PostgrestException) {
      if (e.code == '23505') {
        return 'Une école avec des informations identiques existe déjà. Réessayez.';
      }
      if (e.code == '42501' || (e.message.toLowerCase().contains('row-level security'))) {
        return 'Accès refusé par la base de données (permissions). Contactez le support.';
      }
      if (e.code == '23502') {
        return 'Un champ obligatoire est manquant côté serveur. Contactez le support.';
      }
      return 'Erreur serveur (${e.code ?? '?'}) : ${e.message}';
    }
    return 'Une erreur est survenue. Vérifiez votre connexion et réessayez.';
  }

  void _showSuccess(String id) {
    showDialog(
      context: context, barrierDismissible: false,
      builder: (dialogCtx) {
        final screenH = MediaQuery.sizeOf(dialogCtx).height;
        final isShort = screenH < 700;
        final lottieSize = isShort ? 72.0 : 120.0;
        final outerPad = isShort ? 20.0 : 36.0;
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: screenH - 48, maxWidth: 460),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(outerPad),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            Lottie.asset('assets/lottie/celebration.json', width: lottieSize, height: lottieSize,
                repeat: false, errorBuilder: (_,__,___) => Container(width:lottieSize * .67,height:lottieSize * .67,
                    decoration: BoxDecoration(color:_green.withOpacity(.1),shape:BoxShape.circle),
                    child: const Icon(Icons.check_circle_rounded,color:_green,size:48))),
            SizedBox(height: isShort ? 12 : 20),
            const Text('École créée avec succès !', textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _ink)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _gold.withOpacity(.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _gold.withOpacity(.3)),
              ),
              child: Column(children: [
                const Icon(Icons.hourglass_top_rounded, color: _gold, size: 24),
                const SizedBox(height: 6),
                const Text('Validation par notre équipe',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: _ink)),
                const SizedBox(height: 4),
                const Text(
                  'Notre équipe valide votre établissement avant l\'ouverture '
                  'de l\'accès — généralement sous 24 heures ouvrées. Vous '
                  'recevrez un email dès que votre compte est activé.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, height: 1.4, color: _muted),
                ),
              ]),
            ),
            const SizedBox(height: 8),
            Text('ID école : ${id.substring(0, 8)}…', textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: _muted)),
            SizedBox(height: isShort ? 14 : 24),
            SizedBox(width: double.infinity,
              // Le compte fondateur est déjà connecté (sb.auth.signUp() a
              // ouvert la session) — pas besoin de repasser par /login : le
              // routeur (isSchoolPendingValidation) l'envoie directement sur
              // l'écran d'attente de validation.
              child: _PrimaryBtn(label: 'Continuer', loading: false,
                  onTap: () { Navigator.pop(context); context.go('/'); })),
              ]),
            ),
          ),
        );
      },
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width > 860;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _cream,
        body: SafeArea(
          child: Stack(children: [
            isWide ? _buildWide() : _buildNarrow(),
            if (kDebugMode)
              Positioned(
                top: 12, right: 12,
                child: FloatingActionButton.extended(
                  heroTag: 'fillTestData',
                  backgroundColor: _gold,
                  onPressed: _fillTestData,
                  icon: const Icon(Icons.bolt_rounded, color: Colors.white),
                  label: const Text('Remplir (test)', style: TextStyle(color: Colors.white)),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _buildWide() {
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // ── Left sidebar ───────────────────────────────────────────────────────
      SizedBox(
        width: 250,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_g0, _g1, _g2],
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
            ),
          ),
          child: Stack(children: [
            Positioned.fill(child: CustomPaint(painter: _HexPatternPainter())),
            Column(children: [
              const SizedBox(height: 36),
              _SidebarLogo(),
              const SizedBox(height: 24),
              _StepProgressRing(current: _step, total: _stepLabels.length),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  itemCount: _stepLabels.length,
                  itemBuilder: (_, i) => _SidebarStep(
                    index: i, label: _stepLabels[i], current: _step, total: _stepLabels.length,
                    onTap: i <= _step ? () => setState(() { _step = i; _globalError = null; }) : null,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _white.withOpacity(.04),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _white.withOpacity(.08)),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.shield_outlined, size: 11, color: _gold.withOpacity(.6)),
                    const SizedBox(width: 6),
                    Text('Données sécurisées SSL',
                        style: TextStyle(color: _white.withOpacity(.38), fontSize: 10.5)),
                  ]),
                ),
              ),
            ]),
          ]),
        ),
      ),

      // ── Main content ────────────────────────────────────────────────────────
      Expanded(
        child: ClipRRect(
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(22)),
          child: Container(
            color: _cream,
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(
                child: Column(children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: _buildStepContent(),
                    ),
                  ),
                  _BottomNav(
                    step: _step, total: _stepLabels.length,
                    onPrev: _step > 0 ? _prev : null,
                    onNext: _step < 2 ? _next : null,
                    onSubmit: _step == 2 ? _submit : null,
                    submitting: _submitting, error: _globalError,
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    ]);
  }

  Widget _buildNarrow() {
    return Column(children: [
      Expanded(child: SingleChildScrollView(child: _buildStepContent())),
      _BottomNav(
        step: _step, total: _stepLabels.length,
        onPrev: _step > 0 ? _prev : null,
        onNext: _step < 2 ? _next : null,
        onSubmit: _step == 2 ? _submit : null,
        submitting: _submitting, error: _globalError,
      ),
    ]);
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 0: return _buildStep1();
      case 1: return _buildStep2();
      case 2: return _buildStep3();
      default: return const SizedBox.shrink();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 1 — Informations École
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildStep1() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _StepHero(
        lottie: 'assets/lottie/school_building.json',
        icon: Icons.business_outlined,
        title: 'Informations de l\'école',
        subtitle: 'Renseignez les données officielles de votre établissement scolaire.',
        onBack: () => context.go('/login'),
        step: _step, total: _stepLabels.length,
      ),

      Padding(
        padding: const EdgeInsets.fromLTRB(32, 28, 32, 0),
        child: Form(
          key: _s1Form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── Types d'établissement ───────────────────────────────────────
            _SectionDivider(label: 'Type(s) d\'établissement', icon: Icons.category_outlined,
                sub: 'Sélection multiple — ex : Collège + Lycée'),
            const SizedBox(height: 12),
            _SchoolTypeGrid(
              selected: _types,
              onToggle: (id) => setState(() {
                if (_types.contains(id)) { if (_types.length > 1) _types.remove(id); }
                else { _types.add(id); }
              }),
            ),
            if (_globalError != null && _types.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _InfoBanner(icon: Icons.warning_amber_rounded, color: _red, text: _globalError!),
              ),
            const SizedBox(height: 28),

            // ── Identité ────────────────────────────────────────────────────
            _SectionDivider(label: 'Identité de l\'école', icon: Icons.school_outlined),
            const SizedBox(height: 14),
            _SField(ctrl: _s1Name, label: 'Nom officiel', required: true,
                hint: 'Collège Saint-Joseph', icon: Icons.school_outlined,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Nom requis';
                  if (v.trim().length < 3) return 'Minimum 3 caractères';
                  return null;
                }),
            const SizedBox(height: 28),

            // ── Localisation ────────────────────────────────────────────────
            _SectionDivider(label: 'Localisation', icon: Icons.location_on_outlined),
            const SizedBox(height: 14),
            _TwoCol(
              left: _CountryField(
                ctrl: _s1Country, label: 'Pays', required: true,
                onChanged: (v) => setState(() { _s1City.clear(); }),
              ),
              right: _CityField(
                ctrl: _s1City, label: 'Ville principale', required: true,
                country: _s1Country.text,
              ),
            ),
            const SizedBox(height: 14),
            _SField(ctrl: _s1Address, label: 'Adresse postale', required: true,
                hint: 'Rue Pasteur, Quartier Moungali…', icon: Icons.map_outlined,
                validator: (v) => (v?.trim().isEmpty ?? true) ? 'Adresse requise' : null),
            const SizedBox(height: 28),

            // ── Contact ──────────────────────────────────────────────────────
            _SectionDivider(label: 'Contacts officiels', icon: Icons.contact_phone_outlined),
            const SizedBox(height: 14),
            _TwoCol(
              left: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _FieldLabel('Téléphone principal'),
                const SizedBox(height: 6),
                _PhoneRow(flag: _s1DialFlag, dialCode: _s1DialCode, ctrl: _s1Phone,
                    onDialTap: () => _pickDialCode(onPick: (f,c) => setState((){_s1DialFlag=f;_s1DialCode=c;}))),
              ]),
              right: _SField(ctrl: _s1Email, label: 'Email officiel',
                  hint: 'contact@ecole.com', icon: Icons.mail_outline,
                  keyboard: TextInputType.emailAddress),
            ),
            const SizedBox(height: 28),

            // ── Modules ──────────────────────────────────────────────────────
            _SectionDivider(label: 'Ce que vous voulez gérer', icon: Icons.widgets_outlined,
                sub: 'Notes, bulletins et emploi du temps sont toujours inclus. '
                    'Décochez les modules complémentaires dont vous n\'avez pas besoin '
                    '— modifiable plus tard dans les paramètres.'),
            const SizedBox(height: 12),
            _ModulesGrid(
              selected: _modules,
              onToggle: (id) => setState(() {
                if (_modules.contains(id)) { _modules.remove(id); } else { _modules.add(id); }
              }),
            ),
            const SizedBox(height: 14),
            _PricePreviewBanner(moduleCount: _modules.length),
            const SizedBox(height: 28),
          ]),
        ),
      ),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 2 — Compte Administrateur
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildStep2() {
    final initials = _s2Name.text.trim().split(' ').where((w) => w.isNotEmpty).take(2).map((w) => w[0]).join().toUpperCase();
    final dispInitials = initials.isNotEmpty ? initials : 'AD';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _StepHero(
        lottie: 'assets/lottie/admin.json',
        icon: Icons.person_outline_rounded,
        title: 'Compte administrateur',
        subtitle: 'Ce compte sera le fondateur avec accès total à la plateforme.',
        onBack: _prev,
        step: _step, total: _stepLabels.length,
      ),

      Padding(
        padding: const EdgeInsets.fromLTRB(32, 28, 32, 0),
        child: Form(
          key: _s2Form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            Center(
              child: Container(
                width: 84, height: 84,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_terra, _orange]),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(.12), blurRadius: 12)],
                ),
                child: Center(child: Text(dispInitials,
                    style: const TextStyle(color: _white, fontSize: 28, fontWeight: FontWeight.w900))),
              ),
            ),
            const SizedBox(height: 20),

            _InfoBanner(
              icon: Icons.info_outline_rounded, color: _gold,
              text: 'Ce compte aura automatiquement le rôle "Fondateur" avec accès total. '
                  'Vous pourrez modifier les permissions depuis le panneau d\'administration.',
            ),
            const SizedBox(height: 24),

            // ── Identité ────────────────────────────────────────────────────
            _SectionDivider(label: 'Informations personnelles', icon: Icons.badge_outlined),
            const SizedBox(height: 14),
            _SField(ctrl: _s2Name, label: 'Nom complet', required: true,
                hint: 'Jean-Baptiste Ondo', icon: Icons.badge_outlined,
                validator: (v) => (v?.trim().isEmpty ?? true) ? 'Nom requis' : null,
                onChanged: (_) => setState(() {})),
            const SizedBox(height: 24),

            // ── Coordonnées ─────────────────────────────────────────────────
            _SectionDivider(label: 'Coordonnées de connexion', icon: Icons.contact_mail_outlined),
            const SizedBox(height: 14),
            _TwoCol(
              left: _SField(ctrl: _s2Email, label: 'Email', required: true,
                  hint: 'admin@ecole.com', icon: Icons.mail_outline,
                  keyboard: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Email requis';
                    if (!v.contains('@') || !v.contains('.')) return 'Email invalide';
                    return null;
                  }),
              right: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _FieldLabel('Téléphone'),
                const SizedBox(height: 6),
                _PhoneRow(flag: _s2DialFlag, dialCode: _s2DialCode, ctrl: _s2Phone,
                    onDialTap: () => _pickDialCode(onPick: (f,c) => setState((){_s2DialFlag=f;_s2DialCode=c;}))),
              ]),
            ),
            const SizedBox(height: 14),
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
                  icon: Icon(_s2Obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 18, color: _muted),
                  onPressed: () => setState(() => _s2Obscure = !_s2Obscure),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _PasswordStrength(password: _s2Pass.text),
            const SizedBox(height: 14),
            _FieldLabel('Confirmer le mot de passe', required: true),
            const SizedBox(height: 6),
            TextFormField(
              controller: _s2PassConfirm, obscureText: _s2ObscureConfirm,
              validator: (v) => (v != _s2Pass.text) ? 'Les mots de passe ne correspondent pas' : null,
              style: const TextStyle(fontSize: 14, color: _ink),
              decoration: _inputDeco(
                hint: '••••••••', icon: Icons.lock_outline_rounded,
                suffix: IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                  icon: Icon(_s2ObscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 18, color: _muted),
                  onPressed: () => setState(() => _s2ObscureConfirm = !_s2ObscureConfirm),
                ),
              ),
            ),
            const SizedBox(height: 28),
          ]),
        ),
      ),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 3 — Récapitulatif
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildStep3() {
    final isWide = MediaQuery.sizeOf(context).width > 860;
    final moduleLabels = _modules.isEmpty
        ? 'Aucun (uniquement les fonctionnalités essentielles)'
        : _modules.map((id) => kAppModules.firstWhere((m) => m.id == id).label).join(' · ');

    final schoolCard = _RecapCard(title: 'Informations école', icon: Icons.business_outlined, color: _terra,
      items: [
        ('Nom', _s1Name.text.trim()),
        ('Pays / Ville', '${_s1Country.text.trim()} — ${_s1City.text.trim()}'),
        ('Adresse', _s1Address.text.trim()),
        if (_s1Email.text.isNotEmpty) ('Email', _s1Email.text.trim()),
        if (_s1Phone.text.isNotEmpty) ('Tél.', '$_s1DialCode ${_s1Phone.text.trim()}'),
      ]);
    final typesCard = _RecapCard(title: 'Types d\'établissement', icon: Icons.category_outlined, color: _orange,
      items: [('Types', _types.map((t) => _kSchoolTypes.firstWhere((st) => st.id == t).label).join(' · '))]);
    final plan = _planForModuleCount(_modules.length);
    final modulesCard = _RecapCard(title: 'Modules activés', icon: Icons.widgets_outlined, color: _gold,
      items: [
        ('Modules', moduleLabels),
        ('Offre', '${plan.name} — ${plan.priceMonthly} F/mois (essai 14j gratuit)'),
      ]);
    final adminCard = _RecapCard(title: 'Administrateur', icon: Icons.person_outline_rounded, color: _green,
      items: [
        ('Nom', _s2Name.text.trim()),
        ('Email', _s2Email.text.trim()),
        ('Rôle', 'Fondateur — accès total'),
      ]);

    final content = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _InfoBanner(
        icon: Icons.info_outline_rounded, color: _green,
        text: 'Vérifiez toutes les informations avant de créer votre école. '
            'Cliquez sur "Créer mon école" pour finaliser.',
      ),
      const SizedBox(height: 20),

      if (isWide)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(children: [
            schoolCard, const SizedBox(height: 12), typesCard,
          ])),
          const SizedBox(width: 16),
          Expanded(child: Column(children: [
            adminCard, const SizedBox(height: 12), modulesCard,
          ])),
        ])
      else
        Column(children: [
          schoolCard, const SizedBox(height: 10), typesCard,
          const SizedBox(height: 10), adminCard,
          const SizedBox(height: 10), modulesCard,
        ]),
    ]);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _StepHero(
        lottie: 'assets/lottie/success.json',
        icon: Icons.fact_check_outlined,
        title: 'Récapitulatif final',
        subtitle: 'Vérifiez toutes les informations avant de créer votre école.',
        onBack: _prev,
        step: _step, total: _stepLabels.length,
      ),
      Padding(padding: const EdgeInsets.fromLTRB(32, 28, 32, 28), child: content),
    ]);
  }

  // ── Sheets / dialogs ──────────────────────────────────────────────────────
  void _pickDialCode({required void Function(String flag, String code) onPick}) {
    showModalBottomSheet(
      context: context, backgroundColor: _cream, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: .55, maxChildSize: .85, minChildSize: .3, expand: false,
        builder: (ctx, scroll) => Column(children: [
          Container(margin: const EdgeInsets.symmetric(vertical: 10), width: 36, height: 4,
              decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2))),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Text('Indicatif pays', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
          ),
          Expanded(child: ListView.builder(
            controller: scroll, itemCount: _kDialCodes.length,
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
// STEP HERO — replaces TopBar + StepHeader
// ═════════════════════════════════════════════════════════════════════════════
class _StepHero extends StatelessWidget {
  final String lottie;
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onBack;
  final int step, total;
  const _StepHero({required this.lottie, required this.icon, required this.title,
      required this.subtitle, required this.onBack, required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width > 860;
    return Container(
      constraints: BoxConstraints(minHeight: isWide ? 200 : 160),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_g0, _g1, _g2],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      child: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _HexPatternPainter())),
        // Lottie animation (right side)
        if (isWide)
          Positioned(right: 20, top: 0, bottom: 0,
            child: Lottie.asset(lottie, width: 180, fit: BoxFit.contain,
                errorBuilder: (_,__,___) => const SizedBox.shrink())),
        // Content
        Padding(
          padding: EdgeInsets.fromLTRB(28, 22, isWide ? 220 : 28, 22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center, children: [
            // Back + progress
            Row(children: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: onBack,
                  child: Container(
                    height: 34, width: 34,
                    decoration: BoxDecoration(
                      color: _white.withOpacity(.12),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: _white.withOpacity(.2)),
                    ),
                    child: const Icon(Icons.arrow_back_rounded, color: _white, size: 17),
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _white.withOpacity(.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _white.withOpacity(.15)),
                ),
                child: Text('${step + 1} / $total',
                    style: const TextStyle(color: _white, fontSize: 11.5, fontWeight: FontWeight.w800)),
              ),
            ]),
            const SizedBox(height: 16),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (step + 1) / total,
                backgroundColor: _white.withOpacity(.12),
                valueColor: const AlwaysStoppedAnimation(_gold), minHeight: 4,
              ),
            ),
            const SizedBox(height: 16),
            // Title
            Text(title, style: const TextStyle(color: _white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -.3)),
            const SizedBox(height: 5),
            Text(subtitle, style: TextStyle(color: _white.withOpacity(.7), fontSize: 12.5, height: 1.4)),
          ]),
        ),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// RIGHT ACTIONS PANEL — Step 4
// ═════════════════════════════════════════════════════════════════════════════
class _RightActionsPanel extends StatelessWidget {
  final VoidCallback onAddSeries, onReset, onTogglePanel;
  final List<SchoolSeries> series;
  final void Function(int, bool) onToggleSeriesActive;
  const _RightActionsPanel({required this.onAddSeries, required this.onReset,
      required this.onTogglePanel, required this.series, required this.onToggleSeriesActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _cream,
        border: Border(left: BorderSide(color: _border, width: 1.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 20, 12, 16),
          decoration: BoxDecoration(
            color: _ink.withOpacity(.03),
            border: Border(bottom: BorderSide(color: _border)),
          ),
          child: Row(children: [
            const Expanded(child: Text('Actions', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: _ink))),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onTogglePanel,
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(color: _border.withOpacity(.6), borderRadius: BorderRadius.circular(7)),
                  child: const Icon(Icons.chevron_right_rounded, size: 16, color: _muted),
                ),
              ),
            ),
          ]),
        ),

        Expanded(child: ListView(padding: const EdgeInsets.all(14), children: [
          // Quick action buttons
          _ActionTile(
            icon: Icons.add_circle_outline, label: 'Ajouter une série',
            color: _green, onTap: onAddSeries,
          ),
          const SizedBox(height: 8),
          _ActionTile(
            icon: Icons.restart_alt_rounded, label: 'Réinitialiser tout',
            color: _red, onTap: onReset,
          ),
          const SizedBox(height: 20),

          if (series.isNotEmpty) ...[
            const Text('Séries', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _muted, letterSpacing: 0.8)),
            const SizedBox(height: 8),
            ...series.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: e.value.isActive ? _terra.withOpacity(.06) : _border.withOpacity(.3),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: e.value.isActive ? _terra.withOpacity(.15) : _border),
                ),
                child: Row(children: [
                  Container(width: 7, height: 7,
                    decoration: BoxDecoration(
                      color: e.value.isActive ? _terra : _muted.withOpacity(.4),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(e.value.name,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                          color: e.value.isActive ? _ink : _muted),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                  Transform.scale(
                    scale: 0.75,
                    child: Switch(
                      value: e.value.isActive,
                      onChanged: (v) => onToggleSeriesActive(e.key, v),
                      activeColor: _white,
                      activeTrackColor: _terra,
                      inactiveThumbColor: _muted,
                      inactiveTrackColor: _border,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ]),
              ),
            )),
          ],
        ])),
      ]),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(.2)),
          ),
          child: Row(children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color))),
          ]),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SIDEBAR WIDGETS
// ═════════════════════════════════════════════════════════════════════════════
class _SidebarLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        width: 60, height: 60,
        decoration: BoxDecoration(
          color: _white.withOpacity(.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _white.withOpacity(.12)),
        ),
        padding: const EdgeInsets.all(6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset('assets/images/logo.png', fit: BoxFit.cover,
              errorBuilder: (_,__,___) => const Icon(Icons.school_rounded, color: _gold, size: 34)),
        ),
      ),
      const SizedBox(height: 8),
      const Text('Scolaris', style: TextStyle(color: _white, fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: .3)),
      Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: _gold.withOpacity(.15), borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _gold.withOpacity(.25)),
        ),
        child: const Text('Inscription École', style: TextStyle(color: _gold, fontSize: 10, fontWeight: FontWeight.w600)),
      ),
    ]);
  }
}

class _SidebarStep extends StatelessWidget {
  final int index, current, total;
  final String label;
  final VoidCallback? onTap;
  const _SidebarStep({required this.index, required this.label, required this.current, required this.total, this.onTap});

  @override
  Widget build(BuildContext context) {
    final done = index < current, active = index == current;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
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
                    : Text('${index + 1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
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
      ),
    );
  }
}

class _StepProgressRing extends StatelessWidget {
  final int current, total;
  const _StepProgressRing({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = (current + 1) / total;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
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
                style: const TextStyle(color: _white, fontSize: 12, fontWeight: FontWeight.w900))))),
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

// ═════════════════════════════════════════════════════════════════════════════
// SCHOOL TYPE GRID — no emoji, pro icons
// ═════════════════════════════════════════════════════════════════════════════
/// Déduit l'offre (code DB, nom, prix mensuel XAF) du nombre de modules
/// COMPLÉMENTAIRES cochés (Académique est désormais un socle toujours actif,
/// jamais compté — cf. `backup/migrations_archive/20260809_module_marketplace.sql`,
/// qui applique le même calcul côté trigger `handle_new_school_trial`).
/// Prix codés en dur ici (pas de lecture de `plan_prices`) : l'inscription
/// est encore anonyme à ce stade, or la table n'autorise la lecture qu'aux
/// authentifiés. Reste la SEULE source à mettre à jour si les tarifs
/// changent côté DB.
({String code, String name, int priceMonthly}) _planForModuleCount(int count) {
  if (count <= 0) return (code: 'simple', name: 'Essentiel', priceMonthly: 15000);
  if (count <= 1) return (code: 'pro', name: 'Croissance', priceMonthly: 35000);
  return (code: 'max', name: 'Complet', priceMonthly: 65000);
}

/// Bandeau d'aperçu tarifaire — se met à jour en direct pendant que l'admin
/// coche/décoche des modules, pour que le prix ne soit jamais une surprise à
/// la fin de l'inscription (décision utilisateur explicite).
class _PricePreviewBanner extends StatelessWidget {
  final int moduleCount;
  const _PricePreviewBanner({required this.moduleCount});

  @override
  Widget build(BuildContext context) {
    final plan = _planForModuleCount(moduleCount);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _gold.withOpacity(.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _gold.withOpacity(.25)),
      ),
      child: Row(children: [
        Icon(Icons.sell_outlined, size: 18, color: _gold),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Offre ${plan.name} — ${plan.priceMonthly} F/mois. Essai gratuit de 14 jours, sans engagement.',
            style: TextStyle(fontSize: 12.5, color: _ink, fontWeight: FontWeight.w600),
          ),
        ),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// MODULES GRID — ce que l'école veut gérer (cf. kAppModules)
// ═════════════════════════════════════════════════════════════════════════════
class _ModulesGrid extends StatelessWidget {
  final Set<String> selected;
  final void Function(String) onToggle;
  const _ModulesGrid({required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final cols = w > 700 ? 2 : 1;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 3.4,
      ),
      itemCount: kAppModules.length,
      itemBuilder: (_, i) {
        final m = kAppModules[i];
        final sel = selected.contains(m.id);
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => onToggle(m.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: sel ? _terra.withOpacity(.07) : _white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: sel ? _terra : _border, width: sel ? 1.5 : 1),
              ),
              child: Row(children: [
                Icon(m.icon, size: 20, color: sel ? _terra : _muted),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(m.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                        color: sel ? _terra : _ink)),
                    Text(m.description, style: TextStyle(fontSize: 10.5, color: sel ? _terra.withOpacity(.7) : _muted),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ]),
                ),
                Checkbox(
                  value: sel,
                  onChanged: (_) => onToggle(m.id),
                  activeColor: _terra,
                ),
              ]),
            ),
          ),
        );
      },
    );
  }
}

class _SchoolTypeGrid extends StatelessWidget {
  final Set<String> selected;
  final void Function(String) onToggle;
  const _SchoolTypeGrid({required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final cols = w > 700 ? 4 : w > 480 ? 3 : 2;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.5,
      ),
      itemCount: _kSchoolTypes.length,
      itemBuilder: (_, i) {
        final t = _kSchoolTypes[i];
        if (t.comingSoon) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F0EB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(t.icon, size: 16, color: _muted.withOpacity(.45)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: _muted.withOpacity(.12),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text('Bientôt', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: _muted.withOpacity(.6))),
                ),
              ]),
              const SizedBox(height: 5),
              Text(t.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                  color: _muted.withOpacity(.5)), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(t.sub, style: TextStyle(fontSize: 10, color: _muted.withOpacity(.4)),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          );
        }
        final sel = selected.contains(t.id);
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
          onTap: () => onToggle(t.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: sel ? _terra.withOpacity(.07) : _white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: sel ? _terra : _border, width: sel ? 1.5 : 1),
              boxShadow: sel ? [BoxShadow(color: _terra.withOpacity(.1), blurRadius: 8)] : [BoxShadow(color: _ink.withOpacity(.03), blurRadius: 4)],
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(t.icon, size: 16, color: sel ? _terra : _muted),
                if (sel) ...[
                  const Spacer(),
                  Container(
                    width: 16, height: 16,
                    decoration: const BoxDecoration(color: _terra, shape: BoxShape.circle),
                    child: const Icon(Icons.check, size: 10, color: _white),
                  ),
                ],
              ]),
              const SizedBox(height: 5),
              Text(t.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                  color: sel ? _terra : _ink), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(t.sub, style: TextStyle(fontSize: 10, color: sel ? _terra.withOpacity(.7) : _muted),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          ),
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// COUNTRY / CITY AUTOCOMPLETE FIELDS
// ═════════════════════════════════════════════════════════════════════════════
class _CountryField extends StatefulWidget {
  final TextEditingController ctrl;
  final String label;
  final bool required;
  final void Function(String) onChanged;
  const _CountryField({required this.ctrl, required this.label, this.required = false, required this.onChanged});
  @override
  State<_CountryField> createState() => _CountryFieldState();
}

class _CountryFieldState extends State<_CountryField> {
  final _focus = FocusNode();
  OverlayEntry? _overlay;
  final _key = GlobalKey();
  List<String> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _focus.addListener(() { if (!_focus.hasFocus) _removeOverlay(); });
    widget.ctrl.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final q = widget.ctrl.text.toLowerCase();
    if (q.isEmpty) { _removeOverlay(); _suggestions = []; return; }
    _suggestions = _kCountries.where((c) => c.toLowerCase().contains(q)).take(8).toList();
    if (_suggestions.isEmpty) { _removeOverlay(); return; }
    _showOverlay();
  }

  void _showOverlay() {
    _removeOverlay();
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pos = box.localToGlobal(Offset.zero);
    _overlay = OverlayEntry(builder: (_) => Positioned(
      left: pos.dx, top: pos.dy + box.size.height + 2,
      width: box.size.width,
      child: Material(
        elevation: 8, borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 220),
          decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.symmetric(vertical: 4),
            children: _suggestions.map((s) => InkWell(
              onTap: () { widget.ctrl.text = s; widget.onChanged(s); _removeOverlay(); _focus.unfocus(); setState(() {}); },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Text(s, style: const TextStyle(fontSize: 13.5, color: _ink)),
              ),
            )).toList(),
          ),
        ),
      ),
    ));
    Overlay.of(context).insert(_overlay!);
  }

  void _removeOverlay() { _overlay?.remove(); _overlay = null; }

  @override
  void dispose() { _removeOverlay(); _focus.dispose(); widget.ctrl.removeListener(_onTextChanged); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _FieldLabel(widget.label, required: widget.required),
      const SizedBox(height: 6),
      TextFormField(
        key: _key,
        controller: widget.ctrl,
        focusNode: _focus,
        style: const TextStyle(fontSize: 14, color: _ink),
        decoration: _inputDeco(hint: 'Congo, France, Maroc…', icon: Icons.public_outlined),
        validator: widget.required ? (v) => (v?.trim().isEmpty ?? true) ? 'Pays requis' : null : null,
        onChanged: (v) { widget.onChanged(v); setState(() {}); },
      ),
    ]);
  }
}

class _CityField extends StatefulWidget {
  final TextEditingController ctrl;
  final String label, country;
  final bool required;
  const _CityField({required this.ctrl, required this.label, required this.country, this.required = false});
  @override
  State<_CityField> createState() => _CityFieldState();
}

class _CityFieldState extends State<_CityField> {
  final _focus = FocusNode();
  OverlayEntry? _overlay;
  final _key = GlobalKey();
  List<String> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _focus.addListener(() { if (!_focus.hasFocus) _removeOverlay(); });
    widget.ctrl.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final q = widget.ctrl.text.toLowerCase();
    final citiesForCountry = _kCitiesByCountry[widget.country] ?? [];
    if (q.isEmpty) {
      _suggestions = citiesForCountry.take(8).toList();
    } else {
      _suggestions = citiesForCountry.where((c) => c.toLowerCase().contains(q)).take(8).toList();
    }
    if (_suggestions.isEmpty) { _removeOverlay(); return; }
    _showOverlay();
  }

  void _showOverlay() {
    _removeOverlay();
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pos = box.localToGlobal(Offset.zero);
    _overlay = OverlayEntry(builder: (_) => Positioned(
      left: pos.dx, top: pos.dy + box.size.height + 2,
      width: box.size.width,
      child: Material(
        elevation: 8, borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 220),
          decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.symmetric(vertical: 4),
            children: _suggestions.map((s) => InkWell(
              onTap: () { widget.ctrl.text = s; _removeOverlay(); _focus.unfocus(); setState(() {}); },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Text(s, style: const TextStyle(fontSize: 13.5, color: _ink)),
              ),
            )).toList(),
          ),
        ),
      ),
    ));
    Overlay.of(context).insert(_overlay!);
  }

  void _removeOverlay() { _overlay?.remove(); _overlay = null; }

  @override
  void dispose() { _removeOverlay(); _focus.dispose(); widget.ctrl.removeListener(_onTextChanged); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _FieldLabel(widget.label, required: widget.required),
      const SizedBox(height: 6),
      TextFormField(
        key: _key,
        controller: widget.ctrl,
        focusNode: _focus,
        style: const TextStyle(fontSize: 14, color: _ink),
        decoration: _inputDeco(hint: 'Brazzaville, Paris, Dakar…', icon: Icons.location_city_outlined),
        validator: widget.required ? (v) => (v?.trim().isEmpty ?? true) ? 'Ville requise' : null : null,
        onTap: () {
          if (widget.ctrl.text.isEmpty) _onTextChanged();
        },
      ),
    ]);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SERIES CARD (improved with insert between)
// ═════════════════════════════════════════════════════════════════════════════
class _SeriesCard extends StatefulWidget {
  final SchoolSeries series;
  final ValueChanged<bool> onToggle;
  final VoidCallback onRemove, onChange;
  final ValueChanged<String> onAddClass;
  final void Function(int, String) onInsertClass;
  final ValueChanged<int> onRemoveClass;
  const _SeriesCard({required this.series, required this.onToggle, required this.onRemove,
      required this.onAddClass, required this.onInsertClass, required this.onRemoveClass, required this.onChange});
  @override
  State<_SeriesCard> createState() => _SeriesCardState();
}

class _SeriesCardState extends State<_SeriesCard> {
  bool _expanded = true;
  final _classCtrl = TextEditingController();
  int? _insertAfterIdx;

  @override
  void dispose() { _classCtrl.dispose(); super.dispose(); }

  void _addClass() {
    if (_classCtrl.text.trim().isEmpty) return;
    final v = _classCtrl.text.trim();
    if (_insertAfterIdx != null) {
      widget.onInsertClass(_insertAfterIdx!, v);
      setState(() => _insertAfterIdx = null);
    } else {
      widget.onAddClass(v);
    }
    _classCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.series;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: s.isActive ? _white : _subtle,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: s.isActive ? _border : _border.withOpacity(.4)),
        boxShadow: s.isActive ? [BoxShadow(color: _ink.withOpacity(.04), blurRadius: 6, offset: const Offset(0,2))] : [],
      ),
      child: Column(children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          child: Row(children: [
            Container(width: 10, height: 10,
              decoration: BoxDecoration(color: s.isActive ? _terra : _border, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.name, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: s.isActive ? _ink : _muted)),
              if (s.code.isNotEmpty || s.description.isNotEmpty)
                Text('${s.code}${s.description.isNotEmpty ? "  ·  ${s.description}" : ""}',
                    style: const TextStyle(fontSize: 11, color: _muted)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: _terra.withOpacity(.08), borderRadius: BorderRadius.circular(8)),
              child: Text('${s.classes.length} classe${s.classes.length != 1 ? "s" : ""}',
                  style: const TextStyle(fontSize: 11, color: _terra, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 8),
            // Fixed switch — thumb colored, track subtle
            Transform.scale(
              scale: 0.85,
              child: Switch(
                value: s.isActive,
                onChanged: widget.onToggle,
                activeColor: _white,
                activeTrackColor: _terra,
                inactiveThumbColor: _muted,
                inactiveTrackColor: _border,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: _muted, size: 20),
              ),
            ),
            const SizedBox(width: 4),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: widget.onRemove,
                child: const Icon(Icons.delete_outline_rounded, color: _red, size: 17),
              ),
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
                Column(
                  children: s.classes.asMap().entries.expand((e) => [
                    Row(children: [
                      _ClassChip(label: e.value, onRemove: () => widget.onRemoveClass(e.key)),
                      const SizedBox(width: 6),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () => setState(() => _insertAfterIdx = _insertAfterIdx == e.key ? null : e.key),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: _insertAfterIdx == e.key ? _green.withOpacity(.12) : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.add_rounded, size: 12, color: _insertAfterIdx == e.key ? _green : _muted),
                              Text(' après', style: TextStyle(fontSize: 9.5, color: _insertAfterIdx == e.key ? _green : _muted, fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        ),
                      ),
                    ]),
                    if (_insertAfterIdx == e.key)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 2),
                        child: Row(children: [
                          Expanded(child: SizedBox(height: 38,
                            child: TextField(
                              controller: _classCtrl,
                              style: const TextStyle(fontSize: 13, color: _ink),
                              decoration: _inputDeco(hint: 'Nom de la classe…', icon: Icons.add_outlined),
                              onSubmitted: (_) => _addClass(),
                            ),
                          )),
                          const SizedBox(width: 8),
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: _addClass,
                              child: Container(width: 38, height: 38,
                                decoration: BoxDecoration(color: _green.withOpacity(.1), borderRadius: BorderRadius.circular(9)),
                                child: const Icon(Icons.check_rounded, color: _green, size: 18)),
                            ),
                          ),
                        ]),
                      ),
                    const SizedBox(height: 6),
                  ]).toList(),
                ),
              const SizedBox(height: 8),
              // Add to end row
              if (_insertAfterIdx == null)
                Row(children: [
                  Expanded(child: SizedBox(height: 42,
                    child: TextField(
                      controller: _classCtrl,
                      style: const TextStyle(fontSize: 13, color: _ink),
                      decoration: _inputDeco(hint: 'Ajouter une classe…', icon: Icons.add_outlined),
                      onSubmitted: (v) { if (v.isNotEmpty) { widget.onAddClass(v.trim()); _classCtrl.clear(); } },
                    ),
                  )),
                  const SizedBox(width: 8),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () { if (_classCtrl.text.isNotEmpty) { widget.onAddClass(_classCtrl.text.trim()); _classCtrl.clear(); } },
                      child: Container(width: 42, height: 42,
                        decoration: BoxDecoration(color: _terra.withOpacity(.1), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.add_circle_outline, color: _terra, size: 20)),
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

// ═════════════════════════════════════════════════════════════════════════════
// SYSTEM CARD
// ═════════════════════════════════════════════════════════════════════════════
class _SystemCard extends StatelessWidget {
  final _SysInfo sys;
  final bool selected;
  final VoidCallback onTap, onInfo;
  const _SystemCard({required this.sys, required this.selected, required this.onTap, required this.onInfo});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? _terra.withOpacity(.05) : _white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? _terra : _border, width: selected ? 2 : 1),
          boxShadow: [BoxShadow(color: _ink.withOpacity(.04), blurRadius: 6, offset: const Offset(0,2))],
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: selected ? _terra.withOpacity(.1) : _subtle,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(sys.flag, style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(sys.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                color: selected ? _terra : _ink)),
            const SizedBox(height: 2),
            Text(sys.countries.split(',').take(3).join(', ') + '…',
                style: const TextStyle(fontSize: 11.5, color: _muted), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Text('Langue : ${sys.language}', style: TextStyle(fontSize: 11, color: _muted.withOpacity(.8))),
          ])),
          const SizedBox(width: 8),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onInfo,
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: _gold.withOpacity(.1), borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _gold.withOpacity(.2)),
                ),
                child: const Icon(Icons.info_outline_rounded, size: 16, color: _gold),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (selected)
            const Icon(Icons.check_circle_rounded, color: _terra, size: 22),
        ]),
      ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// BOTTOM NAVIGATION
// ═════════════════════════════════════════════════════════════════════════════
class _BottomNav extends StatelessWidget {
  final int step, total;
  final VoidCallback? onPrev, onNext, onSubmit;
  final bool submitting;
  final String? error;
  const _BottomNav({required this.step, required this.total, this.onPrev, this.onNext,
      this.onSubmit, required this.submitting, this.error});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      decoration: BoxDecoration(
        color: _white,
        border: Border(top: BorderSide(color: _border)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (error != null) ...[
          _InfoBanner(icon: Icons.error_outline_rounded, color: _red, text: error!),
          const SizedBox(height: 10),
        ],
        Row(children: [
          if (onPrev != null)
            _OutlineBtn(label: 'Précédent', icon: Icons.arrow_back_rounded, onTap: onPrev!),
          const Spacer(),
          if (onNext != null)
            _PrimaryBtn(label: 'Continuer', icon: Icons.arrow_forward_rounded, loading: false, onTap: onNext),
          if (onSubmit != null)
            _PrimaryBtn(
              label: submitting ? 'Création en cours…' : 'Créer mon école',
              icon: Icons.school_rounded, loading: submitting, onTap: submitting ? null : onSubmit,
            ),
        ]),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// UTILITY WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

// Social field
class _SocialField extends StatelessWidget {
  final TextEditingController ctrl;
  final String platform, hint;
  final IconData icon;
  const _SocialField({required this.ctrl, required this.platform, required this.hint, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 38, height: 38,
        decoration: BoxDecoration(color: _subtle, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
        child: Icon(icon, size: 17, color: _muted),
      ),
      const SizedBox(width: 10),
      Expanded(child: SizedBox(height: 46,
        child: TextField(
          controller: ctrl,
          style: const TextStyle(fontSize: 13.5, color: _ink),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 13, color: _muted.withOpacity(.5)),
            filled: true, fillColor: _white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: _border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: _border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: _terra, width: 1.5)),
          ),
        ),
      )),
    ]);
  }
}

// Media option button
class _MediaOptionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MediaOptionBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: _subtle,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 22, color: _terra),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _ink),
                textAlign: TextAlign.center, maxLines: 2),
          ]),
        ),
        ),
      ),
    );
  }
}

// Phone row
class _PhoneRow extends StatelessWidget {
  final String flag, dialCode;
  final TextEditingController ctrl;
  final VoidCallback onDialTap;
  const _PhoneRow({required this.flag, required this.dialCode, required this.ctrl, required this.onDialTap});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onDialTap,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: _subtle, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(flag, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 4),
              Text(dialCode, style: const TextStyle(fontSize: 12, color: _ink, fontWeight: FontWeight.w600)),
              const Icon(Icons.expand_more_rounded, size: 14, color: _muted),
            ]),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(child: SizedBox(height: 48,
        child: TextField(
          controller: ctrl, keyboardType: TextInputType.phone,
          style: const TextStyle(fontSize: 14, color: _ink),
          decoration: _inputDeco(hint: '06 xx xx xx xx', icon: Icons.phone_outlined),
        ),
      )),
    ]);
  }
}

// Field label
class _FieldLabel extends StatelessWidget {
  final String text;
  final bool required;
  const _FieldLabel(this.text, {this.required = false});
  @override
  Widget build(BuildContext context) {
    if (!required) return Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink));
    return Text.rich(TextSpan(text: text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink),
      children: const [TextSpan(text: ' *', style: TextStyle(color: _red, fontWeight: FontWeight.w900))]));
  }
}

// Standard form field
class _SField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final IconData icon;
  final bool required;
  final TextInputType? keyboard;
  final int maxLines;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  const _SField({required this.ctrl, required this.label, required this.hint, required this.icon,
      this.required = false, this.keyboard, this.maxLines = 1, this.validator, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _FieldLabel(label, required: required),
      const SizedBox(height: 6),
      TextFormField(
        controller: ctrl, keyboardType: keyboard,
        validator: validator, onChanged: onChanged, maxLines: maxLines,
        style: const TextStyle(fontSize: 14, color: _ink),
        decoration: _inputDeco(hint: hint, icon: icon),
      ),
    ]);
  }
}

// Section divider
class _SectionDivider extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? sub;
  const _SectionDivider({required this.label, required this.icon, this.sub});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 34, height: 34,
        decoration: BoxDecoration(color: _terra.withOpacity(.08), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: _terra, size: 17)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 14, color: _ink, fontWeight: FontWeight.w800)),
        if (sub != null) Text(sub!, style: const TextStyle(fontSize: 11, color: _muted)),
      ])),
    ]);
  }
}

// Two column layout
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

// Type chip (for DB types)

// Info banner
class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _InfoBanner({required this.icon, required this.color, required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(.2)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(fontSize: 12.5, color: color, height: 1.4))),
      ]),
    );
  }
}

// Primary button
class _PrimaryBtn extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onTap;
  final IconData? icon;
  const _PrimaryBtn({required this.label, required this.loading, this.onTap, this.icon});
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 48, padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [_terra, _orange], begin: Alignment.centerLeft, end: Alignment.centerRight),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: _terra.withOpacity(onTap != null ? .3 : .15), blurRadius: 12, offset: const Offset(0,4))],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (loading)
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _white))
          else if (icon != null)
            Icon(icon, color: _white, size: 17),
          if (!loading && icon != null) const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: _white, fontSize: 14, fontWeight: FontWeight.w800)),
        ]),
      ),
      ),
    );
  }
}

// Outline button
class _OutlineBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _OutlineBtn({required this.label, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46, padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: _white, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: _terra),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 13.5, color: _terra, fontWeight: FontWeight.w700)),
        ]),
      ),
      ),
    );
  }
}

// Password strength
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
      Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(value: s / 4, backgroundColor: _border,
            valueColor: AlwaysStoppedAnimation(color), minHeight: 5))),
      const SizedBox(width: 10),
      Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
    ]);
  }
}

// Recap card
class _RecapCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<(String, String)> items;
  const _RecapCard({required this.title, required this.icon, required this.color, required this.items});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _white, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: _ink.withOpacity(.04), blurRadius: 6, offset: const Offset(0,2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 30, height: 30,
            decoration: BoxDecoration(color: color.withOpacity(.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 15, color: color)),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: _ink))),
        ]),
        const SizedBox(height: 10),
        const Divider(height: 1, color: _border),
        const SizedBox(height: 10),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 100,
              child: Text(item.$1, style: const TextStyle(fontSize: 12.5, color: _muted))),
            Expanded(child: Text(item.$2, style: const TextStyle(fontSize: 12.5, color: _ink, fontWeight: FontWeight.w600))),
          ]),
        )),
      ]),
    );
  }
}

// Class chip
class _ClassChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _ClassChip({required this.label, required this.onRemove});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: _terra.withOpacity(.08), borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _terra.withOpacity(.15)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: const TextStyle(fontSize: 12, color: _terra, fontWeight: FontWeight.w600)),
        const SizedBox(width: 5),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(onTap: onRemove,
            child: const Icon(Icons.close_rounded, size: 12, color: _terra)),
        ),
      ]),
    );
  }
}

// Branch card
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
        color: _white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: _ink.withOpacity(.04), blurRadius: 8, offset: const Offset(0,2))],
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          decoration: BoxDecoration(
            color: _terra.withOpacity(.04),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(children: [
            Container(width: 30, height: 30,
              decoration: BoxDecoration(color: _terra.withOpacity(.12), borderRadius: BorderRadius.circular(8)),
              child: Center(child: Text('${index + 1}',
                  style: const TextStyle(color: _terra, fontSize: 13, fontWeight: FontWeight.w900)))),
            const SizedBox(width: 10),
            Text('Filiale ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: _ink)),
            const Spacer(),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(onTap: onRemove,
                child: Container(width: 30, height: 30,
                  decoration: BoxDecoration(color: _red.withOpacity(.08), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.close_rounded, color: _red, size: 15))),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            TextField(style: const TextStyle(fontSize: 13, color: _ink),
              decoration: _inputDeco(hint: 'Nom de la filiale (ex: Campus Sud)', icon: Icons.label_outline),
              onChanged: (v) { branch.name = v; onChange(); }),
            const SizedBox(height: 10),
            _TwoCol(
              left: TextField(style: const TextStyle(fontSize: 13, color: _ink),
                decoration: _inputDeco(hint: 'Pays *', icon: Icons.public_outlined),
                onChanged: (v) { branch.country = v; onChange(); }),
              right: TextField(style: const TextStyle(fontSize: 13, color: _ink),
                decoration: _inputDeco(hint: 'Ville *', icon: Icons.location_city_outlined),
                onChanged: (v) { branch.city = v; onChange(); }),
            ),
            const SizedBox(height: 10),
            TextField(style: const TextStyle(fontSize: 13, color: _ink),
              decoration: _inputDeco(hint: 'Adresse complète *', icon: Icons.map_outlined),
              onChanged: (v) { branch.address = v; onChange(); }),
            const SizedBox(height: 10),
            Row(children: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(onTap: onPickDial,
                  child: Container(height: 48, padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(color: _subtle, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(branch.countryFlag, style: const TextStyle(fontSize: 15)),
                      const SizedBox(width: 4),
                      Text(branch.dialCode, style: const TextStyle(fontSize: 12, color: _ink, fontWeight: FontWeight.w600)),
                      const Icon(Icons.expand_more_rounded, size: 13, color: _muted),
                    ]))),
              ),
              const SizedBox(width: 8),
              Expanded(child: TextField(keyboardType: TextInputType.phone,
                style: const TextStyle(fontSize: 13, color: _ink),
                decoration: _inputDeco(hint: 'Téléphone filiale', icon: Icons.phone_outlined),
                onChanged: (v) { branch.phone = v; onChange(); })),
            ]),
          ]),
        ),
      ]),
    );
  }
}

// Info dialog section
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
          Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _ink, letterSpacing: 0.3)),
        ]),
        const SizedBox(height: 6),
        if (text != null) Text(text!, style: TextStyle(fontSize: 12.5, color: _muted, height: 1.55)),
        if (list != null)
          ...list!.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(margin: const EdgeInsets.only(top: 6), width: 5, height: 5,
                  decoration: const BoxDecoration(color: _terra, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Text(item, style: const TextStyle(fontSize: 12.5, color: _muted, height: 1.4))),
            ]),
          )),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PAINTERS
// ═════════════════════════════════════════════════════════════════════════════
class _HexPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(.025)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const r = 22.0;
    final h = r * math.sqrt(3);
    for (double y = -h; y < size.height + h; y += h) {
      for (double x = -r * 1.5; x < size.width + r * 1.5; x += r * 3) {
        _hex(canvas, paint, Offset(x, y), r);
        _hex(canvas, paint, Offset(x + r * 1.5, y + h / 2), r);
      }
    }
  }

  void _hex(Canvas canvas, Paint paint, Offset center, double r) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = math.pi / 180 * (60 * i - 30);
      final pt = Offset(center.dx + r * math.cos(angle), center.dy + r * math.sin(angle));
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _SidebarPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(.03)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const r = 18.0;
    final h = r * math.sqrt(3);
    for (double y = -h; y < size.height + h; y += h) {
      for (double x = -r * 1.5; x < size.width + r * 1.5; x += r * 3) {
        final path = Path();
        for (int i = 0; i < 6; i++) {
          final angle = math.pi / 180 * (60 * i - 30);
          final pt = Offset(x + r * math.cos(angle), y + r * math.sin(angle));
          i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
        }
        path.close();
        canvas.drawPath(path, paint);
      }
    }
  }
  @override
  bool shouldRepaint(_) => false;
}

class _RingPainter extends CustomPainter {
  final double progress;
  const _RingPainter(this.progress);
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 2;
    canvas.drawCircle(center, radius, Paint()
      ..color = Colors.white.withOpacity(.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, 2 * math.pi * progress, false,
      Paint()
        ..color = const Color(0xFFC17F24)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }
  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

// ── Shared input decoration ───────────────────────────────────────────────────
InputDecoration _inputDeco({required String hint, required IconData icon, Widget? suffix}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(fontSize: 13.5, color: _muted.withOpacity(.5)),
    prefixIcon: Icon(icon, size: 18, color: _muted),
    suffixIcon: suffix,
    filled: true, fillColor: _white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _terra, width: 1.5)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _red, width: 1.5)),
    focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _red, width: 1.5)),
  );
}
