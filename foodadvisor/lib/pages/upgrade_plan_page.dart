import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../app.dart';
import '../models/app_data.dart';
import '../services/profile_service.dart';
import '../services/subscription_models.dart';
import '../services/subscription_service.dart';
import '../theme.dart';
import '../widgets/branding.dart';
import '../widgets/app_sidebar_shell.dart';
import 'diet_generation_options_page.dart';
import 'diet_plan_page.dart';
import 'nutritionist_profiles_page.dart';

class UpgradePlanPage extends StatelessWidget {
  final AppData data;

  const UpgradePlanPage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    final service = const SubscriptionService();
    final locale = Localizations.localeOf(context);
    final dataFuture = _loadData(service);
    Future<void> signOut() async {
      await FirebaseAuth.instance.signOut();
      await GoogleSignIn().signOut();
      if (!context.mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => LandingPage(data: data)),
        (_) => false,
      );
    }

    return AppSidebarShell(
      selectedIndex: 2,
      onSignOut: signOut,
      onDestinationSelected: (index) {
        switch (index) {
          case 0:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => DietPlanPage(
                  data: data,
                  preferencesBuilder: (_) => PreferencesPage(data: data),
                ),
              ),
            );
            return;
          case 1:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => DietGenerationOptionsPage(
                  data: data,
                  preferencesBuilder: (_) => PreferencesPage(data: data),
                ),
              ),
            );
            return;
          case 2:
            return;
          case 3:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NutritionistProfilesPage(
                  data: data,
                  preferencesBuilder: (_) => PreferencesPage(data: data),
                ),
              ),
            );
            return;
        }
      },
      appBar: AppBar(
        title: const Text('Upgrade plan'),
        leading: const BackButton(),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FutureBuilder<_UpgradePlanData>(
              future: dataFuture,
              builder: (context, snapshot) {
                final label = _planLabel(snapshot.data?.subscription);
                return PlanBadge(label: label);
              },
            ),
          ),
        ],
      ),
      child: FutureBuilder<_UpgradePlanData>(
        future: dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final dataBundle = snapshot.data;
          if (dataBundle == null) {
            return const Center(child: Text('Unable to load pricing.'));
          }
          final config = dataBundle.config;
          final subscription = dataBundle.subscription;
          final regionCode = data.regionCode ?? locale.countryCode ?? 'IN';
          final regionPricing = config.resolveRegion(regionCode);
          final activePlan = subscription?.plan.toLowerCase() ?? 'free';
          final isProOrElite = activePlan == 'pro' || activePlan == 'elite';
          final daysRemaining = _daysRemaining(subscription?.currentPeriodEnd);
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _UpgradeHero(),
              const SizedBox(height: 24),
              _PlanCard(
                title: 'Free',
                badge: 'Trial',
                priceLabel: _formatPrice(regionPricing, 'free'),
                description: const [
                  '10 days trial of Elite features',
                  'No card required for trial',
                ],
                buttonLabel: isProOrElite ? 'Free trial' : 'Current plan',
                buttonEnabled: false,
                accent: Colors.grey,
                compact: isProOrElite,
              ),
              const SizedBox(height: 16),
              _PlanCard(
                title: 'Pro',
                badge: 'Most popular',
                priceLabel: _formatPrice(regionPricing, 'pro'),
                description: const [
                  '7 AI-generated recipes per month',
                  'WhatsApp message scheduling',
                  'Voice notes for 30 days',
                ],
                buttonLabel: activePlan == 'pro' ? 'Current plan' : 'Upgrade to Pro',
                buttonEnabled: activePlan != 'pro',
                accent: kPrimary,
                highlight: true,
                footerText: activePlan == 'pro' && daysRemaining != null
                    ? '$daysRemaining days remaining'
                    : null,
                extraAction: _buildExtendAction(
                  context,
                  service: service,
                  config: config,
                  regionPricing: regionPricing,
                  planId: 'pro',
                  daysRemaining: daysRemaining,
                  messenger: messenger,
                ),
                onTap: activePlan == 'pro'
                    ? null
                    : () async {
                        final selection = await _showDurationPicker(
                          context,
                          config: config,
                          regionPricing: regionPricing,
                          planId: 'pro',
                        );
                        if (selection == null) return;
                        await service.requestSubscriptionUpgrade(
                          planId: 'pro',
                          duration: selection.duration,
                          price: selection.price,
                        );
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Upgrade request saved.')),
                        );
                      },
              ),
              const SizedBox(height: 16),
              _PlanCard(
                title: 'Elite',
                badge: 'Premium',
                priceLabel: _formatPrice(regionPricing, 'elite'),
                description: const [
                  'Everything in Pro',
                  'Unlimited recipe generation',
                  'Priority nutritionist support',
                ],
                buttonLabel: activePlan == 'elite' ? 'Current plan' : 'Upgrade to Elite',
                buttonEnabled: activePlan != 'elite',
                accent: kSecondary,
                footerText: activePlan == 'elite' && daysRemaining != null
                    ? '$daysRemaining days remaining'
                    : null,
                extraAction: _buildExtendAction(
                  context,
                  service: service,
                  config: config,
                  regionPricing: regionPricing,
                  planId: 'elite',
                  daysRemaining: daysRemaining,
                  messenger: messenger,
                ),
                onTap: activePlan == 'elite'
                    ? null
                    : () async {
                        final selection = await _showDurationPicker(
                          context,
                          config: config,
                          regionPricing: regionPricing,
                          planId: 'elite',
                        );
                        if (selection == null) return;
                        await service.requestSubscriptionUpgrade(
                          planId: 'elite',
                          duration: selection.duration,
                          price: selection.price,
                        );
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Upgrade request saved.')),
                        );
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatPrice(RegionPricing pricing, String planId) {
    final price = pricing.priceForPlan(planId);
    return '${pricing.symbol}$price';
  }

  Future<_DurationSelection?> _showDurationPicker(
    BuildContext context, {
    required SubscriptionConfig config,
    required RegionPricing regionPricing,
    required String planId,
  }) {
    final basePrice = regionPricing.priceForPlan(planId);
    final durations = config.sortedDurations();
    return showModalBottomSheet<_DurationSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Pick a subscription duration',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Save more when you choose longer plans.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              ...durations.map((duration) {
                final total = basePrice * duration.months;
                final discount = (total * duration.discountPct / 100).round();
                final finalPrice = total - discount;
                final price = SubscriptionPrice(
                  region: regionPricing.region,
                  currency: regionPricing.currency,
                  symbol: regionPricing.symbol,
                  basePrice: total,
                  discountPct: duration.discountPct,
                  finalPrice: finalPrice,
                );
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Text(duration.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: duration.discountPct > 0
                        ? Text('Save ${duration.discountPct}%')
                        : const Text('Standard price'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${regionPricing.symbol}$finalPrice',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        if (duration.discountPct > 0)
                          Text(
                            '${regionPricing.symbol}$total',
                            style: const TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    onTap: () => Navigator.pop(
                      context,
                      _DurationSelection(duration: duration, price: price),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Future<_UpgradePlanData> _loadData(SubscriptionService service) async {
    final results = await Future.wait([
      service.fetchConfig(),
      fetchUserSubscription(),
    ]);
    return _UpgradePlanData(
      config: results[0] as SubscriptionConfig,
      subscription: results[1] as SubscriptionSummary?,
    );
  }

  String _planLabel(SubscriptionSummary? summary) {
    if (summary == null) return 'Free';
    final plan = summary.plan.toLowerCase();
    if (plan == 'free' && summary.status.toLowerCase() == 'trial') {
      return 'Trial';
    }
    if (plan == 'elite') return 'Elite';
    if (plan == 'pro') return 'Pro';
    return 'Free';
  }

  int? _daysRemaining(DateTime? currentPeriodEnd) {
    if (currentPeriodEnd == null) return null;
    final now = DateTime.now();
    final diff = currentPeriodEnd.difference(now).inDays;
    return diff >= 0 ? diff : 0;
  }

  Widget? _buildExtendAction(
    BuildContext context, {
    required SubscriptionService service,
    required SubscriptionConfig config,
    required RegionPricing regionPricing,
    required String planId,
    required int? daysRemaining,
    required ScaffoldMessengerState messenger,
  }) {
    if (daysRemaining == null || daysRemaining >= 90) return null;
    final yearly = config.durations['yearly'];
    if (yearly == null) return null;
    return TextButton(
      onPressed: () async {
        final total = regionPricing.priceForPlan(planId) * yearly.months;
        final discount = (total * yearly.discountPct / 100).round();
        final finalPrice = total - discount;
        final price = SubscriptionPrice(
          region: regionPricing.region,
          currency: regionPricing.currency,
          symbol: regionPricing.symbol,
          basePrice: total,
          discountPct: yearly.discountPct,
          finalPrice: finalPrice,
        );
        await service.requestSubscriptionUpgrade(
          planId: planId,
          duration: yearly,
          price: price,
        );
        messenger.showSnackBar(
          const SnackBar(content: Text('Yearly extension requested.')),
        );
      },
      child: const Text('Extend to yearly'),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.badge,
    required this.priceLabel,
    required this.description,
    required this.buttonLabel,
    required this.accent,
    this.onTap,
    this.buttonEnabled = true,
    this.highlight = false,
    this.compact = false,
    this.footerText,
    this.extraAction,
  });

  final String title;
  final String badge;
  final String priceLabel;
  final List<String> description;
  final String buttonLabel;
  final Color accent;
  final VoidCallback? onTap;
  final bool buttonEnabled;
  final bool highlight;
  final bool compact;
  final String? footerText;
  final Widget? extraAction;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ListTile(
          leading: Icon(Icons.lock_outline, color: accent),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(badge),
          trailing: Text(priceLabel, style: TextStyle(color: accent, fontWeight: FontWeight.w700)),
        ),
      );
    }
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: highlight ? 8 : 2,
      shadowColor: accent.withOpacity(0.2),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: highlight ? accent.withOpacity(0.4) : Colors.transparent),
          gradient: highlight
              ? LinearGradient(
                  colors: [accent.withOpacity(0.12), Colors.transparent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.stars_rounded, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  priceLabel,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: accent),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge,
                  style: TextStyle(color: accent, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...description.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle, size: 18, color: accent),
                    const SizedBox(width: 8),
                    Expanded(child: Text(line)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (footerText != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  footerText!,
                  style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: buttonEnabled ? onTap : null,
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(buttonLabel),
              ),
            ),
            if (extraAction != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: extraAction!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DurationSelection {
  final SubscriptionDuration duration;
  final SubscriptionPrice price;

  const _DurationSelection({required this.duration, required this.price});
}

class _UpgradePlanData {
  final SubscriptionConfig config;
  final SubscriptionSummary? subscription;

  const _UpgradePlanData({required this.config, required this.subscription});
}

class _UpgradeHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Theme.of(context).cardColor,
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Upgrade your nutrition',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Unlock smarter AI plans, priority support, and weekly check-ins.',
                  style: TextStyle(color: Colors.grey.shade700, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            height: 56,
            width: 56,
            decoration: BoxDecoration(
              color: kPrimary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.rocket_launch_rounded, color: kPrimary),
          ),
        ],
      ),
    );
  }
}
