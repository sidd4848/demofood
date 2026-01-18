import 'package:flutter/material.dart';

import '../models/app_data.dart';
import '../theme.dart';
import 'diet_plan_page.dart';

class DietGenerationOptionsPage extends StatelessWidget {
  final AppData data;
  final WidgetBuilder preferencesBuilder;

  const DietGenerationOptionsPage({
    super.key,
    required this.data,
    required this.preferencesBuilder,
  });

  void _openDietPlan(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => DietPlanPage(
          data: data,
          preferencesBuilder: preferencesBuilder,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Choose your plan style"),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              "How would you like to generate your diet plan?",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              "Pick the experience that fits you best. You can change this later.",
              style: TextStyle(color: Colors.grey.shade700, height: 1.4),
            ),
            const SizedBox(height: 20),
            _OptionCard(
              title: "Generate diet with AI",
              description: "Fast, smart suggestions tailored to your profile.",
              icon: Icons.auto_awesome_rounded,
              accent: kPrimary,
              onTap: () => _openDietPlan(context),
            ),
            const SizedBox(height: 16),
            _OptionCard(
              title: "Generate diet with Expert Nutritioner",
              description: "Hand-crafted guidance from a nutrition professional.",
              icon: Icons.health_and_safety_rounded,
              accent: kSecondary,
              onTap: () => _openDietPlan(context),
            ),
            const SizedBox(height: 16),
            _OptionCard(
              title: "Generate diet with yourself (Expert you!)",
              description: "Use your own expertise and preferences to guide the plan.",
              icon: Icons.self_improvement_rounded,
              accent: Colors.deepPurple,
              onTap: () => _openDietPlan(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _OptionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.accent,
    required this.onTap,
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
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: onTap,
                child: const Text("Continue"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
