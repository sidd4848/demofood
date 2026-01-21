import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/app_data.dart';
import '../services/nutritionist_service.dart';
import '../services/plan_access.dart';
import '../services/profile_service.dart';
import '../theme.dart';
import '../widgets/app_sidebar_shell.dart';
import '../app.dart';
import 'diet_generation_options_page.dart';
import 'diet_plan_page.dart';
import 'upgrade_plan_page.dart';

class NutritionistProfilesPage extends StatelessWidget {
  final AppData data;
  final WidgetBuilder preferencesBuilder;

  const NutritionistProfilesPage({
    super.key,
    required this.data,
    required this.preferencesBuilder,
  });

  @override
  Widget build(BuildContext context) {
    const service = NutritionistService();
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
      selectedIndex: 3,
      onSignOut: signOut,
      onDestinationSelected: (index) {
        switch (index) {
          case 0:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => DietPlanPage(
                  data: data,
                  preferencesBuilder: preferencesBuilder,
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
                  preferencesBuilder: preferencesBuilder,
                ),
              ),
            );
            return;
          case 2:
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => UpgradePlanPage(data: data)),
            );
            return;
          case 3:
            return;
        }
      },
      appBar: AppBar(
        title: const Text('Nutrition experts'),
      ),
      child: FutureBuilder<SubscriptionSummary?>(
        future: fetchUserSubscription(),
        builder: (context, subscriptionSnapshot) {
          final tier = resolvePlanTier(subscriptionSnapshot.data);
          if (!canAccessNutritionist(tier)) {
            return _LockedNutritionistState(
              onBack: () => Navigator.pop(context),
              onUpgrade: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => UpgradePlanPage(data: data)),
                );
              },
            );
          }
          return FutureBuilder<List<NutritionistProfile>>(
            future: service.fetchProfiles(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Unable to load nutrition experts.',
                    style: TextStyle(color: Colors.red.shade400),
                  ),
                );
              }
              final profiles = snapshot.data ?? const <NutritionistProfile>[];
              if (profiles.isEmpty) {
                return const Center(child: Text('No nutrition experts available right now.'));
              }
              return ListView.separated(
                padding: const EdgeInsets.all(24),
                itemCount: profiles.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final profile = profiles[index];
                  return _NutritionistCard(profile: profile);
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _LockedNutritionistState extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onUpgrade;

  const _LockedNutritionistState({
    required this.onBack,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: kSecondary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.lock_outline, color: kSecondary),
              ),
              const SizedBox(height: 14),
              const Text(
                'Elite-only access',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Upgrade to Elite to connect with a nutrition expert.',
                style: TextStyle(color: Colors.grey.shade700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onBack,
                      child: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: onUpgrade,
                      child: const Text('Upgrade plan'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NutritionistCard extends StatelessWidget {
  final NutritionistProfile profile;

  const _NutritionistCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: kPrimary.withOpacity(0.15),
                  child: Icon(Icons.person, color: kPrimary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(profile.specialty, style: TextStyle(color: Colors.grey.shade700)),
                    ],
                  ),
                ),
                _RatingPill(rating: profile.rating),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.work_outline, size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(profile.experience, style: TextStyle(color: Colors.grey.shade700)),
                const SizedBox(width: 12),
                Icon(Icons.place_outlined, size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(profile.location, style: TextStyle(color: Colors.grey.shade700)),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Request sent to ${profile.name}')),
                  );
                },
                icon: const Icon(Icons.call_outlined),
                label: const Text('Request call'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingPill extends StatelessWidget {
  final double rating;

  const _RatingPill({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: kSecondary.withOpacity(0.15),
      ),
      child: Row(
        children: [
          Icon(Icons.star, size: 16, color: kSecondary),
          const SizedBox(width: 4),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(fontWeight: FontWeight.w700, color: kSecondary),
          ),
        ],
      ),
    );
  }
}
