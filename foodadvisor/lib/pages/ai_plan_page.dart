import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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
  static final Uri _generateDietEndpoint =
      Uri.parse('https://generate-diet-by-ai-b2g4omif7q-uc.a.run.app');

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
      final response = await http.post(
        _generateDietEndpoint,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'data': {
            'user_id': user.uid,
            'userId': user.uid,
          },
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('Request failed with ${response.statusCode}: ${response.body}. Sent payload with top-level data object.');
      }

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
