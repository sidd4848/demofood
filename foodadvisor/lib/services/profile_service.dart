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
    required this.startDate,
    required this.generatedAt,
    required this.calorieDeficit,
    required this.plan,
  });

  final String jobId;
  final String? userId;
  final DateTime? startDate;
  final DateTime? generatedAt;
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

class SubscriptionSummary {
  const SubscriptionSummary({
    required this.plan,
    required this.status,
    required this.subscriptionId,
    required this.currentPeriodEnd,
  });

  final String plan;
  final String status;
  final String? subscriptionId;
  final DateTime? currentPeriodEnd;
}

class PlanQuota {
  const PlanQuota({
    required this.recipe,
    required this.dietRegeneration,
  });

  final int recipe;
  final int dietRegeneration;

  factory PlanQuota.fromJson(Map<String, dynamic>? data) {
    return PlanQuota(
      recipe: (data?['recipe'] as num?)?.toInt() ?? 0,
      dietRegeneration: (data?['diet_regeneration'] as num?)?.toInt() ?? 0,
    );
  }
}

class UserQuotaSummary {
  const UserQuotaSummary({
    this.proQuota,
    this.trialQuota,
  });

  final PlanQuota? proQuota;
  final PlanQuota? trialQuota;
}

Future<void> saveProfileToFirebase(AppData data) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw StateError('No authenticated user.');
  }
  final payload = data.buildSubmissionPayload();
  final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
  final snapshot = await ref.get();
  final isNewUser = !snapshot.exists;
  final profileData = <String, dynamic>{
    'profile': payload,
    'email': user.email,
    'displayName': user.displayName,
    'updatedAt': FieldValue.serverTimestamp(),
  };
  if (isNewUser) {
    profileData.addAll({
      'plan': 'free',
      'subscriptionStatus': 'trial',
      'subscriptionId': null,
      'currentPeriodEnd': null,
      'quota': {
        'pro_quota': {
          'recipe': 0,
          'diet_regeneration': 0,
        },
        'trial_quota': {
          'recipe': 3,
          'diet_regeneration': 3,
        },
      },
    });
  }
  await ref.set(profileData, SetOptions(merge: true));
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

Future<SubscriptionSummary?> fetchUserSubscription() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;
  final snapshot = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
  if (!snapshot.exists) return null;
  final data = snapshot.data();
  if (data == null) return null;
  final plan =
      data['plan']?.toString() ?? data['planId']?.toString() ?? 'free';
  final rawStatus =
      data['subscriptionStatus']?.toString() ?? data['status']?.toString() ?? 'trial';
  final status = switch (rawStatus.toLowerCase()) {
    'payment_done' || 'paid' => 'active',
    _ => rawStatus,
  };
  final subscriptionId =
      data['subscriptionId']?.toString() ?? data['reqId']?.toString();
  final currentPeriodEnd = _parseFirestoreTimestamp(data['currentPeriodEnd']);
  return SubscriptionSummary(
    plan: plan,
    status: status,
    subscriptionId: subscriptionId,
    currentPeriodEnd: currentPeriodEnd,
  );
}

Future<UserQuotaSummary?> fetchUserQuotaSummary() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;
  final snapshot = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
  if (!snapshot.exists) return null;
  final data = snapshot.data();
  if (data == null) return null;
  final quota = data['quota'];
  if (quota is! Map<String, dynamic>) return null;
  final proQuota = quota['pro_quota'];
  final trialQuota = quota['trial_quota'];
  return UserQuotaSummary(
    proQuota: PlanQuota.fromJson(proQuota is Map<String, dynamic> ? proQuota : null),
    trialQuota: PlanQuota.fromJson(trialQuota is Map<String, dynamic> ? trialQuota : null),
  );
}

Future<DietPlanData?> fetchDietPlan() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;
  Map<String, dynamic>? dietData;
  try {
    final historySnapshot = await FirebaseFirestore.instance
        .collection('userdiethistory')
        .doc(user.uid)
        .get();
    if (!historySnapshot.exists) return null;
    final historyData = historySnapshot.data();
    if (historyData == null) return null;
    final jobIdsRaw = historyData['job_id'];
    if (jobIdsRaw is! List || jobIdsRaw.isEmpty) return null;

    String? jobId;
    for (var i = jobIdsRaw.length - 1; i >= 0; i--) {
      final candidate = jobIdsRaw[i]?.toString();
      if (candidate != null && candidate.isNotEmpty) {
        jobId = candidate;
        break;
      }
    }
    if (jobId == null || jobId.isEmpty) return null;

    final dietSnapshot = await FirebaseFirestore.instance.collection('diet').doc(jobId).get();
    if (!dietSnapshot.exists) return null;
    dietData = dietSnapshot.data();
    if (dietData == null) return null;
    final resolvedJobId = dietData['jobId'] as String? ?? jobId;
    final userId = dietData['userId'] as String?;
    final startDateRaw = dietData['startDate'];
    final startDate = _parseFirestoreTimestamp(startDateRaw);
    final updatedAtRaw = dietData['updatedAt'];
    final createdAtRaw = dietData['createdAt'];
    final generatedAt = _parseFirestoreTimestamp(updatedAtRaw) ?? _parseFirestoreTimestamp(createdAtRaw);
    final deficitRaw = dietData['calorie deficit'];
    final deficit = deficitRaw is int ? deficitRaw : (deficitRaw as num?)?.toInt() ?? 0;
    final planRaw = dietData['plan'];
    final plan = <String, String>{};
    if (planRaw is Map<String, dynamic>) {
      planRaw.forEach((key, value) {
        plan[key] = value?.toString() ?? '';
      });
    }
    return DietPlanData(
      jobId: resolvedJobId,
      userId: userId,
      startDate: startDate,
      generatedAt: generatedAt,
      calorieDeficit: deficit,
      plan: plan,
    );
  } on FirebaseException {
    return null;
  }
}

DateTime? _parseFirestoreTimestamp(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value)?.toLocal();
  }
  return null;
}

Future<void> saveSelfDietPlan({
  required String jobId,
  required int calorieDeficit,
  required Map<String, String> plan,
  DateTime? startDate,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw StateError('No authenticated user.');
  }
  final dietRef = FirebaseFirestore.instance.collection('diet').doc(jobId);
  final payload = <String, dynamic>{
    'jobId': jobId,
    'userId': user.uid,
    'generatedBy': 'self',
    'createdBy': 'self',
    'calorie deficit': calorieDeficit,
    'plan': plan,
    'updatedBy': user.uid,
    'updatedAt': FieldValue.serverTimestamp(),
  };
  if (startDate != null) {
    payload['startDate'] = Timestamp.fromDate(startDate);
  }
  await dietRef.set(payload, SetOptions(merge: true));

  final historyRef = FirebaseFirestore.instance.collection('userdiethistory').doc(user.uid);
  await historyRef.set({
    'job_id': FieldValue.arrayUnion([jobId]),
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
  final snapshot = await FirebaseFirestore.instance.collection('userdiethistory').doc(user.uid).get();
  if (!snapshot.exists) return null;
  final data = snapshot.data();
  if (data == null) return null;
  final jobIds = data['job_id'];
  if (jobIds is! List || jobIds.isEmpty) return null;
  for (var i = jobIds.length - 1; i >= 0; i--) {
    final jobId = jobIds[i]?.toString();
    if (jobId != null && jobId.isNotEmpty) {
      return jobId;
    }
  }
  return null;
}
