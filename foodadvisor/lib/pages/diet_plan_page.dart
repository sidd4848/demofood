import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/app_data.dart';
import '../services/profile_service.dart';
import '../theme.dart';
import '../widgets/form_widgets.dart';
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

  @override
  void initState() {
    super.initState();
    _dietPlanFuture = _fetchBundle();
  }

  Future<_DietPlanBundle> _fetchBundle() async {
    final results = await Future.wait([
      fetchDietPlan(),
      fetchUserProfileSummary(),
    ]);
    return _DietPlanBundle(
      plan: results[0] as DietPlanData?,
      profile: results[1] as UserProfileSummary?,
    );
  }

  void _refreshPlan() {
    setState(() {
      _dietPlanFuture = _fetchBundle();
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
    final plans = <_DayPlan>[];
    for (var i = 0; i < 7; i++) {
      final day = now.add(Duration(days: i));
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
        ),
      );
    }
    return plans;
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

    return Scaffold(
      appBar: AppBar(
        title: const Text("Diet details"),
        actions: [
          IconButton(
            tooltip: "Refresh",
            onPressed: _refreshPlan,
            icon: const Icon(Icons.refresh_rounded),
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
            final bmr = _bmrForProfile(profile);
            final deficit = dietPlan?.calorieDeficit ?? _calorieDeficit(bmr)?.round();
            final plans = _dayPlans(dietPlan);

            if (dietPlan == null) {
              return _DietLoadingState(
                exampleJson: dietDocumentExampleJson('job_1710000000000_ab12cd'),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(20),
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
                const SizedBox(height: 16),
                _MetricsCard(
                  bmr: bmr,
                  deficitTarget: deficit?.toDouble(),
                ),
                const SizedBox(height: 18),
                const SectionTitle(
                  title: "7-day diet plan",
                  subtitle: "From today through the next 7 days.",
                ),
                const SizedBox(height: 12),
                ...plans.map((plan) => _DayPlanCard(plan: plan)).toList(),
                const SizedBox(height: 18),
                Card(
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
                ),
                const SizedBox(height: 18),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
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
                  child: const Text("Update profile"),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DietPlanBundle {
  final DietPlanData? plan;
  final UserProfileSummary? profile;

  const _DietPlanBundle({required this.plan, required this.profile});
}

class _DietLoadingState extends StatelessWidget {
  final String exampleJson;
  const _DietLoadingState({required this.exampleJson});

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
          "Our nutrition engine is crafting your 7-day plan right now.",
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
        const SizedBox(height: 24),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Example diet document",
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  exampleJson,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ],
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

  const _DayPlan({required this.date, required this.meals});
}

class _DayPlanCard extends StatelessWidget {
  final _DayPlan plan;
  const _DayPlanCard({required this.plan});

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

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
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
          ],
        ),
      ),
    );
  }
}
