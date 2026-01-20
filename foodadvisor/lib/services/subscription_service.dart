import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

class SubscriptionConfig {
  final Map<String, RegionPricing> regions;
  final Map<String, SubscriptionDuration> durations;

  const SubscriptionConfig({required this.regions, required this.durations});

  factory SubscriptionConfig.fromJson(Map<String, dynamic> json) {
    final regionData = (json['regions'] as Map<String, dynamic>? ?? {});
    final durationData = (json['durations'] as Map<String, dynamic>? ?? {});
    final regions = <String, RegionPricing>{};
    final durations = <String, SubscriptionDuration>{};
    for (final entry in regionData.entries) {
      final payload = entry.value;
      if (payload is Map<String, dynamic>) {
        regions[entry.key] = RegionPricing.fromJson(entry.key, payload);
      }
    }
    for (final entry in durationData.entries) {
      final payload = entry.value;
      if (payload is Map<String, dynamic>) {
        durations[entry.key] = SubscriptionDuration.fromJson(entry.key, payload);
      }
    }
    return SubscriptionConfig(regions: regions, durations: durations);
  }

  RegionPricing resolveRegion(String? regionCode) {
    if (regions.isEmpty) {
      return const RegionPricing(
        region: 'default',
        currency: 'INR',
        symbol: '₹',
        planPrices: {'free': 0, 'pro': 499, 'elite': 799},
      );
    }
    if (regionCode != null && regions.containsKey(regionCode)) {
      return regions[regionCode]!;
    }
    return regions['default'] ?? regions.values.first;
  }

  List<SubscriptionDuration> sortedDurations() {
    final list = durations.values.toList();
    list.sort((a, b) => a.months.compareTo(b.months));
    return list;
  }
}

class RegionPricing {
  final String region;
  final String currency;
  final String symbol;
  final Map<String, int> planPrices;

  const RegionPricing({
    required this.region,
    required this.currency,
    required this.symbol,
    required this.planPrices,
  });

  factory RegionPricing.fromJson(String region, Map<String, dynamic> json) {
    final planPrices = <String, int>{};
    final prices = json['planPrices'];
    if (prices is Map<String, dynamic>) {
      for (final entry in prices.entries) {
        final value = entry.value;
        if (value is num) {
          planPrices[entry.key] = value.toInt();
        }
      }
    }
    return RegionPricing(
      region: region,
      currency: json['currency']?.toString() ?? 'INR',
      symbol: json['symbol']?.toString() ?? '₹',
      planPrices: planPrices,
    );
  }

  int priceForPlan(String planId) => planPrices[planId] ?? 0;
}

class SubscriptionDuration {
  final String id;
  final String label;
  final int months;
  final int discountPct;

  const SubscriptionDuration({
    required this.id,
    required this.label,
    required this.months,
    required this.discountPct,
  });

  factory SubscriptionDuration.fromJson(String id, Map<String, dynamic> json) {
    return SubscriptionDuration(
      id: id,
      label: json['label']?.toString() ?? id,
      months: (json['months'] as num?)?.toInt() ?? 1,
      discountPct: (json['discountPct'] as num?)?.toInt() ?? 0,
    );
  }
}

class SubscriptionPrice {
  final String region;
  final String currency;
  final String symbol;
  final int basePrice;
  final int discountPct;
  final int finalPrice;

  const SubscriptionPrice({
    required this.region,
    required this.currency,
    required this.symbol,
    required this.basePrice,
    required this.discountPct,
    required this.finalPrice,
  });
}
