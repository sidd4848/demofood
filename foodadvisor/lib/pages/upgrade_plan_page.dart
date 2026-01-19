import 'package:flutter/material.dart';

import '../services/subscription_service.dart';
import '../theme.dart';

class UpgradePlanPage extends StatelessWidget {
  const UpgradePlanPage({super.key});

  @override
  Widget build(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    final service = const SubscriptionService();

    return Scaffold(
      appBar: AppBar(title: const Text('Upgrade plan')),
      body: SafeArea(
        child: ListView(
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
              description: const [
                '7 AI-generated recipes per month',
                'WhatsApp message scheduling',
                'Voice notes for 30 days',
              ],
              buttonLabel: 'Upgrade to Pro',
              accent: kPrimary,
              onTap: () async {
                await service.requestSubscriptionUpgrade(planId: 'pro');
                messenger.showSnackBar(
                  const SnackBar(content: Text('Upgrade flow is being set up.')),
                );
              },
            ),
            const SizedBox(height: 16),
            _PlanCard(
              title: 'Elite',
              badge: 'Paid',
              description: const [
                'Everything in Pro',
                'Unlimited recipe generation',
                'Priority nutritionist support',
              ],
              buttonLabel: 'Upgrade to Elite',
              accent: kSecondary,
              onTap: () async {
                await service.requestSubscriptionUpgrade(planId: 'elite');
                messenger.showSnackBar(
                  const SnackBar(content: Text('Upgrade flow is being set up.')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.badge,
    required this.description,
    required this.buttonLabel,
    required this.accent,
    this.onTap,
    this.buttonEnabled = true,
  });

  final String title;
  final String badge;
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
