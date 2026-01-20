import 'package:flutter/material.dart';

import '../models/app_data.dart';
import '../services/subscription_service.dart';
import '../theme.dart';

class UpgradePlanPage extends StatelessWidget {
  final AppData data;

  const UpgradePlanPage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    final service = const SubscriptionService();
    final locale = Localizations.localeOf(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Upgrade plan')),
      body: SafeArea(
        child: FutureBuilder<SubscriptionConfig>(
          future: service.fetchConfig(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final config = snapshot.data;
            if (config == null) {
              return const Center(child: Text('Unable to load pricing.'));
            }
            final regionCode = data.regionCode ?? locale.countryCode ?? 'IN';
            final regionPricing = config.resolveRegion(regionCode);
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _UpgradeHero(),
                const SizedBox(height: 20),
                _PlanCard(
                  title: 'Free',
                  badge: 'Trial',
                  priceLabel: _formatPrice(regionPricing, 'free'),
                  description: const [
                    '10 days trial of Elite features',
                    'No card required for trial',
                  ],
                  buttonLabel: 'Current plan',
                  buttonEnabled: false,
                  accent: Colors.grey,
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
                  buttonLabel: 'Upgrade to Pro',
                  accent: kPrimary,
                  highlight: true,
                  onTap: () async {
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
                  buttonLabel: 'Upgrade to Elite',
                  accent: kSecondary,
                  onTap: () async {
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

  @override
  Widget build(BuildContext context) {
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

class _UpgradeHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [kPrimary, kSecondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Upgrade your nutrition',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Unlock smarter AI plans, priority support, and weekly check-ins.',
                  style: TextStyle(color: Colors.white.withOpacity(0.9), height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            height: 56,
            width: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.rocket_launch_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
