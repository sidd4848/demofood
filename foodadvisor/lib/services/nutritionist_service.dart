import 'package:cloud_firestore/cloud_firestore.dart';

class NutritionistProfile {
  const NutritionistProfile({
    required this.name,
    required this.specialty,
    required this.experience,
    required this.location,
    required this.rating,
  });

  final String name;
  final String specialty;
  final String experience;
  final String location;
  final double rating;

  factory NutritionistProfile.fromJson(Map<String, dynamic> data) {
    return NutritionistProfile(
      name: data['name']?.toString() ?? 'Nutrition expert',
      specialty: data['specialty']?.toString() ?? 'Personalized diet planning',
      experience: data['experience']?.toString() ?? '5+ years',
      location: data['location']?.toString() ?? 'Remote',
      rating: (data['rating'] as num?)?.toDouble() ?? 4.6,
    );
  }
}

class NutritionistService {
  const NutritionistService();

  static const collectionName = 'nutritionExperts';

  Future<List<NutritionistProfile>> fetchProfiles() async {
    final snapshot = await FirebaseFirestore.instance.collection(collectionName).limit(4).get();
    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs.map((doc) => NutritionistProfile.fromJson(doc.data())).toList();
    }
    return _fallbackProfiles();
  }

  List<NutritionistProfile> _fallbackProfiles() {
    return const [
      NutritionistProfile(
        name: 'Dr. Maya Rao',
        specialty: 'Metabolic balance & weight loss',
        experience: '8 years experience',
        location: 'Bengaluru',
        rating: 4.9,
      ),
      NutritionistProfile(
        name: 'Ankit Verma',
        specialty: 'Sports nutrition & muscle gain',
        experience: '6 years experience',
        location: 'Delhi',
        rating: 4.8,
      ),
      NutritionistProfile(
        name: 'Priya Sharma',
        specialty: 'PCOS & hormonal wellness',
        experience: '7 years experience',
        location: 'Mumbai',
        rating: 4.7,
      ),
      NutritionistProfile(
        name: 'Sarah Khan',
        specialty: 'Gut health & diabetes care',
        experience: '5 years experience',
        location: 'Hyderabad',
        rating: 4.6,
      ),
    ];
  }
}
