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
                const Text(
                  'Choose the plan that fits your goals',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'All paid plans include nutritionist support.',
                  style: TextStyle(color: Colors.grey.shade700, height: 1.4),
                ),
                const SizedBox(height: 16),
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
                  badge: 'Paid',
                  priceLabel: _formatPrice(regionPricing, 'pro'),
                  description: const [
                    '7 AI-generated recipes per month',
                    'WhatsApp message scheduling',
                    'Voice notes for 30 days',
                  ],
                  buttonLabel: 'Upgrade to Pro',
                  accent: kPrimary,
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
                  badge: 'Paid',
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pick a subscription duration',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
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
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(duration.label),
                  subtitle: duration.discountPct > 0
                      ? Text('Save ${duration.discountPct}%')
                      : const Text('Standard price'),
                  trailing: Text(
                    '${regionPricing.symbol}$finalPrice',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onTap: () => Navigator.pop(
                    context,
                    _DurationSelection(duration: duration, price: price),
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
  });

  final String title;
  final String badge;
  final String priceLabel;
  final List<String> description;
  final String buttonLabel;
  final Color accent;
  final VoidCallback? onTap;
  final bool buttonEnabled;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                Text(
                  priceLabel,
                  style: TextStyle(fontWeight: FontWeight.w700, color: accent),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(color: accent, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
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
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: buttonEnabled ? onTap : null,
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
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
