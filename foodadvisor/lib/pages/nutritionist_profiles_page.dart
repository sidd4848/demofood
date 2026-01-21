import 'package:flutter/material.dart';

import '../services/nutritionist_service.dart';
import '../theme.dart';

class NutritionistProfilesPage extends StatelessWidget {
  const NutritionistProfilesPage({super.key});

  @override
  Widget build(BuildContext context) {
    const service = NutritionistService();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutrition experts'),
      ),
      body: SafeArea(
        child: FutureBuilder<List<NutritionistProfile>>(
          future: service.fetchProfiles(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Unable to load nutrition experts.',
                  style: TextStyle(color: Colors.red.shade400),
                ),
              );
            }
            final profiles = snapshot.data ?? const <NutritionistProfile>[];
            if (profiles.isEmpty) {
              return const Center(child: Text('No nutrition experts available right now.'));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: profiles.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final profile = profiles[index];
                return _NutritionistCard(profile: profile);
              },
            );
          },
        ),
      ),
    );
  }
}

class _NutritionistCard extends StatelessWidget {
  final NutritionistProfile profile;

  const _NutritionistCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: kPrimary.withOpacity(0.15),
                  child: const Icon(Icons.person, color: kPrimary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(profile.specialty, style: TextStyle(color: Colors.grey.shade700)),
                    ],
                  ),
                ),
                _RatingPill(rating: profile.rating),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.work_outline, size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(profile.experience, style: TextStyle(color: Colors.grey.shade700)),
                const SizedBox(width: 12),
                Icon(Icons.place_outlined, size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(profile.location, style: TextStyle(color: Colors.grey.shade700)),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Request sent to ${profile.name}')),
                  );
                },
                icon: const Icon(Icons.call_outlined),
                label: const Text('Request call'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingPill extends StatelessWidget {
  final double rating;

  const _RatingPill({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: kSecondary.withOpacity(0.15),
      ),
      child: Row(
        children: [
          const Icon(Icons.star, size: 16, color: kSecondary),
          const SizedBox(width: 4),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(fontWeight: FontWeight.w700, color: kSecondary),
          ),
        ],
      ),
    );
  }
}
