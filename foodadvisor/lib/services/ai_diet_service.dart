import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../models/app_data.dart';

class AiDietService {
  const AiDietService();

  static const collectionName = 'dietPlans';
  static final Uri _generateDietEndpoint =
      Uri.parse('https://generate-diet-by-ai-b2g4omif7q-uc.a.run.app');

  Future<int> countRecentRequests({required String userId, Duration window = const Duration(days: 7)}) async {
    final since = DateTime.now().subtract(window);
    final snapshot = await FirebaseFirestore.instance
        .collection(collectionName)
        .where('userId', isEqualTo: userId)
        .get();
    return snapshot.docs.where((doc) {
      final createdAt = doc.data()['createdAt'];
      return createdAt is Timestamp && !createdAt.toDate().isBefore(since);
    }).length;
  }

  Future<bool> hasRecentRequest({required String userId}) async {
    final since = DateTime.now().subtract(const Duration(days: 7));
    final snapshot = await FirebaseFirestore.instance
        .collection(collectionName)
        .where('userId', isEqualTo: userId)
        .limit(20)
        .get();
    for (final doc in snapshot.docs) {
      final createdAt = doc.data()['createdAt'];
      if (createdAt is Timestamp && createdAt.toDate().isAfter(since)) {
        return true;
      }
    }
    return false;
  }

  Future<DocumentReference<Map<String, dynamic>>> requestPlan({
    required AppData data,
    required String? jobId,
    String? tweaks,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('No authenticated user.');
    }
    final template = await _fetchPromptTemplate();
    final prompt = _applyTemplate(data, template, tweaks: tweaks);
    final payload = <String, dynamic>{
      'userId': user.uid,
      'jobId': jobId,
      'model': 'gemini-1.5-pro',
      'status': 'pending',
      'prompt': prompt,
      'responseSchema': _responseSchema(),
      'responseFormat': 'json',
      'generatedBy': 'ai',
      'createdAt': DateTime.now().toIso8601String(),
    };

    final response = await http.post(
      _generateDietEndpoint,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('AI diet request failed: ${response.statusCode} ${response.body}');
    }

    final resultData = _decodeResponseBody(response.body);
    final requestId = _extractRequestId(resultData);

    if (requestId != null && requestId.isNotEmpty) {
      return FirebaseFirestore.instance.collection(collectionName).doc(requestId);
    }
    throw StateError('AI diet request failed: missing request ID.');
  }

  dynamic _decodeResponseBody(String body) {
    if (body.trim().isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  String? _extractRequestId(dynamic payload) {
    if (payload is Map) {
      final direct = payload['requestId'];
      if (direct is String && direct.trim().isNotEmpty) {
        return direct;
      }
      final nested = payload['data'];
      if (nested is Map) {
        final nestedId = nested['requestId'];
        if (nestedId is String && nestedId.trim().isNotEmpty) {
          return nestedId;
        }
      }
    }
    return null;
  }

  Map<String, dynamic> _responseSchema() {
    const keys = [
      'Mon_breakfast',
      'Mon_lunch',
      'Mon_dinner',
      'Tue_breakfast',
      'Tue_lunch',
      'Tue_dinner',
      'Wed_breakfast',
      'Wed_lunch',
      'Wed_dinner',
      'Thu_breakfast',
      'Thu_lunch',
      'Thu_dinner',
      'Fri_breakfast',
      'Fri_lunch',
      'Fri_dinner',
      'Sat_breakfast',
      'Sat_lunch',
      'Sat_dinner',
      'Sun_breakfast',
      'Sun_lunch',
      'Sun_dinner',
    ];
    final schema = <String, dynamic>{};
    for (final key in keys) {
      schema[key] = 'string';
    }
    return schema;
  }

  Future<String> _fetchPromptTemplate() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('prompt').doc('prompt_generate_dietplan').get();
    final data = snapshot.data();
    final prompt = data?['prompt']?.toString();
    if (prompt == null || prompt.trim().isEmpty) {
      throw StateError('Prompt template is missing.');
    }
    return prompt;
  }

  String _applyTemplate(AppData data, String template, {String? tweaks}) {
    final dietType = dietLabel(data.dietType);
    final cuisines = data.cuisines.isEmpty ? 'local' : data.cuisines.join(', ');
    final symptoms = data.healthSymptoms.isEmpty ? 'none' : data.healthSymptoms.join(', ');
    final items = _itemsText(data);
    final weight = data.weightKg.toStringAsFixed(1);
    final height = data.heightCm.toStringAsFixed(0);
    final bodyFat = data.bodyFatPct == null ? 'unknown' : data.bodyFatPct!.toStringAsFixed(1);
    final visceralFat = data.visceralFatPct == null ? 'unknown' : data.visceralFatPct!.toStringAsFixed(1);
    var prompt = template
        .replaceAll(r'$dietType', dietType)
        .replaceAll(r'$cuisines', cuisines)
        .replaceAll(r'$symptoms', symptoms)
        .replaceAll(r'$items', items)
        .replaceAll(r'$weight', weight)
        .replaceAll(r'$height', height)
        .replaceAll(r'$body_fat_pctand', '$bodyFat and')
        .replaceAll(r'$body_fat_pct', bodyFat)
        .replaceAll(r'$visceral_fat_pct', visceralFat);
    if (tweaks != null && tweaks.trim().isNotEmpty) {
      prompt = '$prompt\nTweaks: ${tweaks.trim()}';
    }
    return prompt;
  }

  String _frequencyText(Map<String, Map<String, dynamic>> frequency) {
    if (frequency.isEmpty) return '';
    final lines = <String>[];
    for (final entry in frequency.entries) {
      final item = entry.key;
      final mode = entry.value['mode']?.toString() ?? '';
      if (mode == 'everyday') {
        lines.add('the patient want $item on monday, tuesday, wednesday, thursday, friday, saturday, sunday');
      } else if (mode == 'monthly') {
        lines.add('the patient want $item monthly');
      } else if (mode == 'weekdays') {
        final weekdays = (entry.value['weekdays'] as List?)?.cast<int>() ?? [];
        if (weekdays.isNotEmpty) {
          lines.add('the patient want $item on ${_weekdayList(weekdays)}');
        }
      }
    }
    return lines.join('\n');
  }

  String _itemsText(AppData data) {
    final frequencyText = _frequencyText(data.frequency);
    if (frequencyText.isNotEmpty) {
      return frequencyText;
    }
    if (data.nonVegItems.isNotEmpty) {
      return data.nonVegItems.join(', ');
    }
    return 'none';
  }

  String _weekdayList(List<int> weekdayIndices) {
    const names = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    final sorted = [...weekdayIndices]..sort();
    return sorted.map((i) => i >= 0 && i < names.length ? names[i] : '').where((s) => s.isNotEmpty).join(', ');
  }
}
