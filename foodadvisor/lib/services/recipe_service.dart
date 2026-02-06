import 'package:cloud_firestore/cloud_firestore.dart';

class RecipeService {
  const RecipeService();

  static const collectionName = 'recipeRequests';

  Future<int> countRecentRequests({required String userId, Duration window = const Duration(days: 7)}) async {
    final since = DateTime.now().subtract(window);
    final snapshot = await FirebaseFirestore.instance
        .collection(collectionName)
        .where('userId', isEqualTo: userId)
        .get();
    return snapshot.docs.where((doc) {
      final createdAt = doc.data()['createdAt'];
      return createdAt is Timestamp && !createdAt.toDate().isBefore(since);
    }).length;
  }

  Future<void> logRecipeRequest({
    required String userId,
    required String dateKey,
  }) async {
    await FirebaseFirestore.instance.collection(collectionName).add({
      'userId': userId,
      'dateKey': dateKey,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
