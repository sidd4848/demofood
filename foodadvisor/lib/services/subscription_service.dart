import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'subscription_models.dart';

class SubscriptionService {
  const SubscriptionService();

  static const configCollection = 'subscriptionConfig';
  static const configDoc = 'default';
  static const upgradeRequestCollection = 'subscriptionUpgradeRequests';

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
    await FirebaseFirestore.instance.collection(upgradeRequestCollection).add({
      'userId': user.uid,
      'planId': planId,
      'duration': duration.id,
      'currency': price.currency,
      'region': price.region,
      'basePrice': price.basePrice,
      'discountPct': price.discountPct,
      'finalPrice': price.finalPrice,
      'status': 'created',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<SubscriptionUpgradeRequestSummary?> fetchLatestUpgradeRequest({required String userId}) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(upgradeRequestCollection)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      return SubscriptionUpgradeRequestSummary.fromJson(snapshot.docs.first.data());
    } on FirebaseException {
      final snapshot = await FirebaseFirestore.instance
          .collection(upgradeRequestCollection)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      return SubscriptionUpgradeRequestSummary.fromJson(snapshot.docs.first.data());
    }
  }
}
