import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_data.dart';

class UserProfileSummary {
  const UserProfileSummary({
    required this.name,
    required this.gender,
    required this.age,
    required this.heightCm,
    required this.weightKg,
  });

  final String name;
  final String gender;
  final int age;
  final double heightCm;
  final double weightKg;
}

class DietPlanData {
  const DietPlanData({
    required this.jobId,
    required this.calorieDeficit,
    required this.plan,
  });

  final String jobId;
  final int calorieDeficit;
  final Map<String, String> plan;
}

Future<void> saveProfileToFirebase(AppData data) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw StateError('No authenticated user.');
  }
  final payload = data.buildSubmissionPayload();
  final jobId = payload['jobId'] as String;
  final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
  await ref.set({
    'profile': payload,
    'email': user.email,
    'displayName': user.displayName,
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  final dietRef = FirebaseFirestore.instance.collection('diet').doc(jobId);
  await dietRef.set(
    buildDietDocument(jobId),
    SetOptions(merge: true),
  );
}

Map<String, dynamic> buildDietDocument(String jobId) {
  return {
    'jobId': jobId,
    'calorie deficit': 300,
    'plan': {
      'Mon_breakfast': 'Overnight oats + berries',
      'Mon_lunch': 'Grilled paneer salad',
      'Mon_dinner': 'Lentil soup + veggies',
      'Tue_breakfast': 'Avocado toast',
      'Tue_lunch': 'Quinoa bowl',
      'Tue_dinner': 'Stir-fry tofu + greens',
      'Wed_breakfast': 'Moong chilla',
      'Wed_lunch': 'Brown rice + dal',
      'Wed_dinner': 'Baked fish + salad',
      'Thu_breakfast': 'Smoothie bowl',
      'Thu_lunch': 'Chickpea wrap',
      'Thu_dinner': 'Veg curry + roti',
      'Fri_breakfast': 'Idli + sambar',
      'Fri_lunch': 'Mediterranean salad',
      'Fri_dinner': 'Grilled chicken + veggies',
      'Sat_breakfast': 'Upma + fruit',
      'Sat_lunch': 'Paneer tikka bowl',
      'Sat_dinner': 'Stuffed bell peppers',
      'Sun_breakfast': 'Veggie omelet',
      'Sun_lunch': 'Sushi bowl',
      'Sun_dinner': 'Veg soup + salad',
    },
  };
}

String dietDocumentExampleJson(String jobId) {
  return const JsonEncoder.withIndent('  ').convert(buildDietDocument(jobId));
}

Future<DietPlanData?> fetchDietPlan() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;
  final snapshot = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
  if (!snapshot.exists) return null;
  final data = snapshot.data();
  if (data == null) return null;
  String? jobId;
  final payload = data['profile'];
  if (payload is Map<String, dynamic>) {
    jobId = payload['jobId'] as String?;
  }
  if (jobId == null || jobId.isEmpty) return null;
  final dietSnapshot = await FirebaseFirestore.instance.collection('diet').doc(jobId).get();
  if (!dietSnapshot.exists) return null;
  final dietData = dietSnapshot.data();
  if (dietData == null) return null;
  final deficitRaw = dietData['calorie deficit'];
  final deficit = deficitRaw is int ? deficitRaw : (deficitRaw as num?)?.toInt() ?? 0;
  final planRaw = dietData['plan'];
  final plan = <String, String>{};
  if (planRaw is Map<String, dynamic>) {
    planRaw.forEach((key, value) {
      plan[key] = value?.toString() ?? '';
    });
  }
  return DietPlanData(jobId: jobId, calorieDeficit: deficit, plan: plan);
}

Future<bool> hasExistingProfile() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;
  final snapshot = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
  if (!snapshot.exists) return false;
  final data = snapshot.data();
  if (data == null) return false;
  return data['profile'] != null;
}

Future<UserProfileSummary?> fetchUserProfileSummary() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;
  final snapshot = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
  if (!snapshot.exists) return null;
  final data = snapshot.data();
  if (data == null) return null;

  Map<String, dynamic>? profile;
  final payload = data['profile'];
  if (payload is Map<String, dynamic>) {
    final nested = payload['profile'];
    if (nested is Map<String, dynamic>) {
      profile = nested;
    } else {
      profile = payload;
    }
  }
  if (profile == null) return null;

  return UserProfileSummary(
    name: (profile['name'] ?? '') as String,
    gender: (profile['gender'] ?? 'Male') as String,
    age: (profile['age'] ?? 25) as int,
    heightCm: (profile['heightCm'] ?? 170).toDouble(),
    weightKg: (profile['weightKg'] ?? 70).toDouble(),
  );
}
