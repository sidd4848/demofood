import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/app_data.dart';
import '../services/profile_service.dart';
import '../theme.dart';
import 'diet_plan_page.dart';

class AiPlanPage extends StatefulWidget {
  final AppData data;
  final WidgetBuilder preferencesBuilder;

  const AiPlanPage({
    super.key,
    required this.data,
    required this.preferencesBuilder,
  });

  @override
  State<AiPlanPage> createState() => _AiPlanPageState();
}

class _AiPlanPageState extends State<AiPlanPage> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _requestAiDiet();
  }

  Future<void> _requestAiDiet() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _error = 'No authenticated user.';
      });
      return;
    }

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('generate_diet_by_ai');
      await callable.call(<String, dynamic>{
        'userId': user.uid,
        'type_request': 'generate_diet'
      });

      await saveDietGenerationChoice('ai');

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
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    }
  }

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
                'Diet is loading soon',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              if (_error == null) ...[
                Text(
                  'Please wait while we generate your AI plan.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 20),
                const CircularProgressIndicator(),
              ] else ...[
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _requestAiDiet,
                  child: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
