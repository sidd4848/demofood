import 'package:flutter/material.dart';

import '../models/app_data.dart';
import '../theme.dart';
import '../widgets/form_widgets.dart';

class UserDetailsPage extends StatefulWidget {
  final AppData data;
  final WidgetBuilder nextPageBuilder;
  const UserDetailsPage({super.key, required this.data, required this.nextPageBuilder});

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
                const SectionTitle(
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
                TwoColumnRow(
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
                TwoColumnRow(
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
                      MaterialPageRoute(builder: widget.nextPageBuilder),
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
