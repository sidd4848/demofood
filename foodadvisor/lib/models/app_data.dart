import 'dart:math';

import 'package:flutter/material.dart';

class AppData extends ChangeNotifier {
  // Profile
  String name = "";
  String gender = "Male";
  int age = 25;
  double heightCm = 170;
  double weightKg = 70;
  double? bodyFatPct; // optional
  double? visceralFatPct; // optional

  // Preferences
  DietType dietType = DietType.veg;

  // Non-veg sub options
  final Set<String> nonVegItems = {};

  // Up to 5 cuisines
  final List<String> cuisines = [];

  // Allergies (modern chips)
  final Set<String> allergies = {};

  // Health symptoms
  final Set<String> healthSymptoms = {};

  // Frequency: item -> {mode: everyday|weekdays|monthly, weekdays:[0..6]}
  final Map<String, Map<String, dynamic>> frequency = {};

  // Locale preferences
  String? languageCode;
  String? regionCode;

  void reset() {
    name = "";
    gender = "Male";
    age = 25;
    heightCm = 170;
    weightKg = 70;
    bodyFatPct = null;
    visceralFatPct = null;
    dietType = DietType.veg;
    nonVegItems.clear();
    cuisines.clear();
    allergies.clear();
    healthSymptoms.clear();
    frequency.clear();
    languageCode = null;
    regionCode = null;
    notifyListeners();
  }

  void setLocale({required String language, required String region}) {
    if (languageCode == language && regionCode == region) {
      return;
    }
    languageCode = language;
    regionCode = region;
    notifyListeners();
  }

  // ---------- cuisine helpers ----------
  void addCuisine(String c) {
    if (cuisines.contains(c)) return;
    if (cuisines.length >= 5) return;
    cuisines.add(c);
    notifyListeners();
  }

  void removeCuisine(String c) {
    cuisines.remove(c);
    notifyListeners();
  }

  // ---------- allergies ----------
  void toggleAllergy(String a) {
    if (allergies.contains(a)) {
      allergies.remove(a);
    } else {
      allergies.add(a);
    }
    notifyListeners();
  }

  // ---------- nonveg ----------
  void toggleNonVeg(String item) {
    if (nonVegItems.contains(item)) {
      nonVegItems.remove(item);
    } else {
      nonVegItems.add(item);
    }
    notifyListeners();
  }

  // ---------- frequency ----------
  void setFrequencyMode(String item, String mode) {
    frequency[item] ??= {};
    frequency[item]!["mode"] = mode;
    if (mode != "weekdays") frequency[item]!.remove("weekdays");
    notifyListeners();
  }

  void toggleFrequencyWeekday(String item, int dayIdx) {
    frequency[item] ??= {};
    frequency[item]!["mode"] = "weekdays";
    final list = (frequency[item]!["weekdays"] as List?)?.cast<int>() ?? <int>[];
    if (list.contains(dayIdx)) {
      list.remove(dayIdx);
    } else {
      list.add(dayIdx);
      list.sort();
    }
    frequency[item]!["weekdays"] = list;
    notifyListeners();
  }

  // ---------- health symptoms ----------
  void toggleHealthSymptom(String value) {
    if (healthSymptoms.contains(value)) {
      healthSymptoms.remove(value);
    } else {
      healthSymptoms.add(value);
    }
    notifyListeners();
  }

  // ---------- JSON ----------
  Map<String, dynamic> toJson() => {
        "profile": {
          "name": name,
          "gender": gender,
          "age": age,
          "heightCm": heightCm,
          "weightKg": weightKg,
          "bodyFatPct": bodyFatPct,
          "visceralFatPct": visceralFatPct,
        },
        "preferences": {
          "dietType": dietType.name,
          "nonVegItems": nonVegItems.toList(),
          "cuisines": cuisines,
          "allergies": allergies.toList(),
          "healthSymptoms": healthSymptoms.toList(),
        },
        "locale": {
          "language": languageCode,
          "region": regionCode,
        },
        "frequency": frequency,
      };

  Map<String, dynamic> buildSubmissionPayload() {
    final now = DateTime.now().toUtc();
    final randomHex = Random.secure().nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
    final jobId = 'job_${now.millisecondsSinceEpoch}_$randomHex';

    return {
      ...toJson(),
      'jobId': jobId,
      'submittedAt': now.toIso8601String(),
    };
  }

  void fromJson(Map<String, dynamic> j) {
    final p = (j["profile"] ?? {}) as Map<String, dynamic>;
    name = (p["name"] ?? "") as String;
    gender = (p["gender"] ?? "Male") as String;
    age = (p["age"] ?? 25) as int;
    heightCm = (p["heightCm"] ?? 170).toDouble();
    weightKg = (p["weightKg"] ?? 70).toDouble();
    bodyFatPct = (p["bodyFatPct"] == null) ? null : (p["bodyFatPct"] as num).toDouble();
    visceralFatPct = (p["visceralFatPct"] == null) ? null : (p["visceralFatPct"] as num).toDouble();

    final pref = (j["preferences"] ?? {}) as Map<String, dynamic>;
    final dt = (pref["dietType"] ?? "veg") as String;
    dietType = DietType.values.firstWhere((e) => e.name == dt, orElse: () => DietType.veg);

    nonVegItems
      ..clear()
      ..addAll(((pref["nonVegItems"] ?? []) as List).cast<String>());

    cuisines
      ..clear()
      ..addAll(((pref["cuisines"] ?? []) as List).cast<String>());

    allergies
      ..clear()
      ..addAll(((pref["allergies"] ?? []) as List).cast<String>());

    healthSymptoms
      ..clear()
      ..addAll(((pref["healthSymptoms"] ?? []) as List).cast<String>());

    frequency
      ..clear()
      ..addAll(((j["frequency"] ?? {}) as Map).cast<String, Map<String, dynamic>>());

    final locale = (j["locale"] ?? {}) as Map<String, dynamic>;
    languageCode = locale["language"]?.toString();
    regionCode = locale["region"]?.toString();

    notifyListeners();
  }
}

enum DietType { veg, nonveg, eggetarian, pescatarian, vegan }

String dietLabel(DietType d) {
  switch (d) {
    case DietType.veg:
      return "Veg";
    case DietType.nonveg:
      return "Non-veg";
    case DietType.eggetarian:
      return "Eggetarian";
    case DietType.pescatarian:
      return "Pescatarian";
    case DietType.vegan:
      return "Vegan";
  }
}
