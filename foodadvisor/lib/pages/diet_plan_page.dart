import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../app.dart';
import '../models/app_data.dart';
import '../services/profile_service.dart';
import '../theme.dart';
import '../widgets/form_widgets.dart';
import 'diet_generation_options_page.dart';
import 'upgrade_plan_page.dart';
import 'user_details_page.dart';

class DietPlanPage extends StatefulWidget {
  final AppData data;
  final WidgetBuilder preferencesBuilder;
  const DietPlanPage({super.key, required this.data, required this.preferencesBuilder});

  @override
  State<DietPlanPage> createState() => _DietPlanPageState();
}

class _DietPlanPageState extends State<DietPlanPage> {
  late Future<_DietPlanBundle> _dietPlanFuture;
  DietPlanData? _cachedPlan;
  final Map<String, String> _editablePlan = {};
  final TextEditingController _selfDeficitController = TextEditingController(text: '300');
  bool _hasRoutedMissingUserId = false;
  final Map<String, _DayCompletionStatus> _dayStatuses = {};
  final Set<String> _generatedRecipes = {};

  @override
  void initState() {
    super.initState();
    _dietPlanFuture = _fetchBundle();
  }

  @override
  void dispose() {
    _selfDeficitController.dispose();
    super.dispose();
  }

  Future<_DietPlanBundle> _fetchBundle() async {
    final results = await Future.wait([
      fetchDietPlan(),
      fetchUserProfileSummary(),
      fetchDietGenerationChoice(),
      fetchProfileJobId(),
    ]);
    final plan = results[0] as DietPlanData?;
    if (plan != null) {
      _cachedPlan = plan;
    }
    final resolvedPlan = plan ?? _cachedPlan;
    return _DietPlanBundle(
      plan: resolvedPlan,
      profile: results[1] as UserProfileSummary?,
      choice: results[2] as DietGenerationChoice?,
      jobId: results[3] as String?,
    );
  }

  void _refreshPlan() {
    setState(() {
      _dietPlanFuture = _fetchBundle();
    });
  }

  void _routeMissingUserId(UserProfileSummary? profile) {
    if (_hasRoutedMissingUserId) return;
    _hasRoutedMissingUserId = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (profile == null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => UserDetailsPage(
              data: widget.data,
              nextPageBuilder: widget.preferencesBuilder,
            ),
          ),
        );
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DietGenerationOptionsPage(
            data: widget.data,
            preferencesBuilder: widget.preferencesBuilder,
          ),
        ),
      );
    });
  }

  double? _bmrForProfile(UserProfileSummary? profile) {
    if (profile == null) return null;
    final base = 10 * profile.weightKg + 6.25 * profile.heightCm - 5 * profile.age;
    final gender = profile.gender.toLowerCase();
    if (gender.contains('female')) {
      return base - 161;
    }
    if (gender.contains('male')) {
      return base + 5;
    }
    return base - 78;
  }

  double? _calorieDeficit(double? bmr) {
    if (bmr == null) return null;
    return bmr * 0.85;
  }

  DateTime _startDateForPlan(DietPlanData? dietPlan) {
    final startDate = dietPlan?.startDate;
    if (startDate != null) {
      return DateTime(startDate.year, startDate.month, startDate.day);
    }
    final generatedAt = dietPlan?.generatedAt ?? DateTime.now();
    final normalized = DateTime(generatedAt.year, generatedAt.month, generatedAt.day);
    return normalized.add(const Duration(days: 1));
  }

  List<_DayPlan> _dayPlans(DietPlanData? dietPlan) {
    final fallbackMeals = [
      ["Greek yogurt + fruit", "Millet bowl + greens", "Grilled paneer + veggies"],
      ["Avocado toast", "Dal + brown rice", "Tofu stir-fry"],
      ["Moong chilla", "Veg quinoa salad", "Baked fish + veggies"],
      ["Smoothie bowl", "Chickpea wrap", "Lean chicken + salad"],
      ["Idli + sambar", "Veggie biryani", "Lentil soup + salad"],
      ["Overnight oats", "Paneer tikka bowl", "Veg curry + roti"],
      ["Upma + fruit", "Sushi bowl", "Stuffed bell peppers"],
    ];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDate = _startDateForPlan(dietPlan);
    final plans = <_DayPlan>[];
    for (var i = 0; i < 7; i++) {
      final day = startDate.add(Duration(days: i));
      final key = _weekdayKey(day.weekday);
      final breakfast = dietPlan?.plan['${key}_breakfast'];
      final lunch = dietPlan?.plan['${key}_lunch'];
      final dinner = dietPlan?.plan['${key}_dinner'];
      final meals = (breakfast != null && lunch != null && dinner != null)
          ? [breakfast, lunch, dinner]
          : fallbackMeals[i % fallbackMeals.length];
      plans.add(
        _DayPlan(
          date: day,
          meals: meals,
          isPast: day.isBefore(today),
          isFuture: day.isAfter(today),
        ),
      );
    }
    return plans;
  }

  Map<String, String> _fallbackPlanMap() {
    const fallbackMeals = [
      ["Greek yogurt + fruit", "Millet bowl + greens", "Grilled paneer + veggies"],
      ["Avocado toast", "Dal + brown rice", "Tofu stir-fry"],
      ["Moong chilla", "Veg quinoa salad", "Baked fish + veggies"],
      ["Smoothie bowl", "Chickpea wrap", "Lean chicken + salad"],
      ["Idli + sambar", "Veggie biryani", "Lentil soup + salad"],
      ["Overnight oats", "Paneer tikka bowl", "Veg curry + roti"],
      ["Upma + fruit", "Sushi bowl", "Stuffed bell peppers"],
    ];
    final map = <String, String>{};
    final now = DateTime.now();
    for (var i = 0; i < 7; i++) {
      final key = _weekdayKey(now.add(Duration(days: i)).weekday);
      map['${key}_breakfast'] = fallbackMeals[i][0];
      map['${key}_lunch'] = fallbackMeals[i][1];
      map['${key}_dinner'] = fallbackMeals[i][2];
    }
    return map;
  }

  void _ensureEditablePlan(Map<String, String> source) {
    if (_editablePlan.isNotEmpty) return;
    _editablePlan.addAll(source);
  }

  String _dateKey(DateTime date) {
    return '${date.year}-${date.month}-${date.day}';
  }

  Future<void> _editDay(BuildContext context, String dayKey) async {
    final breakfast = TextEditingController(text: _editablePlan['${dayKey}_breakfast'] ?? '');
    final lunch = TextEditingController(text: _editablePlan['${dayKey}_lunch'] ?? '');
    final dinner = TextEditingController(text: _editablePlan['${dayKey}_dinner'] ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Edit $dayKey meals"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: breakfast,
                decoration: const InputDecoration(labelText: "Breakfast"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: lunch,
                decoration: const InputDecoration(labelText: "Lunch"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dinner,
                decoration: const InputDecoration(labelText: "Dinner"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text("Save")),
        ],
      ),
    );
    if (saved == true) {
      setState(() {
        _editablePlan['${dayKey}_breakfast'] = breakfast.text.trim();
        _editablePlan['${dayKey}_lunch'] = lunch.text.trim();
        _editablePlan['${dayKey}_dinner'] = dinner.text.trim();
      });
    }
  }

  String _weekdayKey(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Mon';
      case DateTime.tuesday:
        return 'Tue';
      case DateTime.wednesday:
        return 'Wed';
      case DateTime.thursday:
        return 'Thu';
      case DateTime.friday:
        return 'Fri';
      case DateTime.saturday:
        return 'Sat';
      case DateTime.sunday:
        return 'Sun';
    }
    return 'Mon';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Diet details"),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              tooltip: "Refresh",
              onPressed: _refreshPlan,
              icon: const Icon(Icons.refresh_rounded),
            ),
            PopupMenuButton<_PlanMenuAction>(
              onSelected: (action) async {
                switch (action) {
                  case _PlanMenuAction.updateDetails:
                    widget.data.reset();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserDetailsPage(
                          data: widget.data,
                          nextPageBuilder: widget.preferencesBuilder,
                        ),
                      ),
                    );
                    break;
                  case _PlanMenuAction.upgradePlan:
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const UpgradePlanPage()),
                    );
                    break;
                  case _PlanMenuAction.about:
                    showDialog<void>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text("About FoodAdvisor"),
                        content: const Text(
                          "FoodAdvisor helps you stay consistent with balanced meal plans and daily progress.",
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("Close"),
                          ),
                        ],
                      ),
                    );
                    break;
                  case _PlanMenuAction.signOut:
                    await FirebaseAuth.instance.signOut();
                    await GoogleSignIn().signOut();
                    if (!mounted) return;
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => LandingPage(data: widget.data)),
                      (_) => false,
                    );
                    break;
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _PlanMenuAction.updateDetails,
                  child: ListTile(
                    leading: Icon(Icons.manage_accounts_outlined),
                    title: Text("Update details"),
                  ),
                ),
                PopupMenuItem(
                  value: _PlanMenuAction.upgradePlan,
                  child: ListTile(
                    leading: Icon(Icons.workspace_premium_outlined),
                    title: Text("Upgrade plan"),
                  ),
                ),
                PopupMenuItem(
                  value: _PlanMenuAction.about,
                  child: ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text("About"),
                  ),
                ),
                PopupMenuDivider(),
                PopupMenuItem(
                  value: _PlanMenuAction.signOut,
                  child: ListTile(
                    leading: Icon(Icons.logout_rounded),
                    title: Text("Sign out"),
                  ),
                ),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: FutureBuilder<_DietPlanBundle>(
            future: _dietPlanFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    "Unable to load diet plan: ${snapshot.error}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                );
              }

              final profile = snapshot.data?.profile;
              final dietPlan = snapshot.data?.plan;
              final choice = snapshot.data?.choice;
              final jobId = snapshot.data?.jobId;
              final bmr = _bmrForProfile(profile);
              final deficit = dietPlan?.calorieDeficit ?? _calorieDeficit(bmr)?.round();

              if (dietPlan != null && dietPlan.userId == null) {
                _routeMissingUserId(profile);
                return const _DietLoadingState(
                  message: "Updating your plan details.",
                );
              }

              if (choice == null) {
                return const _DietLoadingState(
                  message: "Pick a diet generation style to continue.",
                );
              }

              if (choice.generatedBy == 'expert') {
                return const _DietLoadingState(
                  message: "Expert nutritionist plans are coming soon.",
                );
              }

              if (choice.generatedBy == 'self' && dietPlan == null) {
                final source = dietPlan?.plan ?? _fallbackPlanMap();
                _ensureEditablePlan(source);
                return _SelfPlanEditor(
                  data: widget.data,
                  editablePlan: _editablePlan,
                  deficitController: _selfDeficitController,
                  onUpdate: () => setState(() {}),
                  onUpdateProfile: () {
                    widget.data.reset();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserDetailsPage(
                          data: widget.data,
                          nextPageBuilder: widget.preferencesBuilder,
                        ),
                      ),
                    );
                  },
                  onSave: jobId == null
                      ? null
                      : (startDate) async {
                          final deficitValue = int.tryParse(_selfDeficitController.text.trim()) ?? 300;
                          await saveSelfDietPlan(
                            jobId: jobId,
                            calorieDeficit: deficitValue,
                            plan: _editablePlan,
                            startDate: startDate,
                          );
                          _refreshPlan();
                        },
                );
              }

              if (dietPlan == null) {
                return const _DietLoadingState(
                  message: "Diet is loading soon.",
                );
              }

              final plans = _dayPlans(dietPlan);
              _ensureEditablePlan(dietPlan.plan);
              const bottomBarHeight = 140.0;
              final planList = ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, bottomBarHeight),
                children: [
                  _DietHeader(
                    title: "FoodAdvisor",
                    subtitle: user?.email ?? "Welcome back",
                  ),
                  const SizedBox(height: 16),
                  _GreetingCard(
                    name: profile?.name.isNotEmpty == true ? profile!.name : (user?.displayName ?? "Friend"),
                    note: "Your next 7 days are planned for balanced energy and steady calorie deficit.",
                  ),
                  const SizedBox(height: 12),
                  _FinalizePlanActions(
                    onGenerateAi: () async {
                      await saveDietGenerationChoice('ai');
                      if (!context.mounted) return;
                      _refreshPlan();
                    },
                    onNutritionist: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const UpgradePlanPage()),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _MetricsCard(
                    bmr: bmr,
                    deficitTarget: deficit?.toDouble(),
                  ),
                  const SizedBox(height: 18),
                  const SectionTitle(
                    title: "7-day diet plan",
                    subtitle: "Swipe right for completed, left for not completed.",
                  ),
                  const SizedBox(height: 12),
                  ...plans.map((plan) {
                    final dateKey = _dateKey(plan.date);
                    final status = _dayStatuses[dateKey] ?? _DayCompletionStatus.pending;
                    final recipesGenerated = _generatedRecipes.contains(dateKey);
                    return Dismissible(
                      key: ValueKey(dateKey),
                      direction: plan.isFuture ? DismissDirection.none : DismissDirection.horizontal,
                      confirmDismiss: (direction) async {
                        setState(() {
                          _dayStatuses[dateKey] = direction == DismissDirection.startToEnd
                              ? _DayCompletionStatus.completed
                              : _DayCompletionStatus.missed;
                        });
                        return false;
                      },
                      background: _SwipeStatusBackground(
                        label: "Completed",
                        color: Colors.green.shade100,
                        icon: Icons.check_circle_outline,
                        alignment: Alignment.centerLeft,
                      ),
                      secondaryBackground: _SwipeStatusBackground(
                        label: "Not completed",
                        color: Colors.red.shade100,
                        icon: Icons.highlight_off,
                        alignment: Alignment.centerRight,
                      ),
                      child: _DayPlanCard(
                        plan: plan,
                        status: status,
                        recipesGenerated: recipesGenerated,
                        onGenerateRecipes: plan.isFuture
                            ? null
                            : () {
                                setState(() {
                                  _generatedRecipes.add(dateKey);
                                });
                              },
                        onViewRecipes: () {
                          showDialog<void>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text("Recipes"),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: plan.meals
                                    .map(
                                      (meal) => ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: const Icon(Icons.restaurant_menu_rounded),
                                        title: Text(meal),
                                        subtitle: const Text("Recipe details coming soon."),
                                      ),
                                    )
                                    .toList(),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text("Close"),
                                ),
                              ],
                            ),
                          );
                        },
                        onEdit: () => _editDay(context, _weekdayKey(plan.date.weekday)),
                      ),
                    );
                  }),
                  const SizedBox(height: 18),
                  _PlanContinuationCard(
                    onCopy: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Plan copied for the next 7 days.")),
                      );
                    },
                    onGenerateNew: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DietGenerationOptionsPage(
                            data: widget.data,
                            preferencesBuilder: widget.preferencesBuilder,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );

              return Stack(
                children: [
                  planList,
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 12,
                    child: _WhatsAppReminderBar(),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

enum _PlanMenuAction { updateDetails, upgradePlan, about, signOut }

class _DietPlanBundle {
  final DietPlanData? plan;
  final UserProfileSummary? profile;
  final DietGenerationChoice? choice;
  final String? jobId;

  const _DietPlanBundle({
    required this.plan,
    required this.profile,
    required this.choice,
    required this.jobId,
  });
}

class _DietLoadingState extends StatelessWidget {
  final String message;
  const _DietLoadingState({required this.message});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 16),
        const Text(
          "Diet is loading soon",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 20),
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.network(
              "https://media.giphy.com/media/QssGEmpkyEOhBCb7e1/giphy.gif",
              height: 160,
              width: 160,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ],
    );
  }
}

class _SelfPlanEditor extends StatefulWidget {
  final AppData data;
  final Map<String, String> editablePlan;
  final TextEditingController deficitController;
  final WidgetBuilder preferencesBuilder;
  final VoidCallback onUpdate;
  final VoidCallback onUpdateProfile;
  final Future<void> Function(DateTime startDate)? onSave;

  const _SelfPlanEditor({
    required this.data,
    required this.editablePlan,
    required this.deficitController,
    required this.preferencesBuilder,
    required this.onUpdate,
    required this.onUpdateProfile,
    required this.onSave,
  });

  @override
  State<_SelfPlanEditor> createState() => _SelfPlanEditorState();
}

class _SelfPlanEditorState extends State<_SelfPlanEditor> {
  bool _isSaving = false;

  Future<DateTime?> _pickStartDate() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return showDialog<DateTime>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("When should the diet start?"),
          content: SizedBox(
            width: double.maxFinite,
            height: 320,
            child: ListView.builder(
              itemCount: 15,
              itemBuilder: (context, index) {
                final date = today.add(Duration(days: index - 7));
                final isPast = date.isBefore(today);
                return ListTile(
                  title: Text(MaterialLocalizations.of(context).formatMediumDate(date)),
                  subtitle: Text(isPast ? "Unavailable" : "Available"),
                  enabled: !isPast,
                  onTap: isPast ? null : () => Navigator.pop(dialogContext, date),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    if (widget.onSave == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Unable to save yet. Please try again in a moment.")),
      );
      return;
    }
    final startDate = await _pickStartDate();
    if (startDate == null) return;
    setState(() {
      _isSaving = true;
    });
    try {
      await widget.onSave?.call(startDate);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Plan saved successfully.")),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Unable to save plan. Please try again.")),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const weekDays = {
      'Mon': 'Monday',
      'Tue': 'Tuesday',
      'Wed': 'Wednesday',
      'Thu': 'Thursday',
      'Fri': 'Friday',
      'Sat': 'Saturday',
      'Sun': 'Sunday',
    };

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          "Build your own 7-day plan",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          "Fill in breakfast, lunch, and dinner for each day.",
          style: TextStyle(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: widget.onUpdateProfile,
            icon: const Icon(Icons.manage_accounts_outlined),
            label: const Text("Update details"),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: widget.deficitController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: "Calorie deficit (kcal)"),
        ),
        const SizedBox(height: 12),
        ...weekDays.entries.map((entry) {
          final key = entry.key;
          return Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.value, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  _SelfMealField(
                    label: "Breakfast",
                    initialValue: widget.editablePlan['${key}_breakfast'] ?? '',
                    onChanged: (value) {
                      widget.editablePlan['${key}_breakfast'] = value;
                      widget.onUpdate();
                    },
                  ),
                  const SizedBox(height: 10),
                  _SelfMealField(
                    label: "Lunch",
                    initialValue: widget.editablePlan['${key}_lunch'] ?? '',
                    onChanged: (value) {
                      widget.editablePlan['${key}_lunch'] = value;
                      widget.onUpdate();
                    },
                  ),
                  const SizedBox(height: 10),
                  _SelfMealField(
                    label: "Dinner",
                    initialValue: widget.editablePlan['${key}_dinner'] ?? '',
                    onChanged: (value) {
                      widget.editablePlan['${key}_dinner'] = value;
                      widget.onUpdate();
                    },
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _handleSave,
          child: _isSaving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text("Save plan"),
        ),
      ],
    );
  }
}

class _SelfMealField extends StatelessWidget {
  final String label;
  final String initialValue;
  final ValueChanged<String> onChanged;

  const _SelfMealField({
    required this.label,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initialValue,
      decoration: InputDecoration(labelText: label),
      onChanged: onChanged,
    );
  }
}

class _SelfPlanNextStepPage extends StatelessWidget {
  final AppData data;
  final WidgetBuilder preferencesBuilder;

  const _SelfPlanNextStepPage({
    required this.data,
    required this.preferencesBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Next step")),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              "Choose how to finalize your plan",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            _NextStepCard(
              title: "Generate by AI",
              description: "Let FoodAdvisor refine your plan with AI insights.",
              icon: Icons.auto_awesome_rounded,
              accent: kPrimary,
              onTap: () async {
                await saveDietGenerationChoice('ai');
                if (!context.mounted) return;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DietPlanPage(
                      data: data,
                      preferencesBuilder: preferencesBuilder,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _NextStepCard(
              title: "Generate by nutritionist",
              description: "Upgrade to get expert nutritionist support.",
              icon: Icons.health_and_safety_rounded,
              accent: kSecondary,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UpgradePlanPage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _NextStepCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _NextStepCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: accent.withOpacity(0.15),
                  ),
                  child: Icon(icon, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              description,
              style: TextStyle(color: Colors.grey.shade700, height: 1.4),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: onTap,
                child: const Text("Continue"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DietHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _DietHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [kPrimary, kSecondary],
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white.withOpacity(0.2),
            ),
            child: const Icon(Icons.restaurant_menu_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.white.withOpacity(0.9)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FinalizePlanActions extends StatelessWidget {
  final VoidCallback onNutritionist;
  final VoidCallback onGenerateAi;

  const _FinalizePlanActions({
    required this.onNutritionist,
    required this.onGenerateAi,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onGenerateAi,
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text("Generate by AI"),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: onNutritionist,
            icon: const Icon(Icons.health_and_safety_outlined),
            label: const Text("Nutritionist"),
          ),
        ),
      ],
    );
  }
}

class _WhatsAppReminderBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Schedule reminder",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              "WhatsApp reminders are coming soon.",
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: const Text("Enable WhatsApp reminders"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanContinuationCard extends StatelessWidget {
  final VoidCallback onCopy;
  final VoidCallback onGenerateNew;

  const _PlanContinuationCard({
    required this.onCopy,
    required this.onGenerateNew,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Continue your plan",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              "After 7 days, you can reuse this plan or generate a fresh one.",
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCopy,
                    child: const Text("Copy for next 7 days"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: onGenerateNew,
                    child: const Text("Generate new"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GreetingCard extends StatelessWidget {
  final String name;
  final String note;

  const _GreetingCard({required this.name, required this.note});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Hello, $name",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              note,
              style: TextStyle(color: Colors.grey.shade700, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricsCard extends StatelessWidget {
  final double? bmr;
  final double? deficitTarget;

  const _MetricsCard({required this.bmr, required this.deficitTarget});

  @override
  Widget build(BuildContext context) {
    final bmrLabel = bmr == null ? "--" : bmr!.toStringAsFixed(0);
    final deficitLabel = deficitTarget == null ? "--" : deficitTarget!.toStringAsFixed(0);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _MetricTile(
                icon: Icons.local_fire_department_rounded,
                title: "BMR",
                value: "$bmrLabel kcal",
                accent: kPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricTile(
                icon: Icons.trending_down_rounded,
                title: "Calorie deficit",
                value: "$deficitLabel kcal",
                accent: kSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color accent;

  const _MetricTile({required this.icon, required this.title, required this.value, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: accent.withOpacity(0.08),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _DayPlan {
  final DateTime date;
  final List<String> meals;
  final bool isPast;
  final bool isFuture;

  const _DayPlan({
    required this.date,
    required this.meals,
    required this.isPast,
    required this.isFuture,
  });
}

enum _DayCompletionStatus { pending, completed, missed }

class _DayPlanCard extends StatelessWidget {
  final _DayPlan plan;
  final _DayCompletionStatus status;
  final bool recipesGenerated;
  final VoidCallback onEdit;
  final VoidCallback? onGenerateRecipes;
  final VoidCallback onViewRecipes;

  const _DayPlanCard({
    required this.plan,
    required this.status,
    required this.recipesGenerated,
    required this.onEdit,
    required this.onGenerateRecipes,
    required this.onViewRecipes,
  });

  static const weekDays = [
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday",
    "Sunday",
  ];

  @override
  Widget build(BuildContext context) {
    final weekday = weekDays[plan.date.weekday - 1];
    final dateLabel = "${plan.date.day}/${plan.date.month}";
    final backgroundColor = _statusColor(context);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: kPrimary.withOpacity(0.12),
                  ),
                  child: Text(
                    weekday,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const Spacer(),
                Text(
                  dateLabel,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                if (!plan.isFuture)
                  IconButton(
                    tooltip: "Edit meals",
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ...plan.meals.map(
              (meal) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 16, color: kSecondary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(meal)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatusPill(status: status, isFuture: plan.isFuture),
                const Spacer(),
                if (!recipesGenerated)
                  FilledButton.tonalIcon(
                    onPressed: onGenerateRecipes,
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: const Text("Generate recipes"),
                  )
                else
                  TextButton(
                    onPressed: onViewRecipes,
                    child: const Text("View recipes"),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(BuildContext context) {
    if (plan.isFuture) {
      return Colors.grey.shade100;
    }
    switch (status) {
      case _DayCompletionStatus.completed:
        return Colors.green.shade50;
      case _DayCompletionStatus.missed:
        return Colors.red.shade50;
      case _DayCompletionStatus.pending:
        return Theme.of(context).cardColor;
    }
  }
}

class _StatusPill extends StatelessWidget {
  final _DayCompletionStatus status;
  final bool isFuture;

  const _StatusPill({required this.status, required this.isFuture});

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;
    if (isFuture) {
      label = "Upcoming";
      color = Colors.grey.shade500;
    } else {
      switch (status) {
        case _DayCompletionStatus.completed:
          label = "Completed";
          color = Colors.green.shade700;
          break;
        case _DayCompletionStatus.missed:
          label = "Not completed";
          color = Colors.red.shade700;
          break;
        case _DayCompletionStatus.pending:
          label = "Pending";
          color = Colors.orange.shade700;
          break;
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withOpacity(0.12),
      ),
      child: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _SwipeStatusBackground extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final Alignment alignment;

  const _SwipeStatusBackground({
    required this.label,
    required this.color,
    required this.icon,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: alignment == Alignment.centerLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          Icon(icon, color: Colors.black87),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
