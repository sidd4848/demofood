import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/app_data.dart';
import '../services/profile_service.dart';
import '../services/plan_access.dart';
import '../theme.dart';
import '../widgets/app_sidebar_shell.dart';
import '../app.dart';
import 'diet_plan_page.dart';
import 'nutritionist_profiles_page.dart';
import 'upgrade_plan_page.dart';

class DietGenerationOptionsPage extends StatefulWidget {
  final AppData data;
  final WidgetBuilder preferencesBuilder;

  const DietGenerationOptionsPage({
    super.key,
    required this.data,
    required this.preferencesBuilder,
  });

  @override
  State<DietGenerationOptionsPage> createState() => _DietGenerationOptionsPageState();
}

class _DietGenerationOptionsPageState extends State<DietGenerationOptionsPage> {
  bool _isSavingSelf = false;
  late Future<_AccessSnapshot> _accessFuture;

  @override
  void initState() {
    super.initState();
    _accessFuture = _loadAccess();
  }

  Future<_AccessSnapshot> _loadAccess() async {
    final results = await Future.wait([
      fetchUserSubscription(),
      fetchUserQuotaSummary(),
    ]);
    return _AccessSnapshot(
      subscription: results[0] as SubscriptionSummary?,
      quota: results[1] as UserQuotaSummary?,
    );
  }

  void _showUpgradeDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Upgrade plan"),
        content: const Text("Upgrade to unlock this experience."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Back"),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => UpgradePlanPage(data: widget.data)),
              );
            },
            child: const Text("Upgrade plan"),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => LandingPage(data: widget.data)),
      (_) => false,
    );
  }

  Future<void> _saveChoiceAndOpen(BuildContext context, String generatedBy) async {
    if (generatedBy == 'self') {
      setState(() {
        _isSavingSelf = true;
      });
    }
    await saveDietGenerationChoice(generatedBy);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => DietPlanPage(
          data: widget.data,
          preferencesBuilder: widget.preferencesBuilder,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppSidebarShell(
      selectedIndex: 1,
      onSignOut: _signOut,
      onDestinationSelected: (index) async {
        switch (index) {
          case 0:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => DietPlanPage(
                  data: widget.data,
                  preferencesBuilder: widget.preferencesBuilder,
                ),
              ),
            );
            return;
          case 1:
            return;
          case 2:
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => UpgradePlanPage(data: widget.data)),
            );
            return;
          case 3:
            final access = await _accessFuture;
            final tier = resolvePlanTier(access.subscription);
            if (!canAccessNutritionist(tier)) {
              _showUpgradeDialog();
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NutritionistProfilesPage(
                  data: widget.data,
                  preferencesBuilder: widget.preferencesBuilder,
                ),
              ),
            );
            return;
        }
      },
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            tooltip: 'Menu',
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text("Choose your plan style"),
      ),
      child: FutureBuilder<_AccessSnapshot>(
        future: _accessFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Unable to load plan access right now.'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {
                      setState(() {
                        _accessFuture = _loadAccess();
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          final access = snapshot.data;
          final planTier = resolvePlanTier(access?.subscription);
          final canUseNutritionist = canAccessNutritionist(planTier);
          final canUseAi = planTier == PlanTier.elite ||
              planTier == PlanTier.pro ||
              planTier == PlanTier.trial;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                "How would you like to generate your diet plan?",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text(
                "Pick the experience that fits you best. You can change this later.",
                style: TextStyle(color: Colors.grey.shade700, height: 1.4),
              ),
              const SizedBox(height: 24),
              _OptionCard(
                title: "Generate diet with AI",
                description: "Fast, smart suggestions tailored to your profile.",
                icon: Icons.auto_awesome_rounded,
                accent: kPrimary,
                onTap: () {
                  if (!canUseAi) {
                    _showUpgradeDialog();
                    return;
                  }
                  _saveChoiceAndOpen(context, 'ai');
                },
              ),
              const SizedBox(height: 16),
              _OptionCard(
                title: "Generate diet with Expert Nutritioner",
                description: "Hand-crafted guidance from a nutrition professional.",
                icon: Icons.health_and_safety_rounded,
                accent: kSecondary,
                onTap: () {
                  if (!canUseNutritionist) {
                    _showUpgradeDialog();
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NutritionistProfilesPage(
                        data: widget.data,
                        preferencesBuilder: widget.preferencesBuilder,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              _OptionCard(
                title: "Generate diet with yourself (Expert you!)",
                description: "Use your own expertise and preferences to guide the plan.",
                icon: Icons.self_improvement_rounded,
                accent: Colors.deepPurple,
                isLoading: _isSavingSelf,
                onTap: _isSavingSelf ? null : () => _saveChoiceAndOpen(context, 'self'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AccessSnapshot {
  final SubscriptionSummary? subscription;
  final UserQuotaSummary? quota;

  const _AccessSnapshot({
    required this.subscription,
    required this.quota,
  });
}

class _OptionCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;
  final String? disabledLabel;
  final bool isLoading;

  const _OptionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.accent,
    required this.onTap,
    this.disabledLabel,
    this.isLoading = false,
  });

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
                Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: accent.withOpacity(0.15),
                  ),
                  child: Icon(icon, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(color: Colors.grey.shade700, height: 1.4),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: onTap == null
                  ? OutlinedButton(
                      onPressed: null,
                      child: Text(disabledLabel ?? "Unavailable"),
                    )
                  : FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: onTap,
                      child: isLoading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text("Continue"),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
