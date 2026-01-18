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

Future<String?> fetchDietPlan() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;
  final snapshot = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
  if (!snapshot.exists) return null;
  final value = snapshot.data()?['dietPlan'];
  if (value == null) return null;
  if (value is String) return value;
  return const JsonEncoder.withIndent('  ').convert(value);
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
