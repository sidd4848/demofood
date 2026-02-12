import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'models/app_data.dart';
import 'pages/diet_generation_options_page.dart';
import 'pages/diet_plan_page.dart';
import 'pages/user_details_page.dart';
import 'services/profile_service.dart';
import 'theme.dart';
import 'theme_config.dart';
import 'widgets/branding.dart';
import 'widgets/form_widgets.dart';

class FoodAdvisorApp extends StatefulWidget {
  const FoodAdvisorApp({super.key});
  @override
  State<FoodAdvisorApp> createState() => _FoodAdvisorAppState();
}

class _FoodAdvisorAppState extends State<FoodAdvisorApp> {
  final AppData data = AppData();
  late Future<AppThemeConfig> _themeFuture;
  Timer? _splashTimer;
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    _themeFuture = AppThemeConfig.loadFromAsset('assets/theme.yaml');
    _splashTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) {
        setState(() => _showSplash = false);
      }
    });
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: data,
      builder: (context, _) => FutureBuilder<AppThemeConfig>(
        future: _themeFuture,
        builder: (context, snapshot) {
          final config = snapshot.data ?? AppThemeConfig.fallback();
          AppThemeConfig.apply(config);
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildTheme(config),
            home: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: _showSplash
                  ? SplashScreen(
                      key: const ValueKey('splash'),
                      config: config,
                    )
                  : LandingPage(
                      key: const ValueKey('landing'),
                      data: data,
                    ),
            ),
          );
        },
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PremiumHeader(),
              const SizedBox(height: 28),
              const Text(
                "Welcome back",
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.2),
              ),
              const SizedBox(height: 10),
              Text(
                "Sign in to keep your nutrition plan, favorites, and wellness goals synced across devices.",
                style: TextStyle(color: Colors.grey.shade700, height: 1.5),
              ),
              const SizedBox(height: 28),
              _SignInCard(data: data),
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
    final config = AppThemeConfig.current;
    return Row(
      children: [
        Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: [kPrimary, kSecondary],
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BrandLogo(asset: config.logoAsset, size: 44),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              config.appName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            Text(
              "Personalized nutrition plans",
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
}

class _SignInCard extends StatefulWidget {
  final AppData data;

  const _SignInCard({required this.data});

  @override
  State<_SignInCard> createState() => _SignInCardState();
}

class _SignInCardState extends State<_SignInCard> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  bool get _canSubmit {
    return _emailController.text.trim().isNotEmpty &&
        _passwordController.text.trim().isNotEmpty &&
        !_isLoading;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context);
    widget.data.setLocale(
      language: widget.data.languageCode ?? locale.languageCode,
      region: widget.data.regionCode ?? locale.countryCode ?? 'IN',
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _navigateToOnboarding({required bool resetData}) {
    if (resetData) {
      widget.data.reset();
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => UserDetailsPage(
          data: widget.data,
          nextPageBuilder: (_) => PreferencesPage(data: widget.data),
        ),
      ),
      (_) => false,
    );
  }

  void _navigateToDietPlan() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => DietPlanPage(
          data: widget.data,
          preferencesBuilder: (_) => PreferencesPage(data: widget.data),
        ),
      ),
      (_) => false,
    );
  }

  Future<void> _routeAfterSignIn() async {
    final dietPlan = await fetchDietPlan();
    final hasProfile = await hasExistingProfile();
    if (!mounted) return;
    if (dietPlan != null) {
      _navigateToDietPlan();
    } else if (hasProfile) {
      _navigateToDietPlan();
    } else {
      _showMessage("Welcome! Let's finish setting up your profile.");
      _navigateToOnboarding(resetData: true);
    }
  }

  String? _validateEmail(String? value) {
    final text = value?.trim() ?? "";
    if (text.isEmpty) {
      return "Email is required.";
    }
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(text)) {
      return "Enter a valid email.";
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final text = value?.trim() ?? "";
    if (text.isEmpty) {
      return "Password is required.";
    }
    if (text.length < 6) {
      return "Password must be at least 6 characters.";
    }
    return null;
  }

  Future<void> _signInWithEmail() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      _showMessage("Please fix the highlighted fields.");
      return;
    }
    FocusScope.of(context).unfocus();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _showMessage("Signed in successfully.");
      await _routeAfterSignIn();
    } on FirebaseAuthException catch (e) {
      _showMessage(e.message ?? "Unable to sign in. Please try again.");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createAccount() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      _showMessage("Please fix the highlighted fields.");
      return;
    }
    FocusScope.of(context).unfocus();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      _showMessage("Account created. You're signed in!");
      _navigateToOnboarding(resetData: true);
    } on FirebaseAuthException catch (e) {
      _showMessage(e.message ?? "Unable to create account.");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        _showMessage("Google sign-in was cancelled.");
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      _showMessage("Signed in with Google.");
      await _routeAfterSignIn();
    } on FirebaseAuthException catch (e) {
      _showMessage(e.message ?? "Google sign-in failed.");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Sign in",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                "Sign in to continue your personalised food journey.",
                style: TextStyle(color: Colors.grey.shade700, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: "Email address",
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: _validateEmail,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                decoration: const InputDecoration(
                  labelText: "Password",
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: _validatePassword,
                onFieldSubmitted: (_) => _canSubmit ? _signInWithEmail() : null,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: _canSubmit ? _signInWithEmail : null,
                  icon: _isLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login_rounded),
                  label: const Text("Sign in"),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: _isLoading ? null : _signInWithGoogle,
                  icon: const Icon(Icons.account_circle_rounded),
                  label: const Text("Continue with Google"),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                  const SizedBox(width: 8),
                  Text(
                    "New here?",
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                ],
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: _isLoading ? null : _createAccount,
                child: const Text("Create an account"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SplashScreen extends StatelessWidget {
  final AppThemeConfig config;

  const SplashScreen({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: config.primary,
        width: double.infinity,
        height: double.infinity,
        child: Center(
          child: Container(
            height: 140,
            width: 140,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(32),
            ),
            padding: const EdgeInsets.all(20),
            child: BrandLogo(asset: config.logoAsset, size: 80, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}


/// -------------------------------
/// Step 2: Preferences
/// Diet + NonVeg items + Cuisines + Allergies + Health Symptoms
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
              const SectionTitle(
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
              const SectionTitle(
                title: "Cuisines (up to 5)",
                subtitle: "Pick favourite cuisines for better suggestions.",
              ),
              const SizedBox(height: 10),
              _CuisineSelector(data: data),

              const SizedBox(height: 18),
              const SectionTitle(
                title: "Allergies",
                subtitle: "Tap to select. Compact + modern.",
              ),
              const SizedBox(height: 10),
              _AllergySelector(data: data),

              const SizedBox(height: 18),
              const SectionTitle(
                title: "Health symptoms",
                subtitle: "Select conditions to tailor your diet plan.",
              ),
              const SizedBox(height: 10),
              _HealthSymptomsSelector(data: data),

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
/// Health symptoms
/// -------------------------------
class _HealthSymptomsSelector extends StatelessWidget {
  final AppData data;
  const _HealthSymptomsSelector({required this.data});

  static const options = [
    "High blood pressure",
    "Diabetes",
    "High cholesterol",
    "Thyroid issues",
    "PCOS/PCOD",
    "Kidney concerns",
    "Digestive issues",
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
          children: options.map((symptom) {
            final selected = data.healthSymptoms.contains(symptom);
            return FilterChip(
              label: Text(symptom),
              selected: selected,
              selectedColor: kSecondary.withOpacity(0.18),
              onSelected: (_) => data.toggleHealthSymptom(symptom),
            );
          }).toList(),
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
              const SectionTitle(
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
                  try {
                    await saveProfileToFirebase(data);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Profile saved to Firebase ✅")),
                    );
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DietGenerationOptionsPage(
                          data: data,
                          preferencesBuilder: (_) => PreferencesPage(data: data),
                        ),
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text("Error"),
                        content: Text('Could not submit profile: $e'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
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
          "Health symptoms: ${data.healthSymptoms.isEmpty ? '-' : data.healthSymptoms.join(', ')}\n\n"
          "Frequency:\n${freqText()}",
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
      ],
    );
  }
}
