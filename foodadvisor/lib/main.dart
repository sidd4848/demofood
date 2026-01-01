import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

void main() => runApp(const FoodAdvisorApp());

/// -------------------------------
/// App State (simple + no packages)
/// -------------------------------
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

  // Cheat day
  bool cheatDayEnabled = false;
  String cheatDayPreference = "Moderate"; // Light/Moderate/Heavy

  // Frequency: item -> {mode: everyday|weekdays|monthly, weekdays:[0..6]}
  final Map<String, Map<String, dynamic>> frequency = {};

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
          "cheatDayEnabled": cheatDayEnabled,
          "cheatDayPreference": cheatDayPreference,
        },
        "frequency": frequency,
      };

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

    cheatDayEnabled = (pref["cheatDayEnabled"] ?? false) as bool;
    cheatDayPreference = (pref["cheatDayPreference"] ?? "Moderate") as String;

    frequency
      ..clear()
      ..addAll(((j["frequency"] ?? {}) as Map).cast<String, Map<String, dynamic>>());

    notifyListeners();
  }

  static Future<File> _profileFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File("${dir.path}/foodadvisor_profile.json");
  }

  Future<void> save() async {
    final f = await _profileFile();
    await f.writeAsString(jsonEncode(toJson()));
  }

  Future<bool> loadIfExists() async {
    final f = await _profileFile();
    if (!await f.exists()) return false;
    final txt = await f.readAsString();
    fromJson(jsonDecode(txt) as Map<String, dynamic>);
    return true;
  }
}

/// -------------------------------
/// Theme (2 colors: warm + healing)
/// -------------------------------
const Color kPrimary = Color(0xFFE76F51); // warm coral
const Color kSecondary = Color(0xFF2A9D8F); // healing teal
const Color kBg = Color(0xFFFFFBF7); // warm off-white
const Color kCard = Color(0xFFFFFFFF);

ThemeData buildTheme() {
  final base = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: kPrimary,
      primary: kPrimary,
      secondary: kSecondary,
      surface: kCard,
      background: kBg,
    ),
    useMaterial3: true,
  );

  // IMPORTANT: CardThemeData for older Flutter versions.
  return base.copyWith(
    scaffoldBackgroundColor: kBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: kBg,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: const CardThemeData(
      color: kCard,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: kPrimary, width: 1.2),
      ),
    ),
  );
}

class FoodAdvisorApp extends StatefulWidget {
  const FoodAdvisorApp({super.key});
  @override
  State<FoodAdvisorApp> createState() => _FoodAdvisorAppState();
}

class _FoodAdvisorAppState extends State<FoodAdvisorApp> {
  final AppData data = AppData();

  @override
  void initState() {
    super.initState();
    // Load locally saved profile if exists (for future "Existing User")
    data.loadIfExists();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: data,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: LandingPage(data: data),
      ),
    );
  }
}

/// -------------------------------
/// Landing
/// -------------------------------
class LandingPage extends StatelessWidget {
  final AppData data;
  const LandingPage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PremiumHeader(),
              const SizedBox(height: 18),
              _PremiumHeroCard(),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: kPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserDetailsPage(data: data),
                          ),
                        );
                      },
                      child: const Text("New User"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: null, // disabled for now
                      child: const Text("Existing User"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                "Existing user login will be enabled soon.",
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: [kPrimary, kSecondary],
            ),
          ),
          child: const Icon(Icons.restaurant_rounded, color: Colors.white),
        ),
        const SizedBox(width: 12),
        const Text(
          "FoodAdvisor",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _PremiumHeroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Warm, healing food guidance.",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Personalised choices based on your diet, cuisines, allergies, and frequency.",
                    style: TextStyle(color: Colors.grey.shade700, height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              height: 72,
              width: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: kPrimary.withOpacity(0.12),
              ),
              child: const Icon(Icons.favorite_rounded, color: kPrimary, size: 32),
            )
          ],
        ),
      ),
    );
  }
}

/// -------------------------------
/// Step 1: User details
/// -------------------------------
class UserDetailsPage extends StatefulWidget {
  final AppData data;
  const UserDetailsPage({super.key, required this.data});

  @override
  State<UserDetailsPage> createState() => _UserDetailsPageState();
}

class _UserDetailsPageState extends State<UserDetailsPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController nameC;
  late final TextEditingController ageC;
  late final TextEditingController heightC;
  late final TextEditingController weightC;
  late final TextEditingController bodyFatC;
  late final TextEditingController visceralFatC;

  @override
  void initState() {
    super.initState();
    final d = widget.data;
    nameC = TextEditingController(text: d.name);
    ageC = TextEditingController(text: d.age.toString());
    heightC = TextEditingController(text: d.heightCm.toString());
    weightC = TextEditingController(text: d.weightKg.toString());
    bodyFatC = TextEditingController(text: d.bodyFatPct?.toString() ?? "");
    visceralFatC = TextEditingController(text: d.visceralFatPct?.toString() ?? "");
  }

  @override
  void dispose() {
    nameC.dispose();
    ageC.dispose();
    heightC.dispose();
    weightC.dispose();
    bodyFatC.dispose();
    visceralFatC.dispose();
    super.dispose();
  }

  double? _tryParseDouble(String s) => s.trim().isEmpty ? null : double.tryParse(s.trim());
  int? _tryParseInt(String s) => int.tryParse(s.trim());

  @override
  Widget build(BuildContext context) {
    final d = widget.data;

    return Scaffold(
      appBar: AppBar(
        title: const Text("New user details"),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                _SectionTitle(
                  title: "Profile",
                  subtitle: "This helps personalize food guidance.",
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nameC,
                  decoration: const InputDecoration(labelText: "Name"),
                  validator: (v) => (v == null || v.trim().isEmpty) ? "Please enter your name" : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: d.gender,
                  decoration: const InputDecoration(labelText: "Gender"),
                  items: const [
                    DropdownMenuItem(value: "Male", child: Text("Male")),
                    DropdownMenuItem(value: "Female", child: Text("Female")),
                    DropdownMenuItem(value: "Other", child: Text("Other")),
                    DropdownMenuItem(value: "Prefer not to say", child: Text("Prefer not to say")),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    d.gender = v;
                    d.notifyListeners();
                  },
                ),
                const SizedBox(height: 12),
                _TwoCols(
                  left: TextFormField(
                    controller: ageC,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Age"),
                    validator: (v) {
                      final n = _tryParseInt(v ?? "");
                      if (n == null || n < 5 || n > 120) return "Enter valid age";
                      return null;
                    },
                  ),
                  right: TextFormField(
                    controller: heightC,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Height (cm)"),
                    validator: (v) {
                      final n = double.tryParse((v ?? "").trim());
                      if (n == null || n < 80 || n > 250) return "Enter valid height";
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 12),
                _TwoCols(
                  left: TextFormField(
                    controller: weightC,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Weight (kg)"),
                    validator: (v) {
                      final n = double.tryParse((v ?? "").trim());
                      if (n == null || n < 20 || n > 300) return "Enter valid weight";
                      return null;
                    },
                  ),
                  right: TextFormField(
                    controller: bodyFatC,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Body fat % (optional)"),
                    validator: (v) {
                      final s = (v ?? "").trim();
                      if (s.isEmpty) return null;
                      final n = double.tryParse(s);
                      if (n == null || n < 2 || n > 70) return "Invalid %";
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: visceralFatC,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Visceral fat % (optional)"),
                  validator: (v) {
                    final s = (v ?? "").trim();
                    if (s.isEmpty) return null;
                    final n = double.tryParse(s);
                    if (n == null || n < 1 || n > 60) return "Invalid %";
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: kPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  onPressed: () {
                    if (!_formKey.currentState!.validate()) return;

                    d.name = nameC.text.trim();
                    d.age = int.parse(ageC.text.trim());
                    d.heightCm = double.parse(heightC.text.trim());
                    d.weightKg = double.parse(weightC.text.trim());
                    d.bodyFatPct = _tryParseDouble(bodyFatC.text);
                    d.visceralFatPct = _tryParseDouble(visceralFatC.text);
                    d.notifyListeners();

                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => PreferencesPage(data: d)),
                    );
                  },
                  child: const Text("Continue"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// -------------------------------
/// Step 2: Preferences
/// Diet + NonVeg items + Cuisines + Allergies + Cheat Day
/// -------------------------------
class PreferencesPage extends StatelessWidget {
  final AppData data;
  const PreferencesPage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Preferences")),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            children: [
              _SectionTitle(
                title: "Diet type",
                subtitle: "Choose what best fits you.",
              ),
              const SizedBox(height: 10),
              _DietSelector(data: data),

              if (data.dietType == DietType.nonveg ||
                  data.dietType == DietType.eggetarian ||
                  data.dietType == DietType.pescatarian) ...[
                const SizedBox(height: 12),
                _NonVegSelector(data: data),
              ],

              const SizedBox(height: 18),
              _SectionTitle(
                title: "Cuisines (up to 5)",
                subtitle: "Pick favourite cuisines for better suggestions.",
              ),
              const SizedBox(height: 10),
              _CuisineSelector(data: data),

              const SizedBox(height: 18),
              _SectionTitle(
                title: "Allergies",
                subtitle: "Tap to select. Compact + modern.",
              ),
              const SizedBox(height: 10),
              _AllergySelector(data: data),

              const SizedBox(height: 18),
              _SectionTitle(
                title: "Cheat day preference",
                subtitle: "Optional. Helps plan flexibility without guilt.",
              ),
              const SizedBox(height: 10),
              _CheatDaySelector(data: data),

              const SizedBox(height: 22),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: kSecondary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => FrequencyPage(data: data)),
                  );
                },
                child: const Text("Next: Frequency"),
              ),
            ],
          ),
        ),
      ),
    );
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

class _DietSelector extends StatelessWidget {
  final AppData data;
  const _DietSelector({required this.data});

  @override
  Widget build(BuildContext context) {
    final types = DietType.values;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: types.map((t) {
        final selected = data.dietType == t;
        return ChoiceChip(
          selected: selected,
          label: Text(dietLabel(t)),
          selectedColor: kPrimary.withOpacity(0.18),
          onSelected: (_) {
            data.dietType = t;

            // Reset nonveg choices when switching
            if (t == DietType.veg || t == DietType.vegan) {
              data.nonVegItems.clear();
            }
            if (t == DietType.eggetarian) {
              data.nonVegItems
                ..clear()
                ..add("Eggs");
            }
            if (t == DietType.pescatarian) {
              data.nonVegItems
                ..clear()
                ..add("Seafood");
            }

            data.notifyListeners();
          },
        );
      }).toList(),
    );
  }
}

class _NonVegSelector extends StatelessWidget {
  final AppData data;
  const _NonVegSelector({required this.data});

  static const items = ["Eggs", "Chicken", "Beef", "Pork", "Duck", "Lamb", "Goat", "Seafood"];

  @override
  Widget build(BuildContext context) {
    // Auto enforce for Eggetarian / Pescatarian
    if (data.dietType == DietType.eggetarian) {
      data.nonVegItems
        ..clear()
        ..add("Eggs");
    }
    if (data.dietType == DietType.pescatarian) {
      data.nonVegItems
        ..clear()
        ..add("Seafood");
    }

    final locked = (data.dietType == DietType.eggetarian || data.dietType == DietType.pescatarian);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Non-veg options", style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: items.map((it) {
                final selected = data.nonVegItems.contains(it);
                return FilterChip(
                  label: Text(it),
                  selected: selected,
                  onSelected: locked ? null : (_) => data.toggleNonVeg(it),
                  selectedColor: kSecondary.withOpacity(0.18),
                );
              }).toList(),
            ),
            if (locked)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  "Locked based on diet type.",
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              )
          ],
        ),
      ),
    );
  }
}

/// -------------------------------
/// Cuisine selection
/// -------------------------------
class _CuisineSelector extends StatelessWidget {
  final AppData data;
  const _CuisineSelector({required this.data});

  static const popular = [
    "Indian",
    "Italian",
    "Mexican",
    "Thai",
    "Japanese",
    "Mediterranean",
    "Chinese",
    "Korean",
  ];

  static const Map<String, List<String>> byCountry = {
    "India": ["North Indian", "South Indian", "Punjabi", "Bengali", "Hyderabadi", "Street Food"],
    "Italy": ["Italian", "Sicilian", "Tuscan"],
    "Mexico": ["Mexican", "Tex-Mex"],
    "Japan": ["Japanese", "Sushi", "Ramen"],
    "Thailand": ["Thai"],
    "China": ["Chinese", "Sichuan", "Cantonese"],
    "Korea": ["Korean"],
    "Middle East": ["Lebanese", "Turkish", "Persian"],
    "USA": ["American", "BBQ", "Cajun"],
  };

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: data.cuisines
                  .map((c) => Chip(
                        label: Text(c),
                        onDeleted: () => data.removeCuisine(c),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: Text(
                    data.cuisines.isEmpty ? "No cuisines selected yet." : "${data.cuisines.length}/5 selected",
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: data.cuisines.length >= 5
                      ? null
                      : () async {
                          final selected = await showDialog<String>(
                            context: context,
                            builder: (_) => _CountryCuisinePicker(),
                          );
                          if (selected != null) data.addCuisine(selected);
                        },
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),

            const Divider(height: 22),

            Text(
              "Popular picks",
              style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade800),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: popular.map((c) {
                final already = data.cuisines.contains(c);
                final disabled = already || data.cuisines.length >= 5;
                return ActionChip(
                  label: Text(c),
                  onPressed: disabled ? null : () => data.addCuisine(c),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountryCuisinePicker extends StatefulWidget {
  @override
  State<_CountryCuisinePicker> createState() => _CountryCuisinePickerState();
}

class _CountryCuisinePickerState extends State<_CountryCuisinePicker> {
  String? country;

  static const Map<String, List<String>> byCountry = _CuisineSelector.byCountry;

  @override
  Widget build(BuildContext context) {
    final cuisines = (country == null) ? <String>[] : byCountry[country!] ?? <String>[];

    return AlertDialog(
      title: const Text("Add a cuisine"),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: country,
              decoration: const InputDecoration(labelText: "Country/Region"),
              items: byCountry.keys.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
              onChanged: (v) => setState(() => country = v),
            ),
            const SizedBox(height: 12),
            if (country != null)
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "Cuisine"),
                items: cuisines.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) {
                  if (v == null) return;
                  Navigator.pop(context, v);
                },
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
      ],
    );
  }
}

/// -------------------------------
/// Allergies (modern chips)
/// -------------------------------
class _AllergySelector extends StatelessWidget {
  final AppData data;
  const _AllergySelector({required this.data});

  static const options = [
    "Peanuts",
    "Tree nuts",
    "Dairy",
    "Egg",
    "Soy",
    "Gluten",
    "Fish",
    "Shellfish",
    "Sesame",
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: options.map((a) {
            final selected = data.allergies.contains(a);
            return FilterChip(
              label: Text(a),
              selected: selected,
              selectedColor: kPrimary.withOpacity(0.18),
              onSelected: (_) => data.toggleAllergy(a),
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// -------------------------------
/// Cheat day
/// -------------------------------
class _CheatDaySelector extends StatelessWidget {
  final AppData data;
  const _CheatDaySelector({required this.data});

  static const prefs = ["Light", "Moderate", "Heavy"];

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            SwitchListTile(
              value: data.cheatDayEnabled,
              onChanged: (v) {
                data.cheatDayEnabled = v;
                data.notifyListeners();
              },
              title: const Text("Enable cheat day"),
              subtitle: const Text("We’ll keep your plan flexible."),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
            if (data.cheatDayEnabled)
              DropdownButtonFormField<String>(
                value: data.cheatDayPreference,
                decoration: const InputDecoration(labelText: "Cheat day intensity"),
                items: prefs.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                onChanged: (v) {
                  if (v == null) return;
                  data.cheatDayPreference = v;
                  data.notifyListeners();
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// -------------------------------
/// Step 3: Frequency page (based on diet + nonveg selections)
/// -------------------------------
class FrequencyPage extends StatelessWidget {
  final AppData data;
  const FrequencyPage({super.key, required this.data});

  List<String> itemsForUser() {
    final items = <String>[];

    if (data.dietType == DietType.vegan) {
      items.add("Veg");
    } else if (data.dietType == DietType.veg) {
      items.add("Veg");
    } else if (data.dietType == DietType.eggetarian) {
      items.addAll(["Eggs", "Veg"]);
    } else if (data.dietType == DietType.pescatarian) {
      items.addAll(["Seafood", "Veg"]);
    } else if (data.dietType == DietType.nonveg) {
      items.addAll(data.nonVegItems.isEmpty ? ["Eggs", "Chicken", "Seafood", "Veg"] : {...data.nonVegItems, "Veg"});
    }

    final unique = items.toSet().toList();
    unique.sort();
    return unique;
  }

  @override
  Widget build(BuildContext context) {
    final items = itemsForUser();

    return Scaffold(
      appBar: AppBar(title: const Text("Frequency")),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            children: [
              _SectionTitle(
                title: "How often do you prefer these?",
                subtitle: "Everyday, specific weekdays, or once a month.",
              ),
              const SizedBox(height: 12),

              ...items.map((item) => _FrequencyCard(data: data, item: item)).toList(),

              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: kPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                onPressed: () async {
                  await data.save();
                  if (context.mounted) {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text("Saved ✅"),
                        content: const Text(
                          "Saved locally as JSON in app documents storage:\nfoodadvisor_profile.json",
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK")),
                        ],
                      ),
                    );
                  }
                },
                child: const Text("Save Profile"),
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                onPressed: () {
                  showDialog(context: context, builder: (_) => _SummaryDialog(data: data));
                },
                child: const Text("Preview Summary"),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _FrequencyCard extends StatelessWidget {
  final AppData data;
  final String item;
  const _FrequencyCard({required this.data, required this.item});

  static const days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

  @override
  Widget build(BuildContext context) {
    final cfg = data.frequency[item] ?? {};
    final mode = (cfg["mode"] ?? "everyday") as String;
    final weekdays = ((cfg["weekdays"] ?? []) as List).cast<int>();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),

            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ChoiceChip(
                  label: const Text("Everyday"),
                  selected: mode == "everyday",
                  onSelected: (_) => data.setFrequencyMode(item, "everyday"),
                ),
                ChoiceChip(
                  label: const Text("Weekdays"),
                  selected: mode == "weekdays",
                  onSelected: (_) => data.setFrequencyMode(item, "weekdays"),
                ),
                ChoiceChip(
                  label: const Text("Once a month"),
                  selected: mode == "monthly",
                  onSelected: (_) => data.setFrequencyMode(item, "monthly"),
                ),
              ],
            ),

            if (mode == "weekdays") ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(7, (i) {
                  final on = weekdays.contains(i);
                  return FilterChip(
                    label: Text(days[i]),
                    selected: on,
                    selectedColor: kSecondary.withOpacity(0.18),
                    onSelected: (_) => data.toggleFrequencyWeekday(item, i),
                  );
                }),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// -------------------------------
/// Summary Dialog
/// -------------------------------
class _SummaryDialog extends StatelessWidget {
  final AppData data;
  const _SummaryDialog({required this.data});

  static const days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

  @override
  Widget build(BuildContext context) {
    String freqText() {
      if (data.frequency.isEmpty) return "-";
      final lines = <String>[];
      data.frequency.forEach((item, cfg) {
        final mode = (cfg["mode"] ?? "everyday") as String;
        if (mode == "everyday") {
          lines.add("$item: Everyday");
        } else if (mode == "monthly") {
          lines.add("$item: Once a month");
        } else {
          final d = ((cfg["weekdays"] ?? []) as List).cast<int>();
          final label = d.isEmpty ? "-" : d.map((i) => days[i]).join(", ");
          lines.add("$item: $label");
        }
      });
      return lines.join("\n");
    }

    return AlertDialog(
      title: const Text("Preview"),
      content: SingleChildScrollView(
        child: Text(
          "Name: ${data.name}\n"
          "Gender: ${data.gender}\n"
          "Age: ${data.age}\n"
          "Height: ${data.heightCm} cm\n"
          "Weight: ${data.weightKg} kg\n"
          "Body fat: ${data.bodyFatPct?.toStringAsFixed(1) ?? '-'}%\n"
          "Visceral fat: ${data.visceralFatPct?.toStringAsFixed(1) ?? '-'}%\n\n"
          "Diet: ${dietLabel(data.dietType)}\n"
          "Non-veg items: ${data.nonVegItems.isEmpty ? '-' : data.nonVegItems.join(', ')}\n"
          "Cuisines: ${data.cuisines.isEmpty ? '-' : data.cuisines.join(', ')}\n"
          "Allergies: ${data.allergies.isEmpty ? '-' : data.allergies.join(', ')}\n"
          "Cheat day: ${data.cheatDayEnabled ? data.cheatDayPreference : 'Disabled'}\n\n"
          "Frequency:\n${freqText()}",
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
      ],
    );
  }
}

/// -------------------------------
/// Small UI helpers
/// -------------------------------
class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(subtitle, style: TextStyle(color: Colors.grey.shade700, height: 1.25)),
      ],
    );
  }
}

class _TwoCols extends StatelessWidget {
  final Widget left;
  final Widget right;
  const _TwoCols({required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
  }
}
