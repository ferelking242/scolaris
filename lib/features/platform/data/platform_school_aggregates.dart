import 'platform_mock_data.dart';

/// Agrégats calculés depuis une liste d'écoles — que ce soit la vraie liste
/// (`PlatformRepository.getSchools()`) ou la maquette. Partagé entre le
/// Dashboard et la page Écoles pour ne pas dupliquer la même logique
/// (« à surveiller », répartition par offre, tendance…) à deux endroits.
extension PlatformSchoolsAggregates on List<PlatformSchool> {
  int get total => length;
  int get paying => where((s) => s.isPaying).length;
  int get trials => where((s) => s.status == SubStatus.trial).length;
  int get churned => where((s) =>
      s.status == SubStatus.expired || s.status == SubStatus.canceled).length;

  int get mrr => where((s) => s.isPaying)
      .fold(0, (sum, s) => sum + s.plan.monthlyPrice);

  Map<PlatformPlan, int> get planBreakdown {
    final m = {for (final p in PlatformPlan.values) p: 0};
    for (final s in this) {
      m[s.plan] = (m[s.plan] ?? 0) + 1;
    }
    return m;
  }

  List<PlatformSchool> get recent =>
      [...this]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<PlatformSchool> get needsAttention => where((s) =>
      s.status == SubStatus.pastDue ||
      s.status == SubStatus.expired ||
      (s.status == SubStatus.trial && s.daysLeft <= 20)).toList();

  static const _monthsFr = [
    'jan.', 'fév.', 'mar.', 'avr.', 'mai', 'juin',
    'juil.', 'août', 'sep.', 'oct.', 'nov.', 'déc.',
  ];

  /// Écoles cumulées, mois par mois, sur les 6 derniers mois — dérivé de
  /// `createdAt`, pas d'une série figée.
  List<double> schoolsTrend(DateTime now) {
    final months = List.generate(6, (i) {
      final m = DateTime(now.year, now.month - (5 - i));
      return m;
    });
    return [
      for (final m in months)
        where((s) =>
                s.createdAt.year < m.year ||
                (s.createdAt.year == m.year && s.createdAt.month <= m.month))
            .length
            .toDouble(),
    ];
  }

  List<String> trendMonths(DateTime now) => List.generate(6, (i) {
        final m = DateTime(now.year, now.month - (5 - i));
        return _monthsFr[m.month - 1];
      });

  /// Revenu récurrent cumulé, mois par mois, sur les 6 derniers mois — même
  /// principe que [schoolsTrend] : une école inscrite avant ce mois-là ET
  /// actuellement payante compte pour son offre ACTUELLE (pas d'historique de
  /// changement d'offre/statut conservé) — une approximation de tendance, pas
  /// un relevé comptable exact.
  List<double> mrrTrend(DateTime now) {
    final months = List.generate(6, (i) => DateTime(now.year, now.month - (5 - i)));
    return [
      for (final m in months)
        where((s) =>
                s.isPaying &&
                (s.createdAt.year < m.year ||
                    (s.createdAt.year == m.year && s.createdAt.month <= m.month)))
            .fold<double>(0, (sum, s) => sum + s.plan.monthlyPrice),
    ];
  }
}
