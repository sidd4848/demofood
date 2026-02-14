import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'subscription_models.dart';

class SubscriptionService {
  const SubscriptionService();

  static const configCollection = 'subscriptionConfig';
  static const configDoc = 'default';
  static const upgradeRequestCollection = 'subscriptionUpgradeRequests';
  static const paymentFunctionUrlOverride = String.fromEnvironment(
    'PAYMENT_FUNCTION_URL',
    defaultValue: '',
  );

  static const _defaultPaymentFunctionUrl =
      'https://process-subscription-payment-b2g4omif7q-uc.a.run.app/';

  String _resolvePaymentFunctionUrl() {
    final rawUrl = paymentFunctionUrlOverride.isNotEmpty
        ? paymentFunctionUrlOverride
        : _defaultPaymentFunctionUrl;
    if (rawUrl.endsWith('/')) {
      return rawUrl;
    }
    return '$rawUrl/';
  }

  Future<SubscriptionConfig> fetchConfig() async {
    final snapshot = await FirebaseFirestore.instance.collection(configCollection).doc(configDoc).get();
    final data = snapshot.data() ?? {};
    return SubscriptionConfig.fromJson(data);
  }

  Future<void> requestSubscriptionUpgrade({
    required String planId,
    required SubscriptionDuration duration,
    required SubscriptionPrice price,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('No authenticated user.');
    }

    final token = await user.getIdToken();
    final response = await http.post(
      Uri.parse(_resolvePaymentFunctionUrl()),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(<String, dynamic>{
        'data': <String, dynamic>{
          'basePrice': price.basePrice,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
          'currency': price.currency,
          'discountPct': price.discountPct,
          'duration': duration.id,
          'durationMonths': duration.months,
          'finalPrice': price.finalPrice,
          'planId': planId,
          'region': price.region,
          'status': 'created',
          'userId': user.uid,
        },
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Payment request failed (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Payment response has an unexpected format.');
    }

    Map<String, dynamic>? payload;
    if (decoded['result'] is Map<String, dynamic>) {
      payload = decoded['result'] as Map<String, dynamic>;
    } else {
      payload = decoded;
    }

    final message = payload['message']?.toString();
    if (message == null || message.isEmpty) {
      throw const FormatException('Payment response did not include a success message.');
    }
  }

  Future<SubscriptionUpgradeRequestSummary?> fetchLatestUpgradeRequest({required String userId}) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(upgradeRequestCollection)
          .where('userId', isEqualTo: userId)
          .limit(20)
          .get();
      if (snapshot.docs.isEmpty) return null;
      final summaries = snapshot.docs
          .map((doc) => SubscriptionUpgradeRequestSummary.fromJson(doc.data()))
          .toList()
        ..sort((a, b) {
          final aCreatedAt = a.createdAt;
          final bCreatedAt = b.createdAt;
          if (aCreatedAt == null && bCreatedAt == null) return 0;
          if (aCreatedAt == null) return 1;
          if (bCreatedAt == null) return -1;
          return bCreatedAt.compareTo(aCreatedAt);
        });

      return summaries.first;
    } on FirebaseException {
      return null;
    }
  }
}
