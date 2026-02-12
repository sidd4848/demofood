import 'package:flutter/material.dart';

import '../models/app_data.dart';
import '../theme.dart';
import 'diet_plan_page.dart';

class AiPlanPage extends StatelessWidget {
  final AppData data;
  final WidgetBuilder preferencesBuilder;

  const AiPlanPage({
    super.key,
    required this.data,
    required this.preferencesBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Plan')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_rounded, size: 54, color: kPrimary),
              const SizedBox(height: 16),
              const Text(
                'AI plan page',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text(
                'You have access to AI plans. Continue to your diet plan dashboard from here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DietPlanPage(
                        data: data,
                        preferencesBuilder: preferencesBuilder,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.restaurant_menu_rounded),
                label: const Text('Open diet plan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
