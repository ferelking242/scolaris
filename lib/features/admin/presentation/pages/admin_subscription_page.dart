import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/data/features_catalog.dart' show kAppModules;
import '../../../../shared/pdf/subscription_receipt_pdf.dart';
import '../../../../shared/widgets/page_scaffold.dart';

/// Libellés lisibles des clés de fonctionnalités stockées en base (`plans.features`).
const _featureLabels = <String, String>{
  '1_module_au_choix': '1 module au choix (Académique, Présences, Finances ou Inscriptions)',
  'jusqu_a_3_modules': 'Jusqu\'à 3 modules au choix',
  '4_modules': 'Les 4 modules (Académique, Présences, Finances, Inscriptions)',
  'rapport_premium': 'Rapport Premium (tendances de recouvrement)',
};

/// Noms d'offres, alignés sur les modules (cf. 20260801_offer_tiers.sql).
const _planNames = <String, String>{'simple': 'Essentiel', 'pro': 'Croissance', 'max': 'Complet'};

/// Numéros marchands Mobile Money DE SCOLARIS (pas de l'école) — où les
/// écoles envoient leur règlement d'abonnement tant qu'aucun agrégateur n'est
/// branché. ⚠️ À REMPLACER par les vrais numéros marchands avant le lancement.
const _scolarisMomoMtn = '06 000 00 00';
const _scolarisMomoAirtel = '05 000 00 00';

/// Contact Scolaris (WhatsApp/appel) — pour toute question sur l'abonnement
/// ou pour signaler un versement (dépannage si l'école ne trouve pas la
/// référence, doute sur le montant…). ⚠️ À REMPLACER avant le lancement.
const _scolarisContactPhone = '06 000 00 00';

/// Page Admin « Mon abonnement » : offre actuelle, usage élèves, choix d'offre.
/// L'ÉCOLE paie Scolaris (SaaS). À ne pas confondre avec la facturation des
/// élèves (frais de scolarité) — voir AdminBillingPage.
class AdminSubscriptionPage extends ConsumerWidget {
  const AdminSubscriptionPage({super.key});

  static const _green = Color(0xFF15803D);
  static const _cyan = Color(0xFF0E7490);
  static const _violet = Color(0xFF7C3AED);

  Color _planColor(String code) => switch (code) {
        'simple' => _green,
        'pro' => _cyan,
        'max' => _violet,
        _ => muted,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subAsync = ref.watch(subscriptionProvider);
    final plansAsync = ref.watch(plansProvider);
    final pricesAsync = ref.watch(planPricesProvider);
    final countAsync = ref.watch(studentCountProvider);
    final surchargesAsync = ref.watch(planSizeSurchargesProvider);

    Future<void> refresh() async {
      ref.invalidate(subscriptionProvider);
      ref.invalidate(plansProvider);
      ref.invalidate(planPricesProvider);
      ref.invalidate(studentCountProvider);
      ref.invalidate(planSizeSurchargesProvider);
      await Future.wait([
        ref.read(subscriptionProvider.future),
        ref.read(plansProvider.future),
        ref.read(planPricesProvider.future),
        ref.read(studentCountProvider.future),
        ref.read(planSizeSurchargesProvider.future),
      ]);
    }

    final loading = subAsync.isLoading || plansAsync.isLoading || pricesAsync.isLoading;
    if (loading) {
      return PageScaffold(
        onRefresh: refresh,
        title: 'Mon abonnement',
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (plansAsync.hasError) {
      return PageScaffold(
        onRefresh: refresh,
        title: 'Mon abonnement',
        child: Center(child: Text('Erreur : ${plansAsync.error}')),
      );
    }

    final sub = subAsync.value;
    final plans = plansAsync.value ?? const <SbPlan>[];
    final prices = pricesAsync.value ?? const <SbPlanPrice>[];
    final count = countAsync.value ?? 0;

    double? monthlyPrice(String code) {
      for (final p in prices) {
        if (p.planCode == code && p.period == 'monthly') return p.price;
      }
      return null;
    }

    final currentPlan = sub?.planCode;
    final currentPlanObj = plans.where((p) => p.code == currentPlan).firstOrNull;
    final currentLimit = currentPlanObj?.includedStudents;
    final surcharges = surchargesAsync.value ?? const <SbPlanSizeSurcharge>[];
    final currentSurcharge = currentPlan == null
        ? null
        : surcharges.where((s) => s.planCode == currentPlan && s.matches(count)).firstOrNull;
    final fmt = NumberFormat.decimalPattern('fr');

    return PageScaffold(
      onRefresh: refresh,
      title: 'Mon abonnement',
      subtitle: 'Votre offre Scolaris et votre utilisation',
      child: Column(children: [
        _StatusBanner(sub: sub, color: _planColor(currentPlan ?? '')),
        const SizedBox(height: 14),
        DataPanel(
          title: 'Utilisation — élèves',
          child: _UsageBar(count: count, limit: currentLimit, fmt: fmt),
        ),
        if (currentSurcharge != null) ...[
          const SizedBox(height: 14),
          DataPanel(
            title: 'Supplément de taille',
            child: _SizeSurchargeRow(surcharge: currentSurcharge, fmt: fmt),
          ),
        ],
        const SizedBox(height: 14),
        const DataPanel(
          title: 'Modules actifs',
          child: _ModulesPanel(),
        ),
        const SizedBox(height: 14),
        DataPanel(
          title: 'Choisir une offre',
          child: LayoutBuilder(builder: (ctx, c) {
            final wide = c.maxWidth > 720;
            final cards = [
              for (final p in plans)
                _PlanCard(
                  plan: p,
                  monthly: monthlyPrice(p.code),
                  currency: prices.isNotEmpty ? prices.first.currency : 'XAF',
                  color: _planColor(p.code),
                  isCurrent: p.code == currentPlan,
                  fmt: fmt,
                  onChoose: () => _onChoose(context, ref, p, monthlyPrice(p.code),
                      prices.isNotEmpty ? prices.first.currency : 'XAF', sub),
                ),
            ];
            return wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < cards.length; i++) ...[
                        Expanded(child: cards[i]),
                        if (i < cards.length - 1) const SizedBox(width: 12),
                      ]
                    ],
                  )
                : Column(
                    children: [
                      for (var i = 0; i < cards.length; i++) ...[
                        cards[i],
                        if (i < cards.length - 1) const SizedBox(height: 12),
                      ]
                    ],
                  );
          }),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Paiement annuel = 2 mois offerts. Essai gratuit 1 mois. '
            'Prix indicatifs (FCFA), déclinables par pays.',
            style: TextStyle(fontSize: 11.5, color: context.cMuted),
          ),
        ),
        const SizedBox(height: 14),
        DataPanel(
          title: 'Historique de facturation',
          child: _BillingHistory(
            planNameByCode: {for (final p in plans) p.code: p.name},
            fmt: fmt,
          ),
        ),
      ]),
    );
  }

  void _onChoose(BuildContext context, WidgetRef ref, SbPlan plan,
      double? monthly, String currency, SbSubscription? currentSub) {
    showDialog(
      context: context,
      builder: (_) => _ChoosePlanDialog(
        plan: plan,
        monthly: monthly,
        currency: currency,
        color: _planColor(plan.code),
        currentSub: currentSub,
      ),
    );
  }
}

/// Dialogue de souscription : choix mensuel/annuel + paiement SIMULÉ (démo)
/// → active l'offre. Le jour des vrais agrégateurs, seule la confirmation
/// opérateur change.
class _ChoosePlanDialog extends ConsumerStatefulWidget {
  final SbPlan plan;
  final double? monthly;
  final String currency;
  final Color color;
  final SbSubscription? currentSub;
  const _ChoosePlanDialog({
    required this.plan,
    required this.monthly,
    required this.currency,
    required this.color,
    this.currentSub,
  });
  @override
  ConsumerState<_ChoosePlanDialog> createState() => _ChoosePlanDialogState();
}

class _ChoosePlanDialogState extends ConsumerState<_ChoosePlanDialog> {
  bool _yearly = false;
  bool _processing = false;
  String _operator = 'mtn';
  final _reference = TextEditingController();
  final _fmt = NumberFormat.decimalPattern('fr');

  @override
  void dispose() {
    _reference.dispose();
    super.dispose();
  }

  // Prix plein de la nouvelle offre (stocké en DB pour les renouvellements futurs)
  double? get _fullPrice {
    final m = widget.monthly;
    if (m == null) return null;
    return _yearly ? m * 10 : m;
  }

  // Crédit total disponible = crédit prorata du cycle en cours + solde reporté
  double get _credit {
    final s = widget.currentSub;
    if (s == null || s.isTrial || s.price == null || s.currentPeriodEnd == null) {
      return widget.currentSub?.creditBalance ?? 0;
    }
    final remaining = s.currentPeriodEnd!.difference(DateTime.now()).inDays.clamp(0, 999);
    final totalDays = s.billingPeriod == 'annual' ? 365 : 30;
    final prorata = (remaining / totalDays * s.price!).clamp(0.0, s.price!);
    return prorata + s.creditBalance;
  }

  // Ce que l'école paie maintenant (après déduction du crédit total)
  double? get _chargeNow {
    final full = _fullPrice;
    if (full == null) return null;
    return (full - _credit).clamp(0.0, full);
  }

  // Crédit restant à reporter sur les prochains cycles
  double get _newCreditBalance {
    final full = _fullPrice ?? 0;
    return (_credit - full).clamp(0.0, double.infinity);
  }

  Future<void> _pay() async {
    final schoolId = ref.read(currentSchoolIdProvider);
    final charge = _chargeNow;
    final subId = widget.currentSub?.id;
    final ref_ = _reference.text.trim();
    if (schoolId == null || charge == null || subId == null || subId.isEmpty) return;
    if (ref_.isEmpty) return;
    setState(() => _processing = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Pas d'activation immédiate : l'école a envoyé l'argent elle-même
      // (USSD, hors app) vers le numéro marchand Scolaris — le versement
      // reste `pending` jusqu'à vérification manuelle du versement.
      await SupabaseDbSource.submitSubscriptionPayment(
        subscriptionId: subId,
        schoolId: schoolId,
        planCode: widget.plan.code,
        period: _yearly ? 'annual' : 'monthly',
        amount: charge,
        currency: widget.currency,
        reference: ref_,
        provider: _operator,
      );
      ref.invalidate(subscriptionPaymentsProvider);
      if (mounted) navigator.pop();
      messenger.showSnackBar(const SnackBar(
        backgroundColor: Color(0xFFC17F24),
        behavior: SnackBarBehavior.floating,
        content: Text('Versement enregistré — en attente de vérification. '
            'Votre offre s\'active dès que le paiement est confirmé.'),
        duration: Duration(seconds: 4),
      ));
    } catch (e) {
      if (mounted) {
        setState(() => _processing = false);
        messenger.showSnackBar(SnackBar(
            content: Text('Échec : $e'),
            backgroundColor: const Color(0xFF8B1A00)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final full    = _fullPrice;
    final credit  = _credit;
    final charge  = _chargeNow;
    final hasCredit = credit > 0;
    final c = widget.color;
    final s = widget.currentSub;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text('Souscrire — ${widget.plan.name}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: (MediaQuery.sizeOf(context).width * 0.92).clamp(0, 380),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Bandeau : paiement manuel (pas d'agrégateur branché)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFC17F24).withValues(alpha: .12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
                'Envoyez le montant via Mobile Money au numéro ci-dessous, '
                'puis saisissez la référence reçue par SMS. Votre offre '
                's\'active dès vérification du versement.',
                style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8A5A12),
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 14),
          // Toggle mensuel / annuel
          Row(children: [
            Expanded(child: _periodBtn('Mensuel', !_yearly, c, () => setState(() => _yearly = false))),
            const SizedBox(width: 10),
            Expanded(child: _periodBtn('Annuel · 2 mois offerts', _yearly, c, () => setState(() => _yearly = true))),
          ]),
          const SizedBox(height: 18),

          // Montant à payer maintenant (mis en avant)
          Row(crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic, children: [
            Text(charge != null ? _fmt.format(charge) : '—',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: c)),
            const SizedBox(width: 6),
            Text('${widget.currency} maintenant',
                style: TextStyle(fontSize: 12.5, color: context.cMuted)),
          ]),

          // Détail prorata si crédit applicable
          if (hasCredit && full != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _ProratRow(
                  label: 'Prix offre ${widget.plan.name} (${_yearly ? "an" : "mois"})',
                  value: '${_fmt.format(full)} ${widget.currency}',
                  color: context.cInk,
                ),
                const SizedBox(height: 4),
                if (s != null && s.creditBalance > 0 && (s.price == null || s.currentPeriodEnd == null))
                  _ProratRow(
                    label: 'Crédit disponible (reporté)',
                    value: '− ${_fmt.format(s.creditBalance)} ${widget.currency}',
                    color: const Color(0xFF15803D),
                  )
                else if (s != null && s.currentPeriodEnd != null) ...[
                  _ProratRow(
                    label: 'Prorata offre ${s.planCode?.toUpperCase() ?? ""}'
                        ' (${s.currentPeriodEnd!.difference(DateTime.now()).inDays.clamp(0, 999)} j)',
                    value: '− ${_fmt.format((credit - s.creditBalance).clamp(0, double.infinity))} ${widget.currency}',
                    color: const Color(0xFF15803D),
                  ),
                  if (s.creditBalance > 0) ...[
                    const SizedBox(height: 4),
                    _ProratRow(
                      label: 'Crédit reporté précédent',
                      value: '− ${_fmt.format(s.creditBalance)} ${widget.currency}',
                      color: const Color(0xFF15803D),
                    ),
                  ],
                ],
                const Divider(height: 12, color: Color(0xFFBBF7D0)),
                _ProratRow(
                  label: 'À payer maintenant',
                  value: '${_fmt.format(charge ?? 0)} ${widget.currency}',
                  color: c,
                  bold: true,
                ),
                const SizedBox(height: 4),
                if (_newCreditBalance > 0)
                  Text(
                    'Crédit de ${_fmt.format(_newCreditBalance)} ${widget.currency} reporté sur vos prochains cycles.',
                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF15803D), fontWeight: FontWeight.w600),
                  )
                else
                  Text(
                    'Dès le prochain cycle : ${_fmt.format(full)} ${widget.currency}/${_yearly ? "an" : "mois"}',
                    style: TextStyle(fontSize: 10.5, color: context.cMuted),
                  ),
              ]),
            ),
          ] else ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(widget.plan.limitLabel,
                  style: TextStyle(fontSize: 12, color: context.cMuted)),
            ),
          ],
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _operatorBtn('mtn', 'MTN MoMo', _scolarisMomoMtn, c)),
            const SizedBox(width: 10),
            Expanded(child: _operatorBtn('airtel', 'Airtel Money', _scolarisMomoAirtel, c)),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _reference,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Référence de transaction (reçue par SMS)',
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Icon(Icons.support_agent_rounded, size: 14, color: context.cMuted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                  'Une question, un souci avec le versement ? Contactez '
                  'Scolaris au $_scolarisContactPhone (WhatsApp).',
                  style: TextStyle(fontSize: 10.5, color: context.cMuted)),
            ),
          ]),
        ]),
      ),
      actions: [
        TextButton(
          onPressed: _processing ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _processing || charge == null || _reference.text.trim().isEmpty
              ? null
              : _pay,
          style: FilledButton.styleFrom(backgroundColor: c),
          child: _processing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Confirmer mon versement'),
        ),
      ],
    );
  }

  Widget _operatorBtn(String value, String label, String number, Color c) {
    final sel = _operator == value;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => setState(() => _operator = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: sel ? c.withValues(alpha: .12) : context.cCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: sel ? c : context.cBorder, width: sel ? 2 : 1),
          ),
          child: Column(children: [
            Text(label,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: sel ? c : context.cInk)),
            const SizedBox(height: 2),
            Text(number, style: TextStyle(fontSize: 11, color: context.cMuted)),
          ]),
        ),
      ),
    );
  }

  Widget _periodBtn(String label, bool sel, Color c, VoidCallback onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: sel ? c.withValues(alpha: .12) : context.cCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: sel ? c : context.cBorder, width: sel ? 2 : 1),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11.5,
                  color: sel ? c : context.cInk,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final SbSubscription? sub;
  final Color color;
  const _StatusBanner({required this.sub, required this.color});

  static String _fmtDate(DateTime d) {
    const months = ['jan.','fév.','mars','avr.','mai','juin',
                    'juil.','août','sep.','oct.','nov.','déc.'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final endDate = sub?.endDate;
    final endStr  = endDate != null ? _fmtDate(endDate) : null;

    final (label, detail, c) = switch (sub?.status) {
      'trial' => (
          'Essai gratuit',
          endStr != null
              ? 'Expire le $endStr (${sub!.daysLeft} j restants)'
              : 'En cours',
          const Color(0xFFC17F24),
        ),
      'active' => (
          'Abonnement actif',
          endStr != null ? 'Expire le $endStr' : 'Renouvellement automatique',
          const Color(0xFF15803D),
        ),
      'past_due' => ('Paiement en retard', 'Régularisez pour continuer', const Color(0xFFEA580C)),
      'expired' || 'canceled' => ('Abonnement expiré', 'Choisissez une offre', const Color(0xFFDC2626)),
      _ => ('Aucun abonnement', 'Démarrez votre essai', muted),
    };
    final planName = sub?.planCode != null ? sub!.planCode!.toUpperCase() : '—';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c.withValues(alpha: .14), c.withValues(alpha: .04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.withValues(alpha: .3)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: c.withValues(alpha: .15), shape: BoxShape.circle),
          child: Icon(Icons.workspace_premium_rounded, color: c, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: c.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Offre $planName',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c)),
              ),
            ]),
            const SizedBox(height: 3),
            Text(detail, style: TextStyle(fontSize: 12.5, color: context.cMuted)),
            if ((sub?.creditBalance ?? 0) > 0) ...[
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.savings_rounded, size: 12, color: Color(0xFF15803D)),
                const SizedBox(width: 4),
                Text(
                  'Crédit disponible : ${NumberFormat.decimalPattern('fr').format(sub!.creditBalance)} ${sub!.currency}',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF15803D), fontWeight: FontWeight.w600),
                ),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _UsageBar extends StatelessWidget {
  final int count;
  final int? limit;
  final NumberFormat fmt;
  const _UsageBar({required this.count, required this.limit, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final unlimited = limit == null;
    final ratio = unlimited ? 0.0 : (count / limit!).clamp(0.0, 1.0);
    final near = !unlimited && ratio >= 0.9;
    final barColor = near ? const Color(0xFFDC2626) : const Color(0xFF15803D);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('${fmt.format(count)} élève${count > 1 ? 's' : ''}',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: context.cInk)),
        Text(unlimited ? 'Illimité' : 'sur ${fmt.format(limit)}',
            style: TextStyle(fontSize: 13, color: context.cMuted)),
      ]),
      const SizedBox(height: 10),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: unlimited ? 1.0 : ratio,
          minHeight: 9,
          backgroundColor: context.cSubtle,
          valueColor: AlwaysStoppedAnimation(barColor),
        ),
      ),
      if (near) ...[
        const SizedBox(height: 8),
        Text('Vous approchez de la franchise incluse dans votre offre — un supplément de taille s\'applique au-delà.',
            style: TextStyle(fontSize: 12, color: barColor, fontWeight: FontWeight.w600)),
      ],
    ]);
  }
}

/// Ligne « Supplément de taille » — le nombre réel d'élèves dépasse la
/// franchise incluse dans l'offre (cf. `plan_size_surcharges`). Purement
/// informatif : la facturation reste manuelle (pas de prélèvement automatique).
class _SizeSurchargeRow extends StatelessWidget {
  final SbPlanSizeSurcharge surcharge;
  final NumberFormat fmt;
  const _SizeSurchargeRow({required this.surcharge, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final devis = surcharge.surcharge == null;
    final free = surcharge.surcharge == 0;
    final label = surcharge.maxStudents == null
        ? '${fmt.format(surcharge.minStudents)}+ élèves'
        : '${fmt.format(surcharge.minStudents)} – ${fmt.format(surcharge.maxStudents)} élèves';
    final valueText = devis
        ? 'Sur devis — contactez le support'
        : free
            ? 'Inclus (0 F)'
            : '+ ${fmt.format(surcharge.surcharge)} ${surcharge.currency} / mois';
    final color = devis ? const Color(0xFFC17F24) : free ? const Color(0xFF15803D) : context.cInk;
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text('Tranche actuelle : $label', style: TextStyle(fontSize: 13, color: context.cMuted)),
      Text(valueText, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
    ]);
  }
}

/// Modules actifs de l'école — modifiable après l'inscription (décision
/// utilisateur explicite). Décocher/cocher change ce qui apparaît dans le
/// tableau de bord de tout le monde (admin/enseignants/parents), cf. la
/// même logique de filtrage que dans `AdminHome`/`TeacherHome`/`StudentHome`.
class _ModulesPanel extends ConsumerStatefulWidget {
  const _ModulesPanel();
  @override
  ConsumerState<_ModulesPanel> createState() => _ModulesPanelState();
}

class _ModulesPanelState extends ConsumerState<_ModulesPanel> {
  Set<String>? _draft;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final school = ref.watch(schoolProvider).valueOrNull;
    final saved = (school?.modules.isNotEmpty ?? false) ? school!.modules.toSet() : kAppModules.map((m) => m.id).toSet();
    final selected = _draft ?? saved;
    final dirty = _draft != null && !setEquals(_draft, saved);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final m in kAppModules)
        CheckboxListTile(
          value: selected.contains(m.id),
          onChanged: school == null ? null : (v) => setState(() {
            final next = Set<String>.from(selected);
            if (v == true) { next.add(m.id); } else { next.remove(m.id); }
            _draft = next;
          }),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          dense: true,
          title: Text(m.label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: context.cInk)),
          subtitle: Text(m.description, style: TextStyle(fontSize: 11.5, color: context.cMuted)),
        ),
      if (dirty) ...[
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Text(
            selected.isEmpty
                ? 'Aucun module actif : seules les fonctionnalités essentielles resteront visibles.'
                : 'Le prix de votre offre peut changer selon le nombre de modules actifs.',
            style: TextStyle(fontSize: 11.5, color: context.cMuted))),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => setState(() => _draft = null),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: _saving || school == null ? null : () async {
              setState(() => _saving = true);
              try {
                await SupabaseDbSource.updateSchoolModules(school.id, selected.toList());
                ref.invalidate(schoolProvider);
                if (mounted) setState(() => _draft = null);
              } finally {
                if (mounted) setState(() => _saving = false);
              }
            },
            child: Text(_saving ? 'Enregistrement…' : 'Enregistrer'),
          ),
        ]),
      ],
    ]);
  }
}

/// Historique des versements d'abonnement — chaque ligne est un reçu
/// ré-téléchargeable (PDF Scolaris → école).
class _BillingHistory extends ConsumerWidget {
  final Map<String, String> planNameByCode;
  final NumberFormat fmt;
  const _BillingHistory({required this.planNameByCode, required this.fmt});

  static const _months = ['jan.','fév.','mars','avr.','mai','juin',
                          'juil.','août','sep.','oct.','nov.','déc.'];
  static String _fmtDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(subscriptionPaymentsProvider);
    final school = ref.watch(schoolProvider).valueOrNull;

    return paymentsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text('Erreur : $e',
          style: TextStyle(fontSize: 12, color: context.cMuted)),
      data: (payments) {
        if (payments.isEmpty) {
          return Row(children: [
            Icon(Icons.receipt_long_rounded, size: 18, color: context.cMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Aucun paiement pour le moment. Votre reçu apparaîtra '
                  'ici dès votre premier règlement.',
                  style: TextStyle(fontSize: 12.5, color: context.cMuted)),
            ),
          ]);
        }
        return Column(children: [
          for (var i = 0; i < payments.length; i++) ...[
            _row(context, payments[i], school),
            if (i < payments.length - 1)
              Divider(height: 16, color: context.cBorder),
          ],
        ]);
      },
    );
  }

  Widget _row(BuildContext context, SbSubscriptionPayment p, SbSchool? school) {
    final planName = planNameByCode[p.planCode] ?? (p.planCode ?? '—').toUpperCase();
    final periodLabel = p.isYearly ? 'annuel' : 'mensuel';
    final icon = Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF15803D).withValues(alpha: .12),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF15803D)),
    );
    final info = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Offre $planName · $periodLabel',
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: context.cInk)),
      const SizedBox(height: 2),
      Text('${_fmtDate(p.date)} · Réf. ${p.reference ?? p.id.substring(0, 8).toUpperCase()}',
          style: TextStyle(fontSize: 11, color: context.cMuted)),
    ]);
    final amount = Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text('${fmt.format(p.amount)} ${p.currency}',
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: context.cInk)),
      if (p.creditApplied > 0.01)
        Text('crédit − ${fmt.format(p.creditApplied)}',
            style: const TextStyle(fontSize: 10, color: Color(0xFF15803D))),
    ]);
    final downloadBtn = IconButton(
      tooltip: 'Télécharger le reçu',
      icon: const Icon(Icons.download_rounded, size: 20),
      color: const Color(0xFF8B1A00),
      onPressed: () => printSubscriptionReceipt(
          school: school, payment: p, planName: planName),
    );

    return LayoutBuilder(builder: (_, constraints) {
      if (constraints.maxWidth < 380) {
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [icon, const SizedBox(width: 12), Expanded(child: info)]),
          const SizedBox(height: 8),
          Row(children: [
            const SizedBox(width: 44),
            Expanded(child: Align(alignment: Alignment.centerLeft, child: amount)),
            downloadBtn,
          ]),
        ]);
      }
      return Row(children: [
        icon,
        const SizedBox(width: 12),
        Expanded(child: info),
        const SizedBox(width: 8),
        amount,
        downloadBtn,
      ]);
    });
  }
}

class _ProratRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool bold;
  const _ProratRow({required this.label, required this.value, required this.color, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 11.5,
      color: color,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
    );
    return Row(children: [
      Expanded(child: Text(label, style: style)),
      Text(value, style: style),
    ]);
  }
}

class _PlanCard extends StatelessWidget {
  final SbPlan plan;
  final double? monthly;
  final String currency;
  final Color color;
  final bool isCurrent;
  final NumberFormat fmt;
  final VoidCallback onChoose;

  const _PlanCard({
    required this.plan,
    required this.monthly,
    required this.currency,
    required this.color,
    required this.isCurrent,
    required this.fmt,
    required this.onChoose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrent ? color.withValues(alpha: .06) : context.cCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrent ? color : context.cBorder,
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(plan.name,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
          const Spacer(),
          if (isCurrent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('Actuelle',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
            ),
        ]),
        if (plan.tagline != null) ...[
          const SizedBox(height: 2),
          Text(plan.tagline!, style: TextStyle(fontSize: 12, color: context.cMuted)),
        ],
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic,
          children: [
            Text(monthly != null ? fmt.format(monthly) : '—',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(width: 4),
            Text('$currency /mois', style: TextStyle(fontSize: 11.5, color: context.cMuted)),
          ],
        ),
        if (monthly != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF15803D).withValues(alpha: .10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.savings_rounded, size: 13, color: Color(0xFF15803D)),
              const SizedBox(width: 5),
              Text('${fmt.format(monthly! * 10)} $currency /an',
                  style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF15803D))),
              const SizedBox(width: 5),
              const Text('· 2 mois offerts',
                  style: TextStyle(fontSize: 10.5, color: Color(0xFF15803D))),
            ]),
          ),
        ],
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(plan.limitLabel,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
        ),
        if (plan.features.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final f in plan.features)
            if (_planNames.containsKey(f))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('Tout ${_planNames[f]} +',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w800, color: color)),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.check_circle_rounded, size: 14, color: color),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(_featureLabels[f] ?? f,
                        style: TextStyle(fontSize: 12, color: context.cInk, height: 1.3)),
                  ),
                ]),
              ),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: isCurrent
              ? OutlinedButton(
                  onPressed: null,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: color.withValues(alpha: .4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text('Offre actuelle', style: TextStyle(color: color)),
                )
              : ElevatedButton(
                  onPressed: onChoose,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Choisir cette offre',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
        ),
      ]),
    );
  }
}
