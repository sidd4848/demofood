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
    required this.userId,
    required this.calorieDeficit,
    required this.plan,
  });

  final String jobId;
  final String? userId;
  final int calorieDeficit;
  final Map<String, String> plan;
}

class DietGenerationChoice {
  const DietGenerationChoice({
    required this.userId,
    required this.generatedBy,
  });

  final String userId;
  final String generatedBy;
}

Future<void> saveProfileToFirebase(AppData data) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw StateError('No authenticated user.');
  }
  final payload = data.buildSubmissionPayload();
  final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
  await ref.set({
    'profile': payload,
    'email': user.email,
    'displayName': user.displayName,
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}

Future<void> saveDietGenerationChoice(String generatedBy) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw StateError('No authenticated user.');
  }
  final ref = FirebaseFirestore.instance.collection('dietGeneration').doc(user.uid);
  await ref.set({
    'userId': user.uid,
    'generatedBy': generatedBy,
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}

Future<DietGenerationChoice?> fetchDietGenerationChoice() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;
  final snapshot = await FirebaseFirestore.instance.collection('dietGeneration').doc(user.uid).get();
  if (!snapshot.exists) return null;
  final data = snapshot.data();
  if (data == null) return null;
  final generatedBy = data['generatedBy'] as String?;
  if (generatedBy == null || generatedBy.isEmpty) return null;
  return DietGenerationChoice(userId: user.uid, generatedBy: generatedBy);
}

Future<DietPlanData?> fetchDietPlan() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;
  String? jobId;
  Map<String, dynamic>? dietData;
  try {
    final snapshot = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (snapshot.exists) {
      final data = snapshot.data();
      if (data != null) {
        final payload = data['profile'];
        if (payload is Map<String, dynamic>) {
          jobId = payload['jobId'] as String?;
        }
      }
    }
    if (jobId != null && jobId.isNotEmpty) {
      final dietSnapshot = await FirebaseFirestore.instance.collection('diet').doc(jobId).get();
      if (dietSnapshot.exists) {
        dietData = dietSnapshot.data();
        jobId = dietData?['jobId'] as String? ?? jobId;
      }
    } else {
      final dietSnapshot = await FirebaseFirestore.instance
          .collection('diet')
          .where('userId', isEqualTo: user.uid)
          .orderBy('updatedAt', descending: true)
          .limit(1)
          .get();
      if (dietSnapshot.docs.isEmpty) return null;
      final doc = dietSnapshot.docs.first;
      dietData = doc.data();
      jobId = dietData['jobId'] as String? ?? doc.id;
    }
    if (dietData == null || jobId == null || jobId.isEmpty) return null;
    final userId = dietData['userId'] as String?;
    final deficitRaw = dietData['calorie deficit'];
    final deficit = deficitRaw is int ? deficitRaw : (deficitRaw as num?)?.toInt() ?? 0;
    final planRaw = dietData['plan'];
    final plan = <String, String>{};
    if (planRaw is Map<String, dynamic>) {
      planRaw.forEach((key, value) {
        plan[key] = value?.toString() ?? '';
      });
    }
    return DietPlanData(jobId: jobId, userId: userId, calorieDeficit: deficit, plan: plan);
  } on FirebaseException {
    return null;
  }
}

Future<void> saveSelfDietPlan({
  required String jobId,
  required int calorieDeficit,
  required Map<String, String> plan,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw StateError('No authenticated user.');
  }
  final dietRef = FirebaseFirestore.instance.collection('diet').doc(jobId);
  await dietRef.set({
    'jobId': jobId,
    'userId': user.uid,
    'calorie deficit': calorieDeficit,
    'plan': plan,
    'updatedBy': user.uid,
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
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

Future<String?> fetchProfileJobId() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;
  final snapshot = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
  if (!snapshot.exists) return null;
  final data = snapshot.data();
  if (data == null) return null;
  final payload = data['profile'];
  if (payload is Map<String, dynamic>) {
    return payload['jobId'] as String?;
  }
  return null;
}
