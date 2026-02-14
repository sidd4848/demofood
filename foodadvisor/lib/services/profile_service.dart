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
    final historyData = await _fetchDietHistoryData(user.uid);
    if (historyData == null) return null;
    final jobIdRaw = historyData['job_id'];
    String? jobId;

    if (jobIdRaw is String && jobIdRaw.isNotEmpty) {
      jobId = jobIdRaw;
    } else if (jobIdRaw is List && jobIdRaw.isNotEmpty) {
      for (var i = jobIdRaw.length - 1; i >= 0; i--) {
        final candidate = jobIdRaw[i]?.toString();
        if (candidate != null && candidate.isNotEmpty) {
          jobId = candidate;
          break;
        }
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
    final plan = _normalizeDietPlan(planRaw);
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

Map<String, String> _normalizeDietPlan(dynamic rawPlan) {
  final normalized = <String, String>{};
  if (rawPlan is! Map) return normalized;

  rawPlan.forEach((key, value) {
    final keyText = key?.toString() ?? '';
    if (_looksLikeLegacyMealKey(keyText)) {
      normalized[keyText] = value?.toString() ?? '';
      return;
    }

    final day = _normalizeWeekdayKey(keyText);
    if (day == null || value is! Map) return;

    final normalizedMeals = <String, String>{};
    value.forEach((mealKey, mealValue) {
      final normalizedMealKey = mealKey?.toString().trim().toLowerCase();
      if (normalizedMealKey == null || normalizedMealKey.isEmpty) return;
      normalizedMeals[normalizedMealKey] = mealValue?.toString() ?? '';
    });
    final breakfast = normalizedMeals['breakfast'];
    final lunch = normalizedMeals['lunch'];
    final dinner = normalizedMeals['dinner'];
    if (breakfast != null) normalized['${day}_breakfast'] = breakfast;
    if (lunch != null) normalized['${day}_lunch'] = lunch;
    if (dinner != null) normalized['${day}_dinner'] = dinner;
  });

  return normalized;
}

Map<String, Map<String, String>> _toNestedDietPlan(Map<String, String> plan) {
  final nested = <String, Map<String, String>>{};
  plan.forEach((key, value) {
    final parts = key.split('_');
    if (parts.length != 2) return;
    final day = _normalizeWeekdayKey(parts.first);
    final meal = parts.last.trim().toLowerCase();
    if (day == null) return;
    if (meal != 'breakfast' && meal != 'lunch' && meal != 'dinner') return;
    nested.putIfAbsent(day, () => <String, String>{})[meal] = value;
  });
  return nested;
}


String? _normalizeWeekdayKey(String? value) {
  if (value == null || value.isEmpty) return null;
  final compact = value.trim();
  switch (compact.toLowerCase()) {
    case 'mon':
    case 'monday':
      return 'Mon';
    case 'tue':
    case 'tues':
    case 'tuesday':
      return 'Tue';
    case 'wed':
    case 'weds':
    case 'wednesday':
      return 'Wed';
    case 'thu':
    case 'thur':
    case 'thurs':
    case 'thursday':
      return 'Thu';
    case 'fri':
    case 'friday':
      return 'Fri';
    case 'sat':
    case 'saturday':
      return 'Sat';
    case 'sun':
    case 'sunday':
      return 'Sun';
  }
  return null;
}

bool _looksLikeLegacyMealKey(String value) {
  final parts = value.split('_');
  if (parts.length != 2) return false;
  final day = _normalizeWeekdayKey(parts.first);
  if (day == null) return false;
  return parts.last == 'breakfast' || parts.last == 'lunch' || parts.last == 'dinner';
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
  String? jobId,
  required int calorieDeficit,
  required Map<String, String> plan,
  DateTime? startDate,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw StateError('No authenticated user.');
  }
  final resolvedJobId = (jobId != null && jobId.trim().isNotEmpty)
      ? jobId.trim()
      : FirebaseFirestore.instance.collection('diet').doc().id;
  final dietRef = FirebaseFirestore.instance.collection('diet').doc(resolvedJobId);
  final payload = <String, dynamic>{
    'jobId': resolvedJobId,
    'userId': user.uid,
    'createdby': 'self',
    'createdBy': 'self',
    'generatedBy': 'self',
    'calorie deficit': calorieDeficit,
    'plan': _toNestedDietPlan(plan),
    'updatedBy': user.uid,
    'updatedAt': FieldValue.serverTimestamp(),
    'createdAt': FieldValue.serverTimestamp(),
  };
  if (startDate != null) {
    payload['startDate'] = Timestamp.fromDate(startDate);
  }
  await dietRef.set(payload, SetOptions(merge: true));

  final historyPayload = {
    'user_id': user.uid,
    'job_id': FieldValue.arrayUnion([resolvedJobId]),
    'updatedAt': FieldValue.serverTimestamp(),
  };
  await FirebaseFirestore.instance
      .collection('userdiethistory')
      .doc(user.uid)
      .set(historyPayload, SetOptions(merge: true));
  await FirebaseFirestore.instance
      .collection('userDietHistory')
      .doc(user.uid)
      .set(historyPayload, SetOptions(merge: true));
}


Future<Map<String, dynamic>?> _fetchDietHistoryData(String userId) async {
  final camelCase = await FirebaseFirestore.instance.collection('userDietHistory').doc(userId).get();
  if (camelCase.exists) {
    final data = camelCase.data();
    if (data != null) return data;
  }

  final legacy = await FirebaseFirestore.instance.collection('userdiethistory').doc(userId).get();
  if (!legacy.exists) return null;
  return legacy.data();
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
  final data = await _fetchDietHistoryData(user.uid);
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
